import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_iptv/app.dart';
import 'package:nova_iptv/data/demo_catalog.dart';
import 'package:nova_iptv/data/local_store.dart';
import 'package:nova_iptv/data/source_repository.dart';
import 'package:nova_iptv/domain/catalog_preferences.dart';
import 'package:nova_iptv/domain/models.dart';
import 'package:nova_iptv/domain/platform_catalog.dart';
import 'package:nova_iptv/domain/source_models.dart';
import 'package:nova_iptv/sources/iptv_client.dart';
import 'package:nova_iptv/state/app_controller.dart';
import 'package:nova_iptv/state/source_controller.dart';
import 'package:nova_iptv/ui/pages/catalog_page.dart';
import 'package:nova_iptv/ui/pages/home_page.dart';
import 'package:nova_iptv/ui/pages/platforms_page.dart';

void main() {
  testWidgets('Automatic reset affects only the chosen platform', (
    tester,
  ) async {
    final app = await _start(tester);
    app.updatePlatformPreferences(
      app.platformPreferences.withGroup(MediaKind.movie, 'FR | Documentaires', {
        CatalogPlatform.netflix,
        CatalogPlatform.disneyPlus,
      }),
    );
    await _navigate(tester, 'Par PlateForme');
    await tester.tap(find.byKey(const ValueKey('platform-tile-netflix')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Associer des catégories'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rétablir le classement automatique'));
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    expect(app.platformPreferences.platformsFor(app.itemById('film-foret')!), {
      CatalogPlatform.disneyPlus,
    });
    expect(_posters(tester), {'film-orbite', 'film-ambre', _series.id});
  });
  testWidgets(
    'Platform logos open only matching catalog and support type and search',
    (tester) async {
      final app = await _start(tester);
      await _navigate(tester, 'Par PlateForme');
      expect(find.byType(PlatformsPage), findsOneWidget);
      expect(find.bySemanticsLabel('Logo Netflix'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('platform-tile-netflix')));
      await tester.pumpAndSettle();
      expect(_posters(tester), {'film-orbite', 'film-ambre', _series.id});
      await tester.tap(find.widgetWithText(ChoiceChip, 'Séries'));
      await tester.pumpAndSettle();
      expect(_posters(tester), {_series.id});
      await tester.tap(find.widgetWithText(ChoiceChip, 'Tout'));
      final search = find.descendant(
        of: find.byType(PlatformsPage),
        matching: find.byType(TextField),
      );
      await tester.enterText(search, 'orbite');
      await tester.pumpAndSettle();
      expect(_posters(tester), {'film-orbite'});
      await tester.enterText(search, '');
      app.updateCatalogPreferences(
        app.catalogPreferences.copyWithRule(
          MediaKind.movie,
          const CatalogRule(hiddenLanguages: {'en'}),
        ),
      );
      await tester.pumpAndSettle();
      expect(_posters(tester), {'film-orbite', _series.id});
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Manual platform categories save and can suppress automatic matches',
    (tester) async {
      final app = await _start(tester);
      await _navigate(tester, 'Par PlateForme');
      await tester.tap(find.byKey(const ValueKey('platform-tile-netflix')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Associer des catégories'));
      await tester.pumpAndSettle();
      final docs = find.byKey(
        const ValueKey('platform-group-movie:FR | Documentaires'),
      );
      await tester.ensureVisible(docs);
      await tester.pumpAndSettle();
      await tester.tap(docs);
      final netflix = find.byKey(
        const ValueKey('platform-group-movie:FR | Netflix'),
      );
      await tester.ensureVisible(netflix);
      await tester.pumpAndSettle();
      await tester.tap(netflix);
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();
      expect(_posters(tester), {'film-foret', 'film-ambre', _series.id});
      await app.flush();
      expect(
        app.platformPreferences.platformsFor(app.itemById('film-foret')!),
        {CatalogPlatform.netflix},
      );
      expect(
        app.platformPreferences.platformsFor(app.itemById('film-orbite')!),
        isEmpty,
      );
      await tester.tap(find.text('Toutes les plateformes'));
      await tester.pumpAndSettle();
      final other = find.byKey(const ValueKey('platform-tile-other'));
      await tester.ensureVisible(other);
      await tester.tap(other);
      await tester.pumpAndSettle();
      expect(_posters(tester), {'film-orbite'});
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Home resume rail comes before featured films and right click removes from both collections',
    (tester) async {
      final app = await _start(tester, ongoing: true);
      final rail = find.byKey(const ValueKey('home-resume'));
      await tester.ensureVisible(rail);
      await tester.pumpAndSettle();
      expect(tester.widget<MediaRail>(rail).items.map((item) => item.id), [
        _series.id,
        'film-orbite',
      ]);
      final children =
          tester
                  .widget<ListView>(
                    find
                        .descendant(
                          of: find.byType(HomePage),
                          matching: find.byType(ListView),
                        )
                        .first,
                  )
                  .childrenDelegate
              as SliverChildListDelegate;
      final resumeIndex = children.children.indexWhere(
        (w) => w.key == const ValueKey('home-resume'),
      );
      final moviesIndex = children.children.indexWhere(
        (w) => w is MediaRail && w.items.any((i) => i.id == 'film-azur'),
      );
      expect(resumeIndex, lessThan(moviesIndex));
      final card = find
          .descendant(of: rail, matching: find.byType(MediaPoster))
          .first;
      await tester.tap(card, buttons: kSecondaryMouseButton);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Supprimer de Continuer à regarder'));
      await tester.pumpAndSettle();
      expect(app.resumeItems.map((i) => i.id), ['film-orbite']);
      expect(app.progress['horizons-s1-e2']!.positionSeconds, 300);
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();
      expect(app.resumeItems, hasLength(2));
      await _navigate(tester, 'Continuer à regarder');
      final seriesCard = find.byKey(ValueKey(_series.id));
      await tester.tap(seriesCard, buttons: kSecondaryMouseButton);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Supprimer de Continuer à regarder'));
      await tester.pumpAndSettle();
      expect(_posters(tester), {'film-orbite'});
      await _navigate(tester, 'Accueil');
      expect(
        tester
            .widget<MediaRail>(find.byKey(const ValueKey('home-resume')))
            .items
            .map((i) => i.id),
        ['film-orbite'],
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Platform cards and category dialog fit minimum window size', (
    tester,
  ) async {
    await _start(tester, size: const Size(1000, 680));
    await _navigate(tester, 'Par PlateForme');
    await tester.tap(find.byKey(const ValueKey('platform-tile-netflix')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Associer des catégories'));
    await tester.pumpAndSettle();
    expect(find.byType(CheckboxListTile), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}

Set<String> _posters(WidgetTester tester) => tester
    .widgetList<MediaPoster>(find.byType(MediaPoster))
    .map((w) => w.item.id)
    .toSet();
Future<void> _navigate(WidgetTester tester, String label) async {
  final text = find.text(label);
  final target = text.evaluate().isNotEmpty
      ? text.first
      : find.byTooltip(label);
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

final _series = demoCatalog
    .firstWhere(
      (item) => item.seasons.any(
        (s) => s.episodes.any((e) => e.id == 'horizons-s1-e2'),
      ),
    )
    .copyWith(category: 'FR | Netflix', sourceId: 'library');
final _items = [
  demoCatalog[0].copyWith(category: 'FR | Netflix', sourceId: 'library'),
  demoCatalog[1].copyWith(category: 'FR | Disney+', sourceId: 'library'),
  demoCatalog[2].copyWith(category: 'EN | Netflix', sourceId: 'library'),
  demoCatalog[3].copyWith(category: 'FR | Documentaires', sourceId: 'library'),
  _series,
];

Future<AppController> _start(
  WidgetTester tester, {
  Size size = const Size(1440, 900),
  bool ongoing = false,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  final sources = SourceController(
    repository: MemorySourceRepository([
      SourceRecord(
        config: const SourceConfig(
          id: 'library',
          name: 'Bibliothèque de test',
          kind: SourceKind.m3uUrl,
          address: 'https://example.test/list.m3u',
        ),
        catalog: SourceCatalog(items: _items),
        programmes: const [],
        updatedAt: DateTime.utc(2026),
      ),
    ]),
    client: IptvClient(),
  );
  final app = AppController(
    store: MemoryLocalStore({
      'settings': {'animations': false},
    }),
    sources: sources,
  );
  await app.init();
  addTearDown(app.dispose);
  addTearDown(sources.dispose);
  if (ongoing) {
    app.recordProgress(
      'film-orbite',
      WatchProgress(
        positionSeconds: 120,
        durationSeconds: 600,
        lastWatched: DateTime.utc(2026, 11, 1),
      ),
    );
    app.recordProgress(
      'horizons-s1-e2',
      WatchProgress(
        positionSeconds: 300,
        durationSeconds: 2600,
        lastWatched: DateTime.utc(2026, 11, 2),
      ),
    );
  }
  await tester.pumpWidget(
    NovaApp(controller: app, nativeReady: false, manageWindow: false),
  );
  await tester.pumpAndSettle();
  return app;
}
