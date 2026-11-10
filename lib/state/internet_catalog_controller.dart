import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/local_store.dart';
import '../domain/internet_catalog.dart';
import '../domain/artwork_identity.dart';
import '../domain/models.dart';
import '../domain/platform_catalog.dart';
import '../sources/public_catalog_client.dart';

class InternetCatalogController extends ChangeNotifier {
  InternetCatalogController({
    required LocalStore store,
    PublicCatalogClient Function()? clientFactory,
  })
    // Public injection parameter remains independent of the private field.
    // ignore: prefer_initializing_formals
    : _store = store,
       _clientFactory = clientFactory ?? PublicCatalogClient.new;
  final LocalStore _store;
  final PublicCatalogClient Function() _clientFactory;
  final Map<String, _Feed> _feeds = {};
  final Map<String, List<InternetTitle>> _titleIndex = {};
  final Map<String, Set<CatalogPlatform>> _platformIndex = {};
  List<MediaItem>? _library;
  final Map<String, List<MediaItem>> _libraryIndex = {};
  final Set<String> _ambiguousPosters = {};
  PublicCatalogClient? _client;
  Future<void>? _initialization;
  Future<void> _writes = Future.value();
  bool _disposed = false;
  bool _cancelled = false;
  bool _running = false;
  int _completed = 0;
  String? _message;
  bool get running => _running;
  int get completed => _completed;
  int get total => 20;
  String? get message => _message;
  DateTime? get lastUpdated => _feeds.values
      .map((f) => f.updated)
      .fold<DateTime?>(
        null,
        (latest, date) =>
            latest == null || date.isAfter(latest) ? date : latest,
      );
  List<InternetTitle> trending(MediaKind kind) => List.unmodifiable(
    _feeds['trends/${kind.name}']?.titles.take(20) ?? const <InternetTitle>[],
  );
  List<InternetTitle> selection(CatalogPlatform platform, {MediaKind? kind}) =>
      [
        for (final type in [MediaKind.movie, MediaKind.series])
          if (kind == null || kind == type)
            ...?_feeds['${platform.name}/${type.name}']?.titles,
      ];

  Future<void> init() => _initialization ??= _load();
  Future<void> _load() async {
    try {
      final data = await _store.load();
      final rawFeeds = data['feeds'];
      if (rawFeeds is Map) {
        for (final key in _feedKeys) {
          final raw = rawFeeds[key];
          if (raw is! Map ||
              raw['titles'] is! List ||
              raw['updated'] is! String) {
            continue;
          }
          final date = DateTime.tryParse(raw['updated']);
          if (date == null) continue;
          final kind = key.endsWith('/movie')
              ? MediaKind.movie
              : MediaKind.series;
          final titles = (raw['titles'] as List)
              .take(1000)
              .map((r) => InternetTitle.parse(r, kind))
              .whereType<InternetTitle>()
              .toList();
          if (titles.isNotEmpty) _feeds[key] = _Feed(titles, date);
        }
      }
      _reindex();
    } catch (_) {
      _message = 'Le cache internet est indisponible. Votre bibliothèque reste accessible.';
    }
    _notify();
  }

  Iterable<String> get _feedKeys sync* {
    for (final kind in [MediaKind.movie, MediaKind.series]) {
      yield 'trends/${kind.name}';
      for (final platform in CatalogPlatform.values) {
        if (platform.asset.isEmpty) continue;
        yield '${platform.name}/${kind.name}';
      }
    }
  }

  Future<void> refresh() async {
    if (_running || _disposed) return;
    await init();
    if (_running || _disposed) return;
    _running = true;
    _cancelled = false;
    _completed = 0;
    _message = null;
    _notify();
    var successes = 0;
    var next = 0;
    try {
      final client = _client = _clientFactory();
      final keys = _feedKeys.toList();
      Future<void> worker() async {
        while (!_cancelled && !_disposed && next < keys.length) {
          final key = keys[next++];
          final parts = key.split('/');
          final kind = parts.last == 'movie'
              ? MediaKind.movie
              : MediaKind.series;
          try {
            final titles = parts.first == 'trends'
                ? await client.trends(kind)
                : await client.platforms(
                    CatalogPlatform.values.byName(parts.first),
                    kind,
                  );
            if (_cancelled || _disposed) return;
            _feeds[key] = _Feed(titles, DateTime.now().toUtc());
            successes++;
          } catch (_) {
            /* Keep this feed's last good snapshot. */
          }
          if (_cancelled || _disposed) return;
          _completed++;
          _notify();
        }
      }

      await Future.wait([worker(), worker(), worker()]);
    } catch (_) {
      /* Client creation and transport failures are non-fatal. */
    } finally {
      _client?.close();
      _client = null;
      _reindex();
      if (!_disposed) {
        _message = _cancelled
            ? 'Mise à jour arrêtée. Les données reçues sont conservées.'
            : successes == 0
            ? 'Internet indisponible pour le moment. Le dernier classement et l’accueil restent disponibles.'
            : successes < total
            ? '$successes / $total sélections actualisées. Les autres données sont conservées.'
            : 'Plateformes et tendances de l’accueil actualisées.';
        try {
          await _save();
        } catch (_) {
          _message = 'Données actualisées en mémoire. Leur sauvegarde a échoué, votre bibliothèque reste accessible.';
        }
        _running = false;
        _notify();
      }
    }
  }

  void cancel() {
    _cancelled = true;
    _client?.close();
  }

  Set<CatalogPlatform> platformsFor(MediaItem item) {
    final match = _match(item);
    return match == null
        ? const {}
        : Set.unmodifiable(
            _platformIndex['${match.kind.name}/${match.id}'] ??
                const <CatalogPlatform>{},
          );
  }

  InternetTitle? _match(MediaItem item) {
    final candidates =
        _titleIndex['${item.kind.name}/${internetTitleKey(item.title)}'] ??
        const <InternetTitle>[];
    final matches = candidates
        .where((t) => sameInternetTitle(item, t))
        .toList();
    return matches.length == 1 ? matches.single : null;
  }

  MediaItem? libraryMatch(InternetTitle title, List<MediaItem> items) {
    if (!identical(items, _library)) {
      _library = items;
      _libraryIndex.clear();
      for (final item in items) {
        if (!hasLibraryVideo(item)) continue;
        final key = '${item.kind.name}/${internetTitleKey(item.title)}';
        (_libraryIndex[key] ??= []).add(item);
      }
    }
    final candidates = <String, MediaItem>{};
    for (final name in [title.title, ...title.aliases]) {
      for (final item
          in _libraryIndex['${title.kind.name}/${internetTitleKey(name)}'] ??
              const <MediaItem>[]) {
        if (sameInternetTitle(item, title)) candidates[item.id] = item;
      }
    }
    final matches = candidates.values.toList();
    if (matches.length == 1) return matches.single;
    // Several qualities of the same dated film are safe. Undated remakes are not.
    final years = matches.map(mediaIdentityYear).toSet();
    return matches.isNotEmpty && years.length == 1 && years.single > 0
        ? matches.first
        : null;
  }

  static bool hasLibraryVideo(MediaItem item) =>
      !item.isDemo &&
      item.kind != MediaKind.live &&
      (item.mediaUrl?.trim().isNotEmpty == true ||
          (item.kind == MediaKind.series &&
              (item.providerId?.trim().isNotEmpty == true ||
                  item.seasons.any(
                    (s) => s.episodes.any(
                      (e) => e.mediaUrl?.trim().isNotEmpty == true,
                    ),
                  ))));

  List<InternetTitle> availableTrending(
    MediaKind kind,
    List<MediaItem> items,
  ) => _available(
    _feeds['trends/${kind.name}']?.titles ?? const [],
    items,
  ).take(20).toList();

  List<InternetTitle> availableSelection(
    CatalogPlatform platform,
    List<MediaItem> items,
  ) => _available(selection(platform), items).toList();

  Iterable<InternetTitle> _available(
    Iterable<InternetTitle> titles,
    List<MediaItem> items,
  ) sync* {
    final seen = <String>{};
    for (final title in titles) {
      final match = libraryMatch(title, items);
      if (match != null && seen.add(match.id)) yield title;
    }
  }

  String? posterFor(MediaItem item) {
    final match = _match(item);
    final poster = match?.posterUrl;
    final identity = posterIdentity(poster);
    return identity == null || _ambiguousPosters.contains(identity)
        ? null
        : poster;
  }

  void _reindex() {
    _titleIndex.clear();
    _platformIndex.clear();
    _ambiguousPosters.clear();
    final posterOwners = <String, String>{};
    final seen = <String>{};
    for (final entry in _feeds.entries) {
      final platform = CatalogPlatform.values
          .where((p) => entry.key.startsWith('${p.name}/'))
          .firstOrNull;
      for (final title in entry.value.titles) {
        final identity = '${title.kind.name}/${title.id}';
        final poster = posterIdentity(title.posterUrl);
        if (poster != null) {
          final previous = posterOwners[poster];
          if (previous != null && previous != identity) {
            _ambiguousPosters.add(poster);
          }
          posterOwners[poster] = identity;
        }
        if (platform != null) (_platformIndex[identity] ??= {}).add(platform);
        for (final name in [title.title, ...title.aliases]) {
          final key = '${title.kind.name}/${internetTitleKey(name)}';
          if (seen.add('$key|${title.id}')) {
            (_titleIndex[key] ??= []).add(title);
          }
        }
      }
    }
  }

  Future<void> _save() {
    final snapshot = {
      'feeds': {
        for (final entry in _feeds.entries)
          entry.key: {
            'updated': entry.value.updated.toIso8601String(),
            'titles': entry.value.titles.map((t) => t.toJson()).toList(),
          },
      },
    };
    return _writes = _writes
        .catchError((Object _) {})
        .then((_) => _store.save(snapshot));
  }

  Future<void> close() async {
    cancel();
    try {
      await _save();
    } catch (_) {}
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    cancel();
    super.dispose();
  }
}

class _Feed {
  const _Feed(this.titles, this.updated);
  final List<InternetTitle> titles;
  final DateTime updated;
}
