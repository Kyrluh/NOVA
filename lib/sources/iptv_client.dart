import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../domain/models.dart';
import '../domain/catalog_preferences.dart';
import '../domain/recent_catalog.dart';
import '../domain/source_models.dart';
import 'm3u_parser.dart';
import 'xmltv_parser.dart';

/// Provider adapters. Credentials and stream addresses never enter diagnostics.
class CatalogLoadProgress {
  const CatalogLoadProgress(this.sourceId, this.fraction, this.phase);
  final String sourceId;
  final double? fraction;
  final String phase;
}

class IptvClient {
  IptvClient({
    this.timeout = const Duration(seconds: 25),
    this.maxResponseBytes = 64 * 1024 * 1024,
    http.Client Function()? clientFactory,
  }) : _clientFactory = clientFactory ?? http.Client.new;

  final Duration timeout;
  final int maxResponseBytes;
  final catalogProgress = ValueNotifier<CatalogLoadProgress?>(null);
  void _progress(SourceConfig config, double? fraction, String phase) {
    catalogProgress.value = CatalogLoadProgress(config.id, fraction, phase);
  }

  final http.Client Function() _clientFactory;

  Future<String> testConnection(
    SourceDraft draft, {
    CancellationToken? cancel,
  }) => _guard(() async {
    _validate(draft);
    final config = SourceConfig.fromDraft('connection-test', draft);
    if (draft.kind != SourceKind.xtream) {
      final catalog = await loadCatalog(config, cancel: cancel);
      return '${catalog.items.length} médias trouvés. Playlist accessible.';
    }
    final session = _session(cancel);
    try {
      await _authenticate(session, config);
      return 'Connexion Xtream réussie. Compte actif.';
    } finally {
      session.close();
    }
  });

  Future<SourceCatalog> loadCatalog(
    SourceConfig config, {
    CancellationToken? cancel,
  }) => _loadCatalog(config, cancel: cancel);

  Future<SourceCatalog> loadSelectedCatalog(
    SourceConfig config,
    CatalogPreferences preferences, {
    CancellationToken? cancel,
  }) => config.kind == SourceKind.xtream
      ? _loadCatalog(config, cancel: cancel, preferences: preferences)
      : loadCatalog(config, cancel: cancel);

  Future<SourceCatalog> _loadCatalog(
    SourceConfig config, {
    CancellationToken? cancel,
    CatalogPreferences? preferences,
  }) => _guard(() async {
    _validate(config);
    cancel?.throwIfCancelled();
    _progress(config, .02, 'Connexion à la source');
    if (config.kind == SourceKind.m3uFile) {
      final file = File(config.address);
      if (await file.length() > maxResponseBytes) {
        throw const SourceException(
          'La playlist dépasse la limite de taille autorisée.',
        );
      }
      final bytes = await file.readAsBytes();
      _progress(config, .8, 'Lecture et classement du catalogue');
      cancel?.throwIfCancelled();
      final result = await compute(_parseM3u, (
        bytes,
        config,
        file.absolute.uri,
      ));
      cancel?.throwIfCancelled();
      return result;
    }
    final session = _session(cancel);
    try {
      if (config.kind == SourceKind.m3uUrl) {
        final uri = _httpUri(config.address);
        final bytes = await session.read(
          uri,
          onProgress: (received, total) {
            _progress(
              config,
              total != null && total > 0
                  ? .05 + .7 * (received / total).clamp(0, 1)
                  : null,
              'Téléchargement de la playlist',
            );
          },
        );
        _progress(config, .8, 'Lecture et classement du catalogue');
        final result = await compute(_parseM3u, (bytes, config, uri));
        cancel?.throwIfCancelled();
        return result;
      }
      final userInfo = await _authenticate(session, config);
      _progress(config, .1, 'Compte connecté');
      final formats =
          (userInfo['allowed_output_formats'] as List?)
              ?.whereType<String>()
              .toList() ??
          const <String>[];
      final liveExtension = !formats.contains('ts') && formats.contains('m3u8')
          ? 'm3u8'
          : 'ts';
      final items = <MediaItem>[];
      final warnings = <String>[];
      final failedKinds = <MediaKind>{};
      var successfulLists = 0;
      var sectionIndex = 0;
      // At most one provider request is active at a time; reuse its connection.
      for (final section in [
        (MediaKind.live, 'get_live_categories', 'get_live_streams', 'chaînes'),
        (MediaKind.movie, 'get_vod_categories', 'get_vod_streams', 'films'),
        (MediaKind.series, 'get_series_categories', 'get_series', 'séries'),
      ]) {
        final base = .1 + sectionIndex * .27;
        _progress(config, base, 'Chargement des ${section.$4}');
        cancel?.throwIfCancelled();
        Uint8List categories;
        try {
          categories = await session.read(_apiUri(config, section.$2));
        } on SourceCancelled {
          rethrow;
        } catch (_) {
          categories = Uint8List.fromList(utf8.encode('[]'));
        }
        try {
          final selectedCategories = <String>[];
          var selective = false;
          if (preferences != null) {
            final rows = _rows(await _jsonDocument(categories)).toList();
            for (final row in rows) {
              final probe = MediaItem(
                id: '',
                title: '',
                kind: section.$1,
                category: _text(row['category_name']),
                sourceId: config.id,
                description: '',
                year: 0,
                durationMinutes: 0,
                palette: 0,
                subtitle: '',
                art: 0,
              );
              final rule = preferences.ruleFor(section.$1);
              final language = inferCatalogLanguage(
                probe,
                overrides: rule.languageOverrides,
              );
              final hidden =
                  rule.hiddenCategories.contains(catalogCategoryKey(probe)) ||
                  (language != 'unknown' &&
                      rule.hiddenLanguages.contains(language));
              if (hidden) {
                selective = true;
              } else {
                selectedCategories.add(_text(row['category_id']));
              }
            }
          }
          final requests = selective ? selectedCategories : <String?>[null];
          final parsedItems = <MediaItem>[];
          for (final categoryId in requests) {
            final response = await session.read(
              _apiUri(config, section.$3, {'category_id': ?categoryId}),
              onProgress: (received, total) {
                _progress(
                  config,
                  total != null && total > 0
                      ? base + .22 * (received / total).clamp(0, 1)
                      : null,
                  'Chargement des ${section.$4}',
                );
              },
            );
            _progress(config, base + .24, 'Classement des ${section.$4}');
            final parsed = await compute(_parseXtreamList, (
              response,
              categories,
              config,
              section.$1,
              liveExtension,
            ));
            cancel?.throwIfCancelled();
            parsedItems.addAll(parsed);
          }
          items.addAll(parsedItems);
          successfulLists++;
        } on SourceCancelled {
          rethrow;
        } catch (_) {
          failedKinds.add(section.$1);
          warnings.add(
            'Le catalogue des ${section.$4} n’a pas pu être chargé. Les autres rubriques restent disponibles.',
          );
        }
        sectionIndex++;
        _progress(config, .1 + sectionIndex * .27, 'Catalogue reçu');
      }
      if (successfulLists == 0) {
        throw const SourceException(
          'Aucun catalogue n’a pu être chargé. Le cache existant est conservé.',
        );
      }
      return SourceCatalog(
        items: items,
        warnings: warnings,
        failedKinds: failedKinds,
      );
    } finally {
      session.close();
    }
  });

  Future<MediaItem> loadDetails(
    SourceConfig config,
    MediaItem item, {
    CancellationToken? cancel,
  }) => _guard(() async {
    if (config.kind != SourceKind.xtream ||
        item.kind == MediaKind.live ||
        item.providerId == null) {
      return item;
    }
    final session = _session(cancel);
    try {
      final response = await session.read(
        _apiUri(
          config,
          item.kind == MediaKind.series ? 'get_series_info' : 'get_vod_info',
          {
            item.kind == MediaKind.series ? 'series_id' : 'vod_id':
                item.providerId!,
          },
        ),
      );
      final result = await compute(_parseXtreamDetails, (
        response,
        config,
        item,
      ));
      cancel?.throwIfCancelled();
      return result;
    } finally {
      session.close();
    }
  });

  Future<List<EpgProgramme>> loadEpg(
    SourceConfig config, {
    CancellationToken? cancel,
  }) => _guard(() async {
    final configured = config.epgUrl.trim();
    if (configured.isEmpty && config.kind != SourceKind.xtream) {
      throw const SourceException(
        'Aucune adresse XMLTV n’est configurée pour cette source.',
      );
    }
    final uri = configured.isNotEmpty
        ? _httpUri(configured)
        : _endpoint(config, 'xmltv.php', {
            'username': config.username,
            'password': config.password,
          });
    final session = _session(cancel);
    try {
      final bytes = await session.read(uri);
      final result = await compute(_parseGuide, bytes);
      cancel?.throwIfCancelled();
      return result;
    } finally {
      session.close();
    }
  });

  _HttpSession _session(CancellationToken? cancel) {
    cancel?.throwIfCancelled();
    return _HttpSession(_clientFactory(), timeout, maxResponseBytes, cancel);
  }

  Future<Map<String, dynamic>> _authenticate(
    _HttpSession session,
    SourceConfig config,
  ) async {
    final response = await session.read(_apiUri(config, null));
    final json = await compute(_jsonDocument, response);
    final root = _object(json);
    final user = _object(root['user_info']);
    if (!['1', 'true'].contains('${user['auth']}'.toLowerCase())) {
      throw const SourceException(
        'Connexion refusée. Vérifiez le serveur, le nom d’utilisateur et le mot de passe.',
      );
    }
    final status = '${user['status'] ?? 'Active'}'.toLowerCase();
    if (!['active', ''].contains(status)) {
      throw const SourceException(
        'Ce compte n’est pas actif. Vérifiez sa validité auprès de votre fournisseur.',
      );
    }
    return user;
  }

  void _validate(SourceDraft draft) {
    if (draft.address.trim().isEmpty) {
      throw const SourceException(
        'Renseignez une adresse ou un fichier de source.',
      );
    }
    if (draft.kind != SourceKind.m3uFile) _httpUri(draft.address);
    if (draft.epgUrl.trim().isNotEmpty) _httpUri(draft.epgUrl);
    if (draft.kind == SourceKind.xtream &&
        (draft.username.trim().isEmpty || draft.password.isEmpty)) {
      throw const SourceException(
        'Le nom d’utilisateur et le mot de passe Xtream sont requis.',
      );
    }
  }

  Future<T> _guard<T>(Future<T> Function() task) async {
    try {
      return await task();
    } on SourceException {
      rethrow;
    } on TimeoutException {
      throw const SourceException(
        'Le serveur met trop de temps à répondre. Réessayez ou vérifiez votre connexion.',
      );
    } on FileSystemException {
      throw const SourceException(
        'Le fichier local est inaccessible. Vérifiez son emplacement et vos droits d’accès.',
      );
    } on FormatException {
      throw const SourceException(
        'Le contenu reçu est invalide ou incomplet. Vérifiez le type de source.',
      );
    } catch (_) {
      throw const SourceException(
        'Le chargement a échoué. Vérifiez la connexion et la disponibilité de votre source.',
      );
    }
  }
}

class _HttpSession {
  _HttpSession(this.client, this.timeout, this.limit, this.cancel) {
    cancel?.throwIfCancelled();
    cancel?.onCancel(close);
  }
  final http.Client client;
  final Duration timeout;
  final int limit;
  final CancellationToken? cancel;
  bool _closed = false;

  Future<Uint8List> read(
    Uri uri, {
    void Function(int received, int? total)? onProgress,
  }) async {
    cancel?.throwIfCancelled();
    try {
      return await _read(uri, onProgress: onProgress).timeout(
        timeout,
        onTimeout: () {
          close();
          throw TimeoutException('Source request timed out');
        },
      );
    } catch (_) {
      cancel?.throwIfCancelled();
      rethrow;
    }
  }

  Future<Uint8List> _read(
    Uri uri, {
    void Function(int received, int? total)? onProgress,
  }) async {
    final request = http.Request('GET', uri)
      ..headers.addAll({'user-agent': 'NOVA IPTV/0.2.0', 'accept': '*/*'});
    final response = await client.send(request);
    if ((response.contentLength ?? 0) > limit) {
      close();
      throw const SourceException(
        'La réponse du serveur dépasse la limite de taille autorisée.',
      );
    }
    final builder = BytesBuilder(copy: false);
    var count = 0;
    onProgress?.call(0, response.contentLength);
    await for (final chunk in response.stream) {
      cancel?.throwIfCancelled();
      count += chunk.length;
      if (count > limit) {
        close();
        throw const SourceException(
          'La réponse du serveur dépasse la limite de taille autorisée.',
        );
      }
      builder.add(chunk);
      onProgress?.call(count, response.contentLength);
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw SourceException(
        response.statusCode == 401 || response.statusCode == 403
            ? 'Accès refusé par le serveur. Vérifiez vos identifiants et vos droits d’accès.'
            : 'Le serveur a renvoyé une erreur HTTP ${response.statusCode}. Réessayez plus tard.',
      );
    }
    return builder.takeBytes();
  }

  void close() {
    if (_closed) return;
    _closed = true;
    cancel?.removeOnCancel(close);
    client.close();
  }
}

Uri _httpUri(String value) {
  final uri = Uri.tryParse(value.trim());
  if (uri == null ||
      !['http', 'https'].contains(uri.scheme) ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty) {
    throw const SourceException('Saisissez une adresse HTTP ou HTTPS valide.');
  }
  return uri;
}

Uri _root(SourceConfig config) {
  final uri = _httpUri(config.address);
  final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
  if (segments.isNotEmpty &&
      [
        'player_api.php',
        'get.php',
        'xmltv.php',
      ].contains(segments.last.toLowerCase())) {
    segments.removeLast();
  }
  final query = Map<String, String>.from(uri.queryParameters)
    ..removeWhere(
      (key, _) => [
        'username',
        'password',
        'action',
        'vod_id',
        'series_id',
        'stream_id',
      ].contains(key),
    );
  return uri.replace(
    pathSegments: [...segments, ''],
    queryParameters: query,
    fragment: '',
  );
}

Uri _endpoint(SourceConfig config, String filename, Map<String, String> query) {
  final root = _root(config);
  return root.replace(
    pathSegments: [...root.pathSegments.where((p) => p.isNotEmpty), filename],
    queryParameters: {...root.queryParameters, ...query},
  );
}

Uri _apiUri(
  SourceConfig config,
  String? action, [
  Map<String, String> extra = const {},
]) => _endpoint(config, 'player_api.php', {
  'username': config.username,
  'password': config.password,
  'action': ?action,
  ...extra,
});

String _streamUrl(
  SourceConfig config,
  String type,
  String id,
  String extension,
) {
  final root = _root(config);
  return root
      .replace(
        pathSegments: [
          ...root.pathSegments.where((p) => p.isNotEmpty),
          type,
          config.username,
          config.password,
          '$id.$extension',
        ],
      )
      .toString();
}

Future<String> _document(Uint8List bytes) async {
  if (bytes.length >= 2 && bytes[0] == 0x1f && bytes[1] == 0x8b) {
    final buffer = BytesBuilder(copy: false);
    var count = 0;
    await for (final chunk in gzip.decoder.bind(Stream.value(bytes))) {
      count += chunk.length;
      if (count > 64 * 1024 * 1024) {
        throw const SourceException(
          'Le guide décompressé dépasse la limite de taille autorisée.',
        );
      }
      buffer.add(chunk);
    }
    bytes = buffer.takeBytes();
  }
  if (bytes.length >= 2 &&
      ((bytes[0] == 0xff && bytes[1] == 0xfe) ||
          (bytes[0] == 0xfe && bytes[1] == 0xff))) {
    final data = ByteData.sublistView(bytes);
    return String.fromCharCodes([
      for (var i = 2; i + 1 < bytes.length; i += 2)
        data.getUint16(i, bytes[0] == 0xff ? Endian.little : Endian.big),
    ]);
  }
  final declaration = latin1.decode(bytes.take(200).toList()).toLowerCase();
  if (declaration.contains('iso-8859-1')) return latin1.decode(bytes);
  try {
    return utf8.decode(bytes).replaceFirst('\ufeff', '');
  } on FormatException {
    return latin1.decode(bytes);
  }
}

Future<Object?> _jsonDocument(Uint8List bytes) async =>
    jsonDecode(await _document(bytes));
Future<SourceCatalog> _parseM3u((Uint8List, SourceConfig, Uri) request) async =>
    parseM3u(await _document(request.$1), request.$2, request.$3);
Future<List<EpgProgramme>> _parseGuide(Uint8List bytes) async =>
    parseXmltv(await _document(bytes));

Map<String, dynamic> _object(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : {};
List<Map<String, dynamic>> _rows(Object? value) =>
    value is List ? value.whereType<Map>().map(_object).toList() : [];
String _text(Object? value) =>
    value is String || value is num ? '$value'.trim() : '';
int _number(Object? value) => int.tryParse(_text(value)) ?? 0;
int _year(Object? value) =>
    int.tryParse(
      RegExp(r'(?:19|20)\d{2}').firstMatch(_text(value))?.group(0) ?? '',
    ) ??
    0;
String? _url(Object? value, SourceConfig config) {
  final text = _text(value);
  if (text.isEmpty || text == 'null') return null;
  try {
    final uri = _root(config).resolve(text);
    return ['http', 'https'].contains(uri.scheme) ? uri.toString() : null;
  } on FormatException {
    return null;
  }
}

String _extension(Object? value, [String fallback = 'mp4']) {
  final text = _text(value);
  return RegExp(r'^[a-zA-Z0-9]{1,8}$').hasMatch(text) ? text : fallback;
}

int _minutes(Map<String, dynamic> info) {
  final seconds = _number(info['duration_secs']);
  if (seconds > 0) return (seconds / 60).ceil();
  final duration = _text(info['duration']);
  final parts = duration.split(':').map(int.tryParse).toList();
  if (parts.any((value) => value == null)) return 0;
  if (parts.length == 3) {
    return ((parts[0]! * 3600 + parts[1]! * 60 + parts[2]!) / 60).ceil();
  }
  if (parts.length == 2) return ((parts[0]! * 60 + parts[1]!) / 60).ceil();
  return 0;
}

Future<List<MediaItem>> _parseXtreamList(
  (Uint8List, Uint8List, SourceConfig, MediaKind, String) request,
) async {
  final response = await _jsonDocument(request.$1);
  if (response is! List) {
    throw const SourceException(
      'Le serveur n’a pas renvoyé un catalogue Xtream valide.',
    );
  }
  final categories = <String, String>{};
  try {
    for (final row in _rows(await _jsonDocument(request.$2))) {
      categories[_text(row['category_id'])] = _text(row['category_name']);
    }
  } catch (_) {
    /* Category names are optional; streams remain usable. */
  }
  final config = request.$3;
  final kind = request.$4;
  final list = <String, MediaItem>{};
  for (final row in _rows(response)) {
    final provider = _text(
      row[kind == MediaKind.series ? 'series_id' : 'stream_id'],
    );
    if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(provider)) continue;
    final title = _text(row['name']);
    final id =
        '${config.id}:${kind == MediaKind.movie ? 'movie' : kind.name}:$provider';
    final category = categories[_text(row['category_id'])] ?? '';
    final extension = _extension(
      row['container_extension'],
      kind == MediaKind.live ? request.$5 : 'mp4',
    );
    list[id] = MediaItem(
      addedAt: providerAddedAt(row['added']),
      id: id,
      title: title.isEmpty ? 'Média $provider' : title,
      kind: kind,
      category: category.isEmpty ? 'Sans catégorie' : category,
      description: _text(row['plot']),
      year: _year(row['year'] ?? row['releaseDate'] ?? row['release_date']),
      durationMinutes: _minutes(row),
      palette: 0xff6671a8,
      subtitle: config.name,
      art: provider.hashCode & 0xffff,
      sourceId: config.id,
      providerId: provider,
      posterUrl: _url(row['stream_icon'] ?? row['cover'], config),
      tvgId: _text(row['epg_channel_id']).isEmpty
          ? null
          : _text(row['epg_channel_id']),
      mediaUrl: kind == MediaKind.series
          ? null
          : _url(row['direct_source'], config) ??
                _streamUrl(
                  config,
                  kind == MediaKind.live ? 'live' : 'movie',
                  provider,
                  extension,
                ),
      detailsLoaded: kind == MediaKind.live,
    );
  }
  return list.values.toList(growable: false);
}

Future<MediaItem> _parseXtreamDetails(
  (Uint8List, SourceConfig, MediaItem) request,
) async {
  final data = await _jsonDocument(request.$1);
  if (data is! Map) {
    throw const SourceException(
      'La fiche reçue est invalide. Réessayez plus tard.',
    );
  }
  final root = _object(data);
  final config = request.$2;
  final item = request.$3;
  final info = _object(root['info']);
  if (item.kind == MediaKind.series && !root.containsKey('episodes')) {
    throw const SourceException(
      'La liste des épisodes n’est pas disponible. Réessayez plus tard.',
    );
  }
  if (item.kind == MediaKind.movie &&
      !root.containsKey('info') &&
      !root.containsKey('movie_data')) {
    throw const SourceException(
      'La fiche du film n’est pas disponible. Réessayez plus tard.',
    );
  }
  if (item.kind == MediaKind.movie) {
    final movie = _object(root['movie_data']);
    return item.copyWith(
      description: _text(info['plot']).isNotEmpty
          ? _text(info['plot'])
          : item.description,
      posterUrl:
          _url(info['movie_image'] ?? info['cover_big'], config) ??
          item.posterUrl,
      year:
          _year(info['releasedate'] ?? info['release_date'] ?? info['year']) > 0
          ? _year(info['releasedate'] ?? info['release_date'] ?? info['year'])
          : item.year,
      durationMinutes: _minutes(info) > 0
          ? _minutes(info)
          : item.durationMinutes,
      mediaUrl:
          _url(movie['direct_source'], config) ??
          (_text(movie['container_extension']).isEmpty
              ? item.mediaUrl
              : _streamUrl(
                  config,
                  'movie',
                  item.providerId!,
                  _extension(movie['container_extension']),
                )),
      detailsLoaded: true,
    );
  }
  final episodes = root['episodes'];
  final groups = <int, List<Map<String, dynamic>>>{};
  if (episodes is Map) {
    for (final entry in episodes.entries) {
      final season = int.tryParse('${entry.key}') ?? 0;
      groups[season] = _rows(entry.value);
    }
  } else if (episodes is List) {
    for (final episode in _rows(episodes)) {
      (groups[_number(episode['season'])] ??= []).add(episode);
    }
  }
  final seasons = <DemoSeason>[];
  final numbers = groups.keys.toList()..sort();
  for (final season in numbers) {
    final list = <DemoEpisode>[];
    final knownIds = <String>{};
    for (final episode in groups[season]!) {
      final id = _text(episode['id']);
      if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(id) || !knownIds.add(id)) {
        continue;
      }
      final episodeInfo = _object(episode['info']);
      final title = _text(episode['title']);
      final number = _number(episode['episode_num']);
      list.add(
        DemoEpisode(
          id: '${config.id}:episode:$id',
          title: title.isEmpty ? 'Épisode $number' : title,
          number: number,
          durationMinutes: _minutes(episodeInfo),
          mediaUrl:
              _url(episode['direct_source'], config) ??
              _streamUrl(
                config,
                'series',
                id,
                _extension(episode['container_extension']),
              ),
          posterUrl: _url(episodeInfo['movie_image'], config),
          description: _text(episodeInfo['plot']),
        ),
      );
    }
    list.sort((a, b) => a.number.compareTo(b.number));
    if (list.isNotEmpty) {
      seasons.add(DemoSeason(number: season, episodes: list));
    }
  }
  return item.copyWith(
    description: _text(info['plot']).isNotEmpty
        ? _text(info['plot'])
        : item.description,
    posterUrl: _url(info['cover'], config) ?? item.posterUrl,
    year: _year(info['releaseDate'] ?? info['release_date']) > 0
        ? _year(info['releaseDate'] ?? info['release_date'])
        : item.year,
    seasons: seasons,
    detailsLoaded: true,
  );
}
