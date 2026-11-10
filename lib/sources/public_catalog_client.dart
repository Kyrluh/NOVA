import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/internet_catalog.dart';
import '../domain/models.dart';
import '../domain/platform_catalog.dart';

class PublicCatalogUnavailable implements Exception {
  const PublicCatalogUnavailable();
  @override
  String toString() => 'Le catalogue internet est momentanément indisponible.';
}

const publicPlatformIds = {
  CatalogPlatform.netflix: 'nfx',
  CatalogPlatform.primeVideo: 'amp',
  CatalogPlatform.disneyPlus: 'dnp',
  CatalogPlatform.appleTv: 'atp',
  CatalogPlatform.hbo: 'hbm',
  CatalogPlatform.paramountPlus: 'pmp',
  CatalogPlatform.crunchyroll: 'cru',
  CatalogPlatform.hulu: 'hlu',
  CatalogPlatform.peacock: 'pcp',
};

class PublicCatalogClient {
  PublicCatalogClient({
    http.Client? client,
    this.timeout = const Duration(seconds: 8),
    Uri? platformsBase,
    Uri? trendsBase,
  }) : _client = client ?? http.Client(),
       _platformsBase =
           platformsBase ??
           Uri.parse(
             'https://7a82163c306e-stremio-netflix-catalog-addon.baby-beamup.club/',
           ),
       _trendsBase = trendsBase ?? Uri.parse('https://v3-cinemeta.strem.io/');
  final http.Client _client;
  final Duration timeout;
  final Uri _platformsBase;
  final Uri _trendsBase;

  Future<List<InternetTitle>> platforms(
    CatalogPlatform platform,
    MediaKind kind,
  ) => _catalog(
    _platformsBase.resolve(
      'catalog/${kind.name}/${publicPlatformIds[platform]}.json',
    ),
    kind,
  );
  Future<List<InternetTitle>> trends(MediaKind kind) =>
      _catalog(_trendsBase.resolve('catalog/${kind.name}/top.json'), kind);

  Future<List<InternetTitle>> _catalog(Uri uri, MediaKind kind) async {
    final abort = Completer<void>();
    try {
      return await (() async {
        var target = uri;
        Future<http.StreamedResponse> send() => _client.send(
          http.AbortableRequest('GET', target, abortTrigger: abort.future)
            ..followRedirects = false
            ..headers['Accept'] = 'application/json',
        );
        var response = await send();
        for (
          var redirects = 0;
          redirects < 2 && [301, 302, 307, 308].contains(response.statusCode);
          redirects++
        ) {
          final location = response.headers['location'];
          if (location == null) throw const PublicCatalogUnavailable();
          final next = target.resolve(location);
          final allowed =
              next.host == uri.host ||
              (uri.host == 'v3-cinemeta.strem.io' &&
                  next.host == 'cinemeta-catalogs.strem.io');
          if (!allowed || next.scheme != 'https' || next.userInfo.isNotEmpty) {
            throw const PublicCatalogUnavailable();
          }
          await response.stream.drain<void>();
          target = next;
          response = await send();
        }
        if (response.statusCode != 200) throw const PublicCatalogUnavailable();
        final bytes = <int>[];
        await for (final chunk in response.stream) {
          if (bytes.length + chunk.length > 3 * 1024 * 1024) {
            throw const PublicCatalogUnavailable();
          }
          bytes.addAll(chunk);
        }
        final data = jsonDecode(utf8.decode(bytes));
        if (data is! Map || data['metas'] is! List) {
          throw const PublicCatalogUnavailable();
        }
        final titles = <String, InternetTitle>{};
        for (final raw in (data['metas'] as List).take(1000)) {
          final title = InternetTitle.parse(raw, kind);
          if (title != null) titles[title.id] = title;
        }
        // Some public endpoints return [] on upstream failure. Never erase a
        // useful previous snapshot based solely on such an ambiguous response.
        if (titles.isEmpty) throw const PublicCatalogUnavailable();
        return titles.values.toList(growable: false);
      })().timeout(
        timeout,
        onTimeout: () {
          if (!abort.isCompleted) abort.complete();
          throw const PublicCatalogUnavailable();
        },
      );
    } catch (_) {
      throw const PublicCatalogUnavailable();
    }
  }

  void close() => _client.close();
}
