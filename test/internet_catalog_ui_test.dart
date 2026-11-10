import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:nova_iptv/app.dart';
import 'package:nova_iptv/data/local_store.dart';
import 'package:nova_iptv/data/demo_catalog.dart';
import 'package:nova_iptv/data/source_repository.dart';
import 'package:nova_iptv/domain/source_models.dart';
import 'package:nova_iptv/sources/iptv_client.dart';
import 'package:nova_iptv/state/source_controller.dart';
import 'package:nova_iptv/domain/models.dart';
import 'package:nova_iptv/state/app_controller.dart';
import 'package:nova_iptv/state/internet_catalog_controller.dart';
import 'package:nova_iptv/ui/pages/catalog_page.dart';
import 'package:nova_iptv/ui/widgets/internet_catalog_widgets.dart';

import 'support/public_catalog_fixture.dart';

void main() {
  testWidgets(
    'Unmatched trends leave no empty headings or discovery cards on home',
    (tester) async {
      final api = InternetCatalogController(
        store: MemoryLocalStore(),
        clientFactory: fixtureClient,
      );
      await api.refresh();
      await _start(tester, api, matchingTitles: false);
      expect(find.text('Tendances du moment · Films'), findsNothing);
      expect(find.text('Tendances du moment · Séries'), findsNothing);
      expect(find.byType(InternetTitleCard), findsNothing);
      expect(find.byType(MediaPoster), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Top right update refreshes platform matches and both home trend rails without a key',
    (tester) async {
      final api = InternetCatalogController(
        store: MemoryLocalStore(),
        clientFactory: fixtureClient,
      );
      await _start(tester, api);
      await _navigate(tester, 'Par PlateForme');
      final button = find.byKey(const ValueKey('internet-update'));
      expect(find.text('Mettre a jour par internet'), findsOneWidget);
      expect(tester.getCenter(button).dx, greaterThan(900));
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(api.trending(MediaKind.movie), isNotEmpty);
      expect(api.trending(MediaKind.series), isNotEmpty);
      await tester.tap(find.byKey(const ValueKey('platform-tile-netflix')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widgetList<MediaPoster>(find.byType(MediaPoster))
            .any((p) => p.item.id == 'film-orbite'),
        isTrue,
      );
      await _navigate(tester, 'Accueil');
      expect(find.byKey(const ValueKey('home-trends-movie')), findsOneWidget);
      expect(find.byKey(const ValueKey('home-trends-series')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'An unavailable API leaves cache, navigation and home usable with no blocking dialog',
    (tester) async {
      var offline = false;
      final api = InternetCatalogController(
        store: MemoryLocalStore(),
        clientFactory: () => fixtureClient(
          handler: (request) async => offline
              ? http.Response('Unavailable', 503)
              : fixtureResponse(request.url),
        ),
      );
      await api.refresh();
      offline = true;
      await _start(tester, api);
      await _navigate(tester, 'Par PlateForme');
      await tester.tap(find.byKey(const ValueKey('internet-update')));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.textContaining('Internet indisponible'), findsOneWidget);
      await _navigate(tester, 'Films');
      expect(find.byType(MediaPoster), findsWidgets);
      await _navigate(tester, 'Accueil');
      expect(find.byKey(const ValueKey('home-trends-movie')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'An absent internet title is hidden from platform selections and cannot open discovery',
    (tester) async {
      final api = InternetCatalogController(
        store: MemoryLocalStore(),
        clientFactory: fixtureClient,
      );
      await api.refresh();
      await _start(tester, api, size: const Size(1000, 680));
      await _navigate(tester, 'Par PlateForme');
      await tester.tap(find.byKey(const ValueKey('platform-tile-primeVideo')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'selected platform page');
      expect(find.text('Voir les titres disponibles'), findsNothing);
      expect(find.byType(InternetTitleCard), findsNothing);
      expect(find.text('Autre création originale'), findsNothing);
      expect(find.widgetWithText(FilledButton, 'Lecture'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> _navigate(WidgetTester tester, String label) async {
  final text = find.text(label);
  final target = text.evaluate().isNotEmpty
      ? text.first
      : find.byTooltip(label);
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> _start(
  WidgetTester tester,
  InternetCatalogController api, {
  Size size = const Size(1440, 900),
  bool matchingTitles = true,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  final app = AppController(
    store: MemoryLocalStore({
      'settings': {'animations': false},
    }),
    internetCatalog: api,
    sources: SourceController(
      repository: MemorySourceRepository([
        SourceRecord(
          config: const SourceConfig(
            id: 'api-test',
            name: 'Fixture',
            kind: SourceKind.m3uUrl,
            address: 'https://example.test/list.m3u',
          ),
          catalog: SourceCatalog(
            items: demoCatalog
                .map(
                  (item) => item.copyWith(
                    title: matchingTitles
                        ? item.title
                        : 'Titre local ${item.id}',
                    sourceId: 'api-test',
                    mediaUrl: 'https://example.test/${item.id}.mp4',
                    detailsLoaded: true,
                  ),
                )
                .toList(),
          ),
          programmes: const [],
          updatedAt: DateTime.utc(2026),
        ),
      ]),
      client: IptvClient(),
    ),
  );
  await app.init();
  addTearDown(api.dispose);
  addTearDown(app.dispose);
  addTearDown(() => app.sources!.dispose());
  await tester.pumpWidget(
    NovaApp(controller: app, nativeReady: false, manageWindow: false),
  );
  await tester.pumpAndSettle();
}
