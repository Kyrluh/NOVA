import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:nova_iptv/data/local_store.dart';
import 'package:nova_iptv/data/source_repository.dart';
import 'package:nova_iptv/domain/catalog_preferences.dart';
import 'package:nova_iptv/domain/models.dart';
import 'package:nova_iptv/domain/source_models.dart';
import 'package:nova_iptv/sources/iptv_client.dart';
import 'package:nova_iptv/state/app_controller.dart';
import 'package:nova_iptv/state/source_controller.dart';
import 'package:nova_iptv/ui/tv/tv_live.dart';
import 'package:nova_iptv/ui/tv/tv_widgets.dart';

void main() {
  test('Dedicated TV repairs old alphabetical order for each profile and retains later explicit choices', () async {
    Map<String, dynamic> profile(String id) => {
      'id': id,
      'name': id,
      'genresConfigured': true,
      'androidTvSourceOrderVersion': 1,
      'catalogPreferences': const CatalogPreferences()
          .copyWithRule(
            MediaKind.live,
            const CatalogRule(
              order: CatalogOrder.titleAsc,
              hiddenLanguages: {'de'},
            ),
          )
          .toJson(),
      'favorites': ['TF1'],
    };
    final store = MemoryLocalStore({
      'profiles': [profile('one'), profile('two')],
      'activeProfileId': 'one',
    });
    final app = AppController(store: store, android: true, television: true);
    await app.init();
    expect(
      app.catalogPreferences.ruleFor(MediaKind.live).order,
      CatalogOrder.source,
    );
    app.selectProfile('two');
    expect(
      app.catalogPreferences.ruleFor(MediaKind.live).order,
      CatalogOrder.source,
    );
    expect(app.catalogPreferences.ruleFor(MediaKind.live).hiddenLanguages, {
      'de',
    });
    expect(app.favorites, contains('TF1'));
    app.updateCatalogPreferences(
      app.catalogPreferences.copyWithRule(
        MediaKind.live,
        app.catalogPreferences
            .ruleFor(MediaKind.live)
            .copyWith(order: CatalogOrder.titleAsc),
      ),
    );
    await app.flush();
    app.dispose();
    final restored = AppController(
      store: store,
      android: true,
      television: true,
    );
    await restored.init();
    expect(
      restored.catalogPreferences.ruleFor(MediaKind.live).order,
      CatalogOrder.titleAsc,
    );
    restored.selectProfile('one');
    expect(
      restored.catalogPreferences.ruleFor(MediaKind.live).order,
      CatalogOrder.source,
    );
    await restored.flush();
    restored.dispose();
  });

  testWidgets(
    'TV channel tiles follow provider order after profile repair, filtering and explicit order changes',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1200, 800);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final source = SourceController(
        repository: MemorySourceRepository([
          SourceRecord(
            config: const SourceConfig(
              id: 'source',
              name: 'Fixture',
              kind: SourceKind.m3uUrl,
              address: 'https://example.test/list.m3u',
            ),
            catalog: SourceCatalog(
              items: [
                for (final title in ['TF1', 'France 2', 'Arte'])
                  MediaItem(
                    id: title,
                    title: title,
                    kind: MediaKind.live,
                    category: 'FR | TNT',
                    description: '',
                    year: 0,
                    durationMinutes: 0,
                    palette: 0,
                    subtitle: '',
                    art: 0,
                    sourceId: 'source',
                  ),
              ],
            ),
            programmes: const [],
            updatedAt: DateTime.utc(2026),
          ),
        ]),
        client: IptvClient(),
      );
      final app = AppController(
        store: MemoryLocalStore({
          'androidTvSourceOrderVersion': 1,
          'catalogPreferences': const CatalogPreferences()
              .copyWithRule(
                MediaKind.live,
                const CatalogRule(order: CatalogOrder.titleAsc),
              )
              .toJson(),
        }),
        sources: source,
        android: true,
        television: true,
      );
      await app.init();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: TvLive(controller: app, nativeReady: false)),
        ),
      );
      await tester.pumpAndSettle();
      List<String> titles() => tester
          .widgetList<TvTile>(find.byType(TvTile))
          .map((w) => w.label!)
          .toList();
      expect(titles(), ['TF1', 'France 2', 'Arte']);
      await tester.enterText(find.byType(TextField), 'France');
      await tester.pumpAndSettle();
      expect(titles(), ['France 2']);
      await tester.enterText(find.byType(TextField), '');
      await tester.pumpAndSettle();
      tester
          .widget<DropdownButtonFormField<CatalogOrder>>(
            find.byType(DropdownButtonFormField<CatalogOrder>),
          )
          .onChanged!(CatalogOrder.titleAsc);
      await tester.pumpAndSettle();
      expect(titles(), ['Arte', 'France 2', 'TF1']);
      tester
          .widget<DropdownButtonFormField<CatalogOrder>>(
            find.byType(DropdownButtonFormField<CatalogOrder>),
          )
          .onChanged!(CatalogOrder.source);
      await tester.pumpAndSettle();
      expect(titles(), ['TF1', 'France 2', 'Arte']);
      expect(tester.takeException(), isNull);
      tester.view.physicalSize = const Size(480, 300);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await app.flush();
      await tester.pumpWidget(const SizedBox());
      app.dispose();
      source.dispose();
    },
  );
  test('Android restores provider channel order once and preserves filters, favorites and progress', () async {
    final original = CatalogPreferences().copyWithRule(
      MediaKind.live,
      const CatalogRule(order: CatalogOrder.titleAsc, hiddenLanguages: {'de'}),
    );
    final store = MemoryLocalStore({
      'catalogPreferences': original.toJson(),
      'favorites': ['TF1'],
      'progress': {
        'TF1': WatchProgress(
          positionSeconds: 0,
          durationSeconds: 0,
          lastWatched: DateTime.utc(2026),
        ).toJson(),
      },
    });
    final sources = SourceController(
      repository: MemorySourceRepository([
        SourceRecord(
          config: const SourceConfig(
            id: 'source',
            name: 'Fixture',
            kind: SourceKind.m3uUrl,
            address: 'https://example.test/list.m3u',
          ),
          catalog: SourceCatalog(
            items: [
              for (final title in ['TF1', 'France 2', 'Arte'])
                MediaItem(
                  id: title,
                  title: title,
                  kind: MediaKind.live,
                  category: 'FR | TNT',
                  description: '',
                  year: 0,
                  durationMinutes: 0,
                  palette: 0,
                  subtitle: '',
                  art: 0,
                  sourceId: 'source',
                ),
            ],
          ),
          programmes: const [],
          updatedAt: DateTime.utc(2026),
        ),
      ]),
      client: IptvClient(),
    );
    addTearDown(sources.close);
    final app = AppController(store: store, sources: sources, android: true);
    addTearDown(app.dispose);
    await app.init();
    expect(app.items.map((i) => i.title), ['TF1', 'France 2', 'Arte']);
    expect(app.catalogPreferences.ruleFor(MediaKind.live).hiddenLanguages, {
      'de',
    });
    expect(store.data['favorites'], ['TF1']);
    expect((store.data['progress'] as Map).keys, contains('TF1'));
    app.updateCatalogPreferences(
      app.catalogPreferences.copyWithRule(
        MediaKind.live,
        app.catalogPreferences
            .ruleFor(MediaKind.live)
            .copyWith(order: CatalogOrder.titleAsc),
      ),
    );
    await app.flush();
    final restored = AppController(
      store: store,
      sources: sources,
      android: true,
    );
    addTearDown(restored.dispose);
    await restored.init();
    expect(restored.items.first.title, 'Arte');
  });

  test('Windows sorting preferences are retained', () async {
    final store = MemoryLocalStore({
      'catalogPreferences': CatalogPreferences()
          .copyWithRule(
            MediaKind.live,
            const CatalogRule(order: CatalogOrder.titleAsc),
          )
          .toJson(),
    });
    final app = AppController(store: store, android: false);
    addTearDown(app.dispose);
    await app.init();
    expect(
      app.catalogPreferences.ruleFor(MediaKind.live).order,
      CatalogOrder.titleAsc,
    );
  });
}
