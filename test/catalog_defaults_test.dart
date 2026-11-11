import 'package:flutter_test/flutter_test.dart';
import 'package:nova_iptv/data/local_store.dart';
import 'package:nova_iptv/data/source_repository.dart';
import 'package:nova_iptv/domain/catalog_defaults_data.dart';
import 'package:nova_iptv/domain/catalog_preferences.dart';
import 'package:nova_iptv/domain/models.dart';
import 'package:nova_iptv/domain/source_models.dart';
import 'package:nova_iptv/sources/iptv_client.dart';
import 'package:nova_iptv/state/app_controller.dart';
import 'package:nova_iptv/state/source_controller.dart';

List<MediaItem> fixture(String source) => [
  for (final entry in [
    ('live-fr', MediaKind.live, 'FR | TNT'),
    ('live-de', MediaKind.live, 'DE | GENERAL'),
    ('live-be', MediaKind.live, 'BELGIUM'),
    ('movie-fr', MediaKind.movie, 'FR · Films'),
    ('movie-es', MediaKind.movie, 'ES · Films'),
    ('movie-karaoke', MediaKind.movie, ' Karaoké '),
    ('series-fr', MediaKind.series, 'FR · Séries'),
    ('series-crave', MediaKind.series, 'Séries CRAVE'),
    ('series-ar', MediaKind.series, 'Séries ARABES'),
  ])
    MediaItem(
      id: '$source:${entry.$1}',
      title: entry.$1,
      kind: entry.$2,
      category: entry.$3,
      description: '',
      year: 2025,
      durationMinutes: 90,
      palette: 0,
      subtitle: '',
      art: 0,
      sourceId: source,
    ),
];

Future<(AppController, SourceController)> start(
  MemoryLocalStore store, {
  bool cached = true,
}) async {
  final sources = SourceController(
    repository: MemorySourceRepository([
      if (cached)
        SourceRecord(
          config: const SourceConfig(
            id: 'different-installation',
            name: 'Fixture',
            kind: SourceKind.xtream,
            address: 'https://example.test',
          ),
          catalog: SourceCatalog(items: fixture('different-installation')),
          programmes: const [],
          updatedAt: DateTime.utc(2026),
        ),
    ]),
    client: _Client(),
  );
  final app = AppController(store: store, sources: sources, android: false);
  await app.init();
  addTearDown(() {
    app.dispose();
    sources.dispose();
  });
  return (app, sources);
}

void main() {
  test('Fresh profile reproduces portable Windows filters with different source IDs', () async {
    final (app, _) = await start(MemoryLocalStore());
    expect(app.items.map((i) => i.id.split(':').last), [
      'live-fr',
      'movie-fr',
      'series-fr',
    ]);
    expect(
      app.catalogPreferences.ruleFor(MediaKind.live).hiddenLanguages,
      containsAll(['de', 'ar', 'es']),
    );
    expect(
      app.catalogPreferences.ruleFor(MediaKind.live).hiddenLanguages,
      isNot(contains('fr')),
    );
    expect(
      app.catalogPreferences.ruleFor(MediaKind.live).hiddenLanguages,
      isNot(contains('en')),
    );
    expect(
      app.catalogPreferences.ruleFor(MediaKind.live).hiddenCategories.single,
      'different-installation|live|BELGIUM',
    );
    expect(catalogDefaultsJson, isNot(contains('src-')));
  });

  test(
    'First source imported after onboarding receives the category defaults',
    () async {
      final (app, sources) = await start(MemoryLocalStore(), cached: false);
      await sources.add(
        const SourceDraft(
          name: 'Fixture',
          kind: SourceKind.xtream,
          address: 'https://example.test',
          username: 'fixture',
          password: 'fixture',
        ),
      );
      expect(app.items.map((i) => i.id.split(':').last), [
        'live-fr',
        'movie-fr',
        'series-fr',
      ]);
      expect(
        app.catalogPreferences.ruleFor(MediaKind.live).hiddenCategories.single,
        startsWith('${Uri.encodeComponent(sources.sources.single.id)}|live|'),
      );
    },
  );

  test(
    'Rechecked categories and languages survive refresh and restart',
    () async {
      final store = MemoryLocalStore();
      final (app, sources) = await start(store);
      final rule = app.catalogPreferences.ruleFor(MediaKind.movie);
      app.updateCatalogPreferences(
        app.catalogPreferences.copyWithRule(
          MediaKind.movie,
          rule.copyWith(
            hiddenLanguages: {...rule.hiddenLanguages}..remove('es'),
            hiddenCategories: {},
          ),
        ),
      );
      await sources.refresh('different-installation');
      expect(
        app.items.map((i) => i.id),
        containsAll([
          'different-installation:movie-es',
          'different-installation:movie-karaoke',
        ]),
      );
      await app.flush();
      final restored = AppController(
        store: store,
        sources: sources,
        android: false,
      );
      await restored.init();
      expect(
        restored.items.map((i) => i.id),
        containsAll([
          'different-installation:movie-es',
          'different-installation:movie-karaoke',
        ]),
      );
      restored.dispose();
    },
  );

  test('Existing empty preferences remain untouched while a new profile starts with defaults', () async {
    final (app, _) = await start(
      MemoryLocalStore({
        'catalogPreferences': const CatalogPreferences().toJson(),
      }),
    );
    expect(app.items.length, 9);
    final id = app.createProfile('Nouveau');
    app.selectProfile(id);
    expect(app.items.map((i) => i.id.split(':').last), [
      'live-fr',
      'movie-fr',
      'series-fr',
    ]);
    app.selectProfile('main');
    expect(app.items.length, 9);
  });
}

class _Client extends IptvClient {
  @override
  Future<SourceCatalog> loadCatalog(
    SourceConfig config, {
    CancellationToken? cancel,
  }) async => SourceCatalog(items: fixture(config.id));
}
