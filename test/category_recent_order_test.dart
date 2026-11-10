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
import 'package:nova_iptv/ui/pages/catalog_page.dart';
import 'package:nova_iptv/ui/tv/tv_catalog.dart';

void main() {
  for (final kind in [MediaKind.movie, MediaKind.series]) {
    testWidgets(
      '${kind.name}: provider category defaults to newest additions on desktop/mobile and TV',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final originals = demoCatalog
            .where((i) => i.kind == kind)
            .take(3)
            .toList();
        final items = [
          originals[0].copyWith(
            title: 'Ancien',
            category: 'Horreur',
            addedAt: DateTime.utc(2024),
            sourceId: 'fixture',
          ),
          originals[1].copyWith(
            title: 'Nouveau',
            category: 'Horreur',
            addedAt: DateTime.utc(2025),
            sourceId: 'fixture',
          ),
          originals[2].copyWith(
            title: 'Autre genre',
            category: 'Comédie',
            addedAt: DateTime.utc(2026),
            sourceId: 'fixture',
          ),
        ];
        final sources = SourceController(
          repository: MemorySourceRepository([
            SourceRecord(
              config: const SourceConfig(
                id: 'fixture',
                name: 'Fixture',
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
        addTearDown(() {
          app.dispose();
          sources.dispose();
        });
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MediaCatalogPage(
                controller: app,
                kind: kind,
                onDetails: (_) {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(ChoiceChip, 'Horreur'));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<CatalogGrid>(find.byType(CatalogGrid))
              .items
              .map((i) => i.title),
          ['Nouveau', 'Ancien'],
        );
        expect(
          tester
              .widget<DropdownButtonFormField<String>>(
                find.byType(DropdownButtonFormField<String>),
              )
              .initialValue,
          'recent',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: TvCatalog(
                controller: app,
                items: items,
                recentCategory: true,
                onDetails: (_) {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        tester
            .widget<DropdownButtonFormField<String>>(
              find.byType(DropdownButtonFormField<String>),
            )
            .onChanged!('Horreur');
        await tester.pumpAndSettle();
        final grid = tester.widget<GridView>(find.byType(GridView));
        final delegate = grid.childrenDelegate as SliverChildBuilderDelegate;
        expect(delegate.childCount, 2);
        final first = delegate.builder(
          tester.element(find.byType(GridView)),
          0,
        )!;
        expect(first.key, ValueKey('tv-card-${items[1].id}'));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
