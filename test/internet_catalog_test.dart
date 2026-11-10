import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nova_iptv/data/demo_catalog.dart';
import 'package:nova_iptv/data/local_store.dart';
import 'package:nova_iptv/domain/internet_catalog.dart';
import 'package:nova_iptv/domain/models.dart';
import 'package:nova_iptv/domain/platform_catalog.dart';
import 'package:nova_iptv/sources/public_catalog_client.dart';
import 'package:nova_iptv/state/app_controller.dart';
import 'package:nova_iptv/state/internet_catalog_controller.dart';

import 'support/public_catalog_fixture.dart';

void main() {
  test('Cinemeta official redirect is followed without enabling arbitrary redirects', () async {
    final client = fixtureClient(
      handler: (request) async {
        if (request.url.host == 'v3-cinemeta.strem.io') {
          return http.Response(
            '',
            307,
            headers: {
              'location': 'https://cinemeta-catalogs.strem.io/top/catalog/movie/top.json',
            },
          );
        }
        return fixtureResponse(request.url);
      },
    );
    addTearDown(client.close);
    expect(await client.trends(MediaKind.movie), isNotEmpty);
  });
  test(
    'Unexpected redirect destinations are rejected without fetching them',
    () async {
      final requests = <Uri>[];
      final client = fixtureClient(
        handler: (request) async {
          requests.add(request.url);
          return http.Response(
            '',
            302,
            headers: {'location': 'http://127.0.0.1/private'},
          );
        },
      );
      addTearDown(client.close);
      await expectLater(
        client.trends(MediaKind.movie),
        throwsA(isA<PublicCatalogUnavailable>()),
      );
      expect(requests, hasLength(1));
    },
  );
  test('Oversized public metadata is rejected', () async {
    final client = fixtureClient(
      handler: (_) async =>
          http.Response.bytes(List.filled(3 * 1024 * 1024 + 1, 32), 200),
    );
    addTearDown(client.close);
    await expectLater(
      client.trends(MediaKind.movie),
      throwsA(isA<PublicCatalogUnavailable>()),
    );
  });
  test(
    'Public API uses only fixed metadata endpoints without keys or IPTV data',
    () async {
      final requests = <http.Request>[];
      final api = InternetCatalogController(
        store: MemoryLocalStore(),
        clientFactory: () => fixtureClient(
          handler: (request) async {
            requests.add(request);
            return fixtureResponse(request.url);
          },
        ),
      );
      addTearDown(api.dispose);
      await api.refresh();
      expect(requests, hasLength(20));
      expect(
        requests.every(
          (r) =>
              r.method == 'GET' &&
              r.url.query.isEmpty &&
              r.headers['Authorization'] == null &&
              r.body.isEmpty,
        ),
        isTrue,
      );
      expect(api.platformsFor(demoCatalog.first), {CatalogPlatform.netflix});
      expect(
        api.trending(MediaKind.movie).single.title,
        demoCatalog.first.title,
      );
      expect(api.completed, 20);
      expect(api.running, isFalse);
    },
  );

  for (final invalid in [
    '<html>Unavailable</html>',
    '{"metas":[]}',
    '{"metas":{}}',
  ]) {
    test('Invalid/empty data keeps a persisted snapshot: $invalid', () async {
      final store = MemoryLocalStore();
      final first = InternetCatalogController(
        store: store,
        clientFactory: fixtureClient,
      );
      await first.refresh();
      final date = first.lastUpdated;
      first.dispose();
      var calls = 0;
      final restored = InternetCatalogController(
        store: store,
        clientFactory: () => fixtureClient(
          handler: (_) async {
            calls++;
            return http.Response(invalid, 200);
          },
        ),
      );
      addTearDown(restored.dispose);
      await restored.init();
      expect(calls, 0);
      await restored.refresh();
      expect(restored.lastUpdated, date);
      expect(restored.trending(MediaKind.series), isNotEmpty);
      expect(restored.platformsFor(demoCatalog.first), {
        CatalogPlatform.netflix,
      });
      expect(restored.message, contains('indisponible'));
    });
  }

  test(
    'Partial failure preserves failed feeds while updating healthy ones',
    () async {
      var failNetflix = false;
      final api = InternetCatalogController(
        store: MemoryLocalStore(),
        clientFactory: () => fixtureClient(
          handler: (request) async {
            if (failNetflix && request.url.path.endsWith('/nfx.json')) {
              return http.Response('Unavailable', 503);
            }
            return fixtureResponse(request.url);
          },
        ),
      );
      addTearDown(api.dispose);
      await api.refresh();
      failNetflix = true;
      await api.refresh();
      expect(api.platformsFor(demoCatalog.first), {CatalogPlatform.netflix});
      expect(api.message, contains('18 / 20'));
    },
  );

  test(
    'Slow requests have a finite deadline and refresh does not throw',
    () async {
      final api = InternetCatalogController(
        store: MemoryLocalStore(),
        clientFactory: () => PublicCatalogClient(
          timeout: const Duration(milliseconds: 3),
          client: MockClient((request) async {
            await Future<void>.delayed(const Duration(milliseconds: 20));
            return fixtureResponse(request.url);
          }),
        ),
      );
      addTearDown(api.dispose);
      await api.refresh();
      expect(api.running, isFalse);
      expect(api.trending(MediaKind.movie), isEmpty);
      expect(api.message, contains('indisponible'));
    },
  );

  test(
    'Cancellation ignores late responses and permits another refresh',
    () async {
      final gate = Completer<void>();
      var block = true;
      final api = InternetCatalogController(
        store: MemoryLocalStore(),
        clientFactory: () => fixtureClient(
          handler: (request) async {
            if (block) await gate.future;
            return fixtureResponse(request.url);
          },
        ),
      );
      addTearDown(api.dispose);
      final pending = api.refresh();
      await Future<void>.delayed(Duration.zero);
      api.cancel();
      gate.complete();
      await pending;
      expect(api.trending(MediaKind.movie), isEmpty);
      expect(api.running, isFalse);
      block = false;
      await api.refresh();
      expect(api.trending(MediaKind.movie), isNotEmpty);
    },
  );

  test(
    'Manual exclusions retain priority over matching internet metadata',
    () async {
      final api = InternetCatalogController(
        store: MemoryLocalStore(),
        clientFactory: fixtureClient,
      );
      final app = AppController(
        store: MemoryLocalStore(),
        internetCatalog: api,
      );
      addTearDown(api.dispose);
      addTearDown(app.dispose);
      await app.init();
      await api.refresh();
      final movie = demoCatalog.first;
      expect(app.platformsFor(movie), {CatalogPlatform.netflix});
      app.updatePlatformPreferences(
        app.platformPreferences.withGroup(movie.kind, movie.category, {}),
      );
      expect(app.platformsFor(movie), isEmpty);
      expect(app.items, contains(movie));
    },
  );

  test('Metadata parser rejects invalid types and untrusted poster hosts; matching respects year', () {
    final title = InternetTitle.parse({
      'id': 'tt10000001',
      'name': 'Création fictive',
      'releaseInfo': '2026',
      'poster': 'http://127.0.0.1/private',
    }, MediaKind.movie)!;
    expect(title.posterUrl, isNull);
    expect(
      InternetTitle.parse({'id': 'invalid', 'name': 'X'}, MediaKind.movie),
      isNull,
    );
    expect(
      InternetTitle.parse({
        'id': 'tt10000001',
        'name': 'X',
        'type': 'series',
      }, MediaKind.movie),
      isNull,
    );
    expect(
      sameInternetTitle(
        demoCatalog.first.copyWith(title: 'Création fictive', year: 2025),
        title,
      ),
      isFalse,
    );
    expect(
      internetTitleKey('[FR] Création fictive (2026)'),
      'creation fictive',
    );
  });

  test('A cache write failure leaves updated data usable in memory', () async {
    final api = InternetCatalogController(
      store: _WriteFailure(),
      clientFactory: fixtureClient,
    );
    addTearDown(api.dispose);
    await api.refresh();
    expect(api.trending(MediaKind.movie), isNotEmpty);
    expect(api.running, isFalse);
    expect(api.message, contains('sauvegarde'));
  });
}

class _WriteFailure implements LocalStore {
  @override
  Future<Map<String, dynamic>> load() async => {};
  @override
  Future<void> save(Map<String, dynamic> data) async =>
      throw StateError('Test disk failure');
}
