import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_iptv/data/demo_catalog.dart';
import 'package:nova_iptv/data/local_store.dart';
import 'package:nova_iptv/data/source_repository.dart';
import 'package:nova_iptv/domain/models.dart';
import 'package:nova_iptv/domain/source_models.dart';
import 'package:nova_iptv/sources/iptv_client.dart';
import 'package:nova_iptv/state/app_controller.dart';
import 'package:nova_iptv/state/source_controller.dart';
import 'package:nova_iptv/ui/adaptive.dart';
import 'package:nova_iptv/ui/pages/catalog_page.dart';
import 'package:nova_iptv/ui/theme.dart';

void main() {
  Future<AppController> start(
    WidgetTester tester, {
    bool mobile = false,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = mobile
        ? const Size(390, 844)
        : const Size(1280, 850);
    final seed = demoCatalog.firstWhere((item) => item.kind == MediaKind.movie);
    final items = List<MediaItem>.generate(
      80,
      (index) => MediaItem.fromJson({
        ...seed.toJson(),
        'id': 'adaptive-movie-$index',
        'title': 'Film $index',
        'category': 'Genre $index',
        'sourceId': 'adaptive-fixture',
        'detailsLoaded': true,
      }),
    );
    final sources = SourceController(
      repository: MemorySourceRepository([
        SourceRecord(
          config: const SourceConfig(
            id: 'adaptive-fixture',
            name: 'Démonstration',
            kind: SourceKind.m3uUrl,
            address: 'https://example.test/list.m3u',
          ),
          catalog: SourceCatalog(items: items),
          programmes: const [],
          updatedAt: DateTime.utc(2026),
        ),
      ]),
      client: IptvClient(),
    );
    final app = AppController(store: MemoryLocalStore(), sources: sources);
    await app.init();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      app.dispose();
      sources.dispose();
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.view.resetViewInsets();
    });
    return app;
  }

  Widget catalog(AppController app) => MediaCatalogPage(
    key: const ValueKey('adaptive-movies'),
    controller: app,
    kind: MediaKind.movie,
    onDetails: (_) {},
  );

  testWidgets(
    'Desktop categories stay bounded and searchable for a large source',
    (tester) async {
      final app = await start(tester);
      await tester.pumpWidget(
        MaterialApp(
          theme: novaTheme(app.settings.accent),
          home: Scaffold(body: catalog(app)),
        ),
      );
      await tester.pumpAndSettle();
      final strip = tester.getRect(
        find.byKey(const ValueKey('catalog-category-strip')),
      );
      expect(strip.height, 48);
      expect(find.byType(SliverGrid), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('catalog-category-picker')));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('catalog-category-search')),
        'Genre 52',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Genre 52'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<CatalogGrid>(find.byType(CatalogGrid)).items.single.title,
        'Film 52',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Android category picker uses a touch sheet and stays usable with the keyboard',
    (tester) async {
      final app = await start(tester, mobile: true);
      await tester.pumpWidget(
        MaterialApp(
          theme: novaTheme(app.settings.accent),
          home: NovaAdaptiveScope(
            android: true,
            child: Scaffold(body: catalog(app)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('catalog-category-picker')));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.byType(Dialog), findsNothing);
      final search = find.byKey(const ValueKey('catalog-category-search'));
      expect(tester.widget<TextField>(search).autofocus, isFalse);
      await tester.enterText(search, 'Genre 7');
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.widgetWithText(ListTile, 'Genre 7'));
      await tester.pumpAndSettle();
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      expect(
        tester.widget<CatalogGrid>(find.byType(CatalogGrid)).items.single.title,
        'Film 7',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Catalogue restores search category and sort after settings and can reset empty results',
    (tester) async {
      final app = await start(tester);
      late StateSetter update;
      var showingCatalog = true;
      await tester.pumpWidget(
        MaterialApp(
          theme: novaTheme(app.settings.accent),
          home: Scaffold(
            body: StatefulBuilder(
              builder: (_, setState) {
                update = setState;
                return showingCatalog ? catalog(app) : const Text('Paramètres');
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'Tout explorer'));
      await tester.pumpAndSettle();
      tester
          .widget<DropdownButtonFormField<String>>(
            find.byType(DropdownButtonFormField<String>),
          )
          .onChanged!('title');
      await tester.enterText(find.byType(TextField), 'Film 1');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('catalog-category-picker')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('catalog-category-search')),
        'Genre 11',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Genre 11'));
      await tester.pumpAndSettle();
      update(() => showingCatalog = false);
      await tester.pumpAndSettle();
      update(() => showingCatalog = true);
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Film 1',
      );
      expect(
        tester
            .widget<DropdownButtonFormField<String>>(
              find.byType(DropdownButtonFormField<String>),
            )
            .initialValue,
        'title',
      );
      expect(
        tester.widget<CatalogGrid>(find.byType(CatalogGrid)).items.single.title,
        'Film 11',
      );
      await tester.enterText(find.byType(TextField), 'Introuvable');
      await tester.pumpAndSettle();
      expect(find.text('Aucun résultat pour « Introuvable »'), findsOneWidget);
      final reset = find.byKey(const ValueKey('catalog-reset-filters'));
      await tester.ensureVisible(reset);
      await tester.tap(reset);
      await tester.pumpAndSettle();
      expect(
        tester.widget<CatalogGrid>(find.byType(CatalogGrid)).items.length,
        80,
      );
      expect(
        tester
            .widget<DropdownButtonFormField<String>>(
              find.byType(DropdownButtonFormField<String>),
            )
            .initialValue,
        'recent',
      );
      expect(tester.takeException(), isNull);
    },
  );
}
