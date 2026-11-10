import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nova_iptv/app.dart';
import 'package:nova_iptv/data/local_store.dart';
import 'package:nova_iptv/data/source_repository.dart';
import 'package:nova_iptv/domain/models.dart';
import 'package:nova_iptv/domain/source_models.dart';
import 'package:nova_iptv/sources/iptv_client.dart';
import 'package:nova_iptv/state/app_controller.dart';
import 'package:nova_iptv/state/source_controller.dart';
import 'package:nova_iptv/ui/pages/catalog_page.dart';
import 'package:nova_iptv/ui/pages/home_hub.dart';
import 'package:nova_iptv/ui/pages/live_page.dart';
import 'package:nova_iptv/ui/pages/sources_page.dart';

void main() {
  testWidgets('Settings imports a real M3U catalogue and its XMLTV guide', (
    tester,
  ) async {
    final fixture = _ProviderFixture();
    final session = await _start(tester, fixture);
    try {
      await _openSources(tester);
      expect(find.byType(SourcesPage), findsOneWidget);
      await _importForm(
        tester,
        name: 'Ma télévision',
        address: '$_server/a.m3u',
      );
      await _waitFor(tester, () => session.sources.hasConfiguredSources);
      expect(find.byType(Dialog), findsNothing);
      expect(session.app.isDemo, isFalse);
      expect(session.app.items.single.title, 'Chaîne locale A');
      expect(session.app.items.single.kind, MediaKind.live);
      expect(session.app.items.any((item) => item.isDemo), isFalse);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Guide TV'));
      await _waitFor(tester, () => session.sources.programmes.isNotEmpty);
      expect(
        session.app.guideFor(session.app.items.single).first.title,
        'Journal de la source A',
      );
      await _back(tester);
      await _navigate(tester, 'Accueil');
      expect(find.byType(HomeHub), findsOneWidget);
      expect(
        find.text('Chaîne locale A'),
        findsOneWidget,
        reason: 'A live-only catalogue must still have a working home page.',
      );
      expect(find.text('Dernière orbite'), findsNothing);
      await _navigate(tester, 'Films');
      expect(find.byType(MediaCatalogPage), findsOneWidget);
      expect(find.byType(MediaPoster), findsNothing);
      expect(find.text('Aucun résultat'), findsOneWidget);
      await _navigate(tester, 'TV en direct');
      expect(find.byType(LivePage), findsOneWidget);
      expect(find.text('Aucune source configurée'), findsNothing);
      expect(find.text('Journal de la source A'), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(
        fixture.requests.where((uri) => uri.path == '/a.m3u'),
        hasLength(1),
      );
      expect(
        fixture.requests.where((uri) => uri.path == '/a.xml'),
        hasLength(1),
      );
    } finally {
      await session.close(tester);
    }
  });

  testWidgets(
    'XMLTV aliases match channels and identical IDs stay isolated by source',
    (tester) async {
      final fixture = _ProviderFixture();
      final session = await _start(tester, fixture);
      try {
        for (final name in ['a', 'b']) {
          await _complete(
            tester,
            () => session.sources.add(
              SourceDraft(
                name: name,
                kind: SourceKind.m3uUrl,
                address: '$_server/$name.m3u',
              ),
            ),
          );
        }
        for (final source in session.sources.sources) {
          await _complete(tester, () => session.sources.refreshEpg(source.id));
        }
        await tester.pumpAndSettle();
        final a = session.app.items.firstWhere(
          (item) => item.title == 'Chaîne locale A',
        );
        final b = session.app.items.firstWhere(
          (item) => item.title == 'Chaîne locale B',
        );
        expect(a.tvgId, 'alias-fallback');
        expect(session.app.guideFor(a).map((p) => p.title), [
          'Journal de la source A',
          'Suite de la source A',
        ]);
        expect(session.app.guideFor(b).map((p) => p.title), [
          'Journal de la source B',
          'Suite de la source B',
        ]);
        await _navigate(tester, 'TV en direct');
        expect(find.text('Journal de la source A'), findsOneWidget);
        expect(find.text('Journal de la source B'), findsNothing);
        await tester.tap(find.text('Chaîne locale B').first);
        await tester.pumpAndSettle();
        expect(find.text('Journal de la source B'), findsOneWidget);
        expect(find.text('Journal de la source A'), findsNothing);
        expect(tester.takeException(), isNull);
      } finally {
        await session.close(tester);
      }
    },
  );

  testWidgets(
    'Xtream episodes, favorites and progress reopen from cache without HTTP',
    (tester) async {
      final fixture = _ProviderFixture();
      final repository = MemorySourceRepository();
      final preferences = MemoryLocalStore({
        'settings': {'animations': false},
      });
      final session = await _start(
        tester,
        fixture,
        repository: repository,
        preferences: preferences,
      );
      String? seriesId;
      String? episodeId;
      try {
        await _openSources(tester);
        await _importForm(
          tester,
          name: 'Mon compte',
          address: '$_server/proxy',
          xtream: true,
        );
        await _waitFor(tester, () => session.sources.hasConfiguredSources);
        await _back(tester);
        await _navigate(tester, 'Séries');
        expect(find.byType(MediaPoster), findsOneWidget);
        final series = session.app.items.single;
        seriesId = series.id;
        expect(series.title, 'Série du fournisseur');
        expect(series.detailsLoaded, isFalse);
        await tester.tap(find.byType(MediaPoster));
        await _waitFor(
          tester,
          () => session.app.itemById(series.id)?.detailsLoaded == true,
        );
        expect(find.text('Épisode du fournisseur'), findsOneWidget);
        expect(find.byTooltip('Lire cet épisode'), findsOneWidget);
        expect(find.textContaining('Création fictive'), findsNothing);
        await tester.ensureVisible(
          find.widgetWithText(OutlinedButton, 'Ajouter aux favoris'),
        );
        await tester.tap(
          find.widgetWithText(OutlinedButton, 'Ajouter aux favoris'),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byTooltip('Marquer comme vu'));
        await tester.tap(find.byTooltip('Marquer comme vu'));
        await tester.pumpAndSettle();
        final episode = session.app
            .itemById(series.id)!
            .seasons
            .single
            .episodes
            .single;
        episodeId = episode.id;
        expect(session.app.favorites, contains(series.id));
        expect(session.app.progress[episode.id]?.completed, isTrue);
        expect(
          episode.mediaUrl,
          contains('/proxy/series/fixture-user/fixture-password/101.mkv'),
        );
        expect(
          fixture.requests.where(
            (uri) => uri.queryParameters['action'] == 'get_series_info',
          ),
          hasLength(1),
        );
        await session.app.flush();
      } finally {
        await session.close(tester);
      }

      var offlineRequests = 0;
      final restoredSources = SourceController(
        repository: repository,
        client: IptvClient(
          clientFactory: () => MockClient((request) async {
            offlineRequests++;
            return http.Response('offline', 503);
          }),
        ),
      );
      final restoredApp = AppController(
        store: preferences,
        sources: restoredSources,
      );
      await restoredApp.init();
      final restored = _Session(restoredApp, restoredSources);
      await tester.pumpWidget(
        NovaApp(
          controller: restoredApp,
          nativeReady: false,
          manageWindow: false,
        ),
      );
      await tester.pumpAndSettle();
      try {
        expect(restoredApp.isDemo, isFalse);
        expect(restoredApp.favorites, contains(seriesId));
        expect(restoredApp.progress[episodeId]?.completed, isTrue);
        await _navigate(tester, 'Favoris');
        expect(find.byType(MediaPoster), findsOneWidget);
        await tester.tap(find.byType(MediaPoster));
        await tester.pumpAndSettle();
        expect(find.text('Épisode du fournisseur'), findsOneWidget);
        expect(find.byTooltip('Épisode vu'), findsOneWidget);
        expect(find.byTooltip('Lire cet épisode'), findsOneWidget);
        expect(
          offlineRequests,
          0,
          reason: 'Startup and a cached details sheet must not contact the provider.',
        );
        expect(tester.takeException(), isNull);
      } finally {
        await restored.close(tester);
      }
    },
  );
}

const _server = 'http://127.0.0.1:8088';

class _ProviderFixture {
  final requests = <Uri>[];
  final DateTime now = DateTime.now().toUtc();

  IptvClient client() => IptvClient(clientFactory: () => MockClient(_respond));

  Future<http.Response> _respond(http.Request request) async {
    final uri = request.url;
    requests.add(uri);
    if (uri.path == '/a.m3u' || uri.path == '/b.m3u') {
      final name = uri.path.startsWith('/a') ? 'A' : 'B';
      final id = name == 'A' ? 'alias-fallback' : 'shared';
      return http.Response(
        '#EXTM3U x-tvg-url="/${name.toLowerCase()}.xml"\n'
        '#EXTINF:-1 tvg-id="$id" group-title="Informations",Chaîne locale $name\n'
        '$_server/live/${name.toLowerCase()}.ts\n',
        200,
        headers: {'content-type': 'audio/x-mpegurl; charset=utf-8'},
      );
    }
    if (uri.path == '/a.xml' || uri.path == '/b.xml') {
      final name = uri.path.startsWith('/a') ? 'A' : 'B';
      return http.Response(
        _guide(name),
        200,
        headers: {'content-type': 'application/xml; charset=utf-8'},
      );
    }
    if (uri.path == '/proxy/player_api.php') {
      if (uri.queryParameters['username'] != 'fixture-user' ||
          uri.queryParameters['password'] != 'fixture-password') {
        return _json({
          'user_info': {'auth': 0},
        });
      }
      switch (uri.queryParameters['action']) {
        case null:
          return _json({
            'user_info': {
              'auth': 1,
              'status': 'Active',
              'allowed_output_formats': ['ts'],
            },
          });
        case 'get_live_categories':
        case 'get_vod_categories':
        case 'get_series_categories':
          return _json([
            {'category_id': '7', 'category_name': 'Fournisseur'},
          ]);
        case 'get_live_streams':
        case 'get_vod_streams':
          return _json([]);
        case 'get_series':
          return _json([
            {
              'series_id': 10,
              'name': 'Série du fournisseur',
              'category_id': '7',
            },
          ]);
        case 'get_series_info':
          return _json({
            'info': {'plot': 'Synopsis fourni par le serveur.'},
            'episodes': {
              '1': [
                {
                  'id': 101,
                  'episode_num': 1,
                  'title': 'Épisode du fournisseur',
                  'container_extension': 'mkv',
                  'info': {'duration_secs': 1800},
                },
              ],
            },
          });
      }
    }
    return http.Response('fixture route not found', 404);
  }

  String _guide(String name) {
    final start = now.subtract(const Duration(hours: 1));
    final next = now.add(const Duration(hours: 1));
    final end = now.add(const Duration(hours: 2));
    return '<tv><channel id="shared"><display-name>Chaîne locale $name</display-name></channel>'
        '<programme channel="shared" start="${_xmlTime(start)} +0000" stop="${_xmlTime(next)} +0000">'
        '<title>Journal de la source $name</title><desc>Guide personnel $name.</desc></programme>'
        '<programme channel="shared" start="${_xmlTime(next)} +0000" stop="${_xmlTime(end)} +0000">'
        '<title>Suite de la source $name</title></programme></tv>';
  }
}

http.Response _json(Object value) => http.Response(
  jsonEncode(value),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);
String _xmlTime(DateTime date) =>
    '${date.year}${_two(date.month)}${_two(date.day)}${_two(date.hour)}${_two(date.minute)}${_two(date.second)}';
String _two(int value) => value.toString().padLeft(2, '0');

Future<_Session> _start(
  WidgetTester tester,
  _ProviderFixture fixture, {
  MemorySourceRepository? repository,
  MemoryLocalStore? preferences,
}) async {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final sources = SourceController(
    repository: repository ?? MemorySourceRepository(),
    client: fixture.client(),
  );
  final app = AppController(
    store:
        preferences ??
        MemoryLocalStore({
          'settings': {'animations': false},
        }),
    sources: sources,
  );
  await app.init();
  await tester.pumpWidget(
    NovaApp(controller: app, nativeReady: false, manageWindow: false),
  );
  await tester.pumpAndSettle();
  return _Session(app, sources);
}

Future<void> _openSources(WidgetTester tester) async {
  await _navigate(tester, 'Paramètres');
  final button = find.byKey(const Key('manage-sources'));
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

Future<void> _importForm(
  WidgetTester tester, {
  required String name,
  required String address,
  bool xtream = false,
}) async {
  await tester.tap(find.byKey(const Key('add-source')));
  await tester.pumpAndSettle();
  if (xtream) {
    await tester.tap(find.byType(DropdownButtonFormField<SourceKind>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xtream Codes').last);
    await tester.pumpAndSettle();
  }
  await _enter(tester, 'source-name', name);
  await _enter(tester, 'source-address', address);
  if (xtream) {
    await _enter(tester, 'source-username', 'fixture-user');
    await _enter(tester, 'source-password', 'fixture-password');
  }
  await tester.tap(find.byKey(const Key('save-source')));
}

Future<void> _enter(WidgetTester tester, String key, String value) async {
  final field = find.byKey(Key(key));
  await tester.ensureVisible(field);
  await tester.pumpAndSettle();
  await tester.enterText(field, value);
  await tester.pumpAndSettle();
}

Future<void> _waitFor(WidgetTester tester, bool Function() condition) async {
  final watch = Stopwatch()..start();
  while (!condition()) {
    if (watch.elapsed > const Duration(seconds: 8)) {
      throw TimeoutException('Fixture operation did not complete.');
    }
    // UI callbacks use the test zone; compute runs on a real isolate.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

Future<void> _complete(
  WidgetTester tester,
  Future<void> Function() action,
) async {
  var done = false;
  Object? error;
  unawaited(
    Future<void>.sync(action).then(
      (_) {
        done = true;
      },
      onError: (Object caught, StackTrace stack) {
        error = caught;
        done = true;
      },
    ),
  );
  await _waitFor(tester, () => done);
  if (error != null) throw error!;
}

Future<void> _back(WidgetTester tester) async {
  Navigator.of(tester.element(find.byType(SourcesPage))).pop();
  await tester.pumpAndSettle();
}

Future<void> _navigate(WidgetTester tester, String label) async {
  await tester.tap(find.text(label).first);
  await tester.pumpAndSettle();
}

class _Session {
  _Session(this.app, this.sources);
  final AppController app;
  final SourceController sources;
  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await app.shutdown();
    app.dispose();
    sources.dispose();
  }
}
