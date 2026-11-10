import 'package:flutter_test/flutter_test.dart';
import 'package:nova_iptv/data/local_store.dart';
import 'package:nova_iptv/data/source_repository.dart';
import 'package:nova_iptv/domain/catalog_preferences.dart';
import 'package:nova_iptv/domain/models.dart';
import 'package:nova_iptv/domain/source_models.dart';
import 'package:nova_iptv/sources/iptv_client.dart';
import 'package:nova_iptv/state/app_controller.dart';
import 'package:nova_iptv/state/source_controller.dart';

void main() {
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
