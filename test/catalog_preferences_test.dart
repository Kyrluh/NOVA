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
  test('Language visibility is independent for TV, films and series', () {
    final items = [
      _item('tv', kind: MediaKind.live, title: 'EN: News'),
      _item('film', title: '[EN] Film'),
      _item('series', kind: MediaKind.series, title: 'EN| Series'),
    ];
    final preferences = const CatalogPreferences().copyWithRule(
      MediaKind.live,
      const CatalogRule(hiddenLanguages: {'en'}),
    );
    expect(_ids(applyCatalogPreferences(items, preferences)), [
      'film',
      'series',
    ]);
    expect(preferences.ruleFor(MediaKind.movie).hiddenLanguages, isEmpty);
  });

  test('Unidentified languages are visible unless explicitly hidden', () {
    final unknown = _item('unknown', title: 'Orbite');
    expect(inferCatalogLanguage(unknown), 'unknown');
    expect(catalogLanguageLabel('unknown'), 'Non renseignée');
    expect(applyCatalogPreferences([unknown], const CatalogPreferences()), [
      unknown,
    ]);
    final preferences = const CatalogPreferences().copyWithRule(
      MediaKind.movie,
      const CatalogRule(hiddenLanguages: {'unknown'}),
    );
    expect(applyCatalogPreferences([unknown], preferences), isEmpty);
  });

  test(
    'Language tags are explicit and ordinary title words stay unidentified',
    () {
      for (final entry in {
        'FR| TF1': 'fr',
        '[EN] Movie': 'en',
        'EN: Movie': 'en',
        'FR - Journal': 'fr',
        'Movie (DE)': 'de',
        '[UA] News': 'uk',
        'En attendant': 'unknown',
        'De beaux lendemains': 'unknown',
        'It': 'unknown',
        'No country for old men': 'unknown',
        'Film VOSTFR': 'unknown',
        '[FR] [EN] Film': 'unknown',
      }.entries) {
        expect(
          inferCatalogLanguage(_item('a', title: entry.key)),
          entry.value,
          reason: entry.key,
        );
      }
      for (final entry in {
        'Français': 'fr',
        'French cinema': 'fr',
        'France': 'fr',
        'US': 'en',
        'UK | SPORTS': 'en',
        'Arab': 'ar',
        'EN Entertainment': 'en',
        'Canales de España': 'es',
        'Films de guerre': 'unknown',
        'Ukrainian': 'uk',
      }.entries) {
        expect(
          inferCatalogLanguage(_item('a', category: entry.key)),
          entry.value,
          reason: entry.key,
        );
      }
    },
  );

  test('Manual category language corrects metadata and supports unknown', () {
    final first = _item('one', title: 'EN: One', category: 'French films');
    final second = _item('two', title: 'EN: Two', category: 'French films');
    final key = catalogCategoryKey(first);
    expect(inferCatalogLanguage(first), 'fr');
    expect(inferCatalogLanguage(first, overrides: {key: 'ja'}), 'ja');
    expect(
      inferCatalogLanguage(second, overrides: {key: 'unknown'}),
      'unknown',
    );
    expect(inferCatalogLanguage(first, overrides: {key: 'invalid'}), 'fr');
    final preferences = const CatalogPreferences().copyWithRule(
      MediaKind.movie,
      CatalogRule(
        hiddenLanguages: const {'ja'},
        languageOverrides: {key: 'ja'},
      ),
    );
    expect(applyCatalogPreferences([first, second], preferences), isEmpty);
  });

  test('Category identity separates sources and kinds and excludes URLs', () {
    final first = _item('one', category: 'Films | nouveautés');
    final otherSource = _item(
      'two',
      category: first.category,
      sourceId: 'other',
    );
    final otherKind = _item(
      'three',
      category: first.category,
      kind: MediaKind.live,
    );
    expect(catalogCategoryKey(first), isNot(catalogCategoryKey(otherSource)));
    expect(catalogCategoryKey(first), isNot(catalogCategoryKey(otherKind)));
    expect(catalogCategoryKey(first), isNot(contains('password')));
    final preferences = const CatalogPreferences().copyWithRule(
      MediaKind.movie,
      CatalogRule(hiddenCategories: {catalogCategoryKey(first)}),
    );
    expect(
      _ids(
        applyCatalogPreferences([first, otherSource, otherKind], preferences),
      ),
      ['two', 'three'],
    );
  });

  test(
    'Titles sort with accents normalized and equal keys preserve source order',
    () {
      final items = [
        _item('z', title: 'Zèbre'),
        _item('tv', kind: MediaKind.live),
        _item('e1', title: 'Éclair'),
        _item('e2', title: 'eclair'),
        _item('a', title: 'Abricot'),
      ];
      final preferences = const CatalogPreferences().copyWithRule(
        MediaKind.movie,
        const CatalogRule(order: CatalogOrder.titleAsc),
      );
      expect(_ids(applyCatalogPreferences(items, preferences)), [
        'a',
        'tv',
        'e1',
        'e2',
        'z',
      ]);
      expect(_ids(applyCatalogPreferences(items, const CatalogPreferences())), [
        'z',
        'tv',
        'e1',
        'e2',
        'a',
      ]);
      expect(
        _ids(
          applyCatalogPreferences(
            items,
            preferences.copyWithRule(
              MediaKind.movie,
              const CatalogRule(order: CatalogOrder.titleDesc),
            ),
          ),
        ),
        ['z', 'tv', 'e1', 'e2', 'a'],
      );
    },
  );

  test('Newest release ordering places missing years last', () {
    final items = [
      _item('unknown', year: 0),
      _item('old', year: 2001),
      _item('new', year: 2026),
    ];
    final preferences = const CatalogPreferences().copyWithRule(
      MediaKind.movie,
      const CatalogRule(order: CatalogOrder.yearDesc),
    );
    expect(_ids(applyCatalogPreferences(items, preferences)), [
      'new',
      'old',
      'unknown',
    ]);
  });

  test('Custom categories come first, titles inside them sort A to Z', () {
    final items = [
      _item('a2', title: 'Zulu', category: 'Action'),
      _item('c', title: 'Film', category: 'Comédie'),
      _item('a1', title: 'Alpha', category: 'Action'),
      _item('d', category: 'Drame'),
    ];
    final preferences = const CatalogPreferences().copyWithRule(
      MediaKind.movie,
      CatalogRule(
        order: CatalogOrder.category,
        categoryOrder: [
          catalogCategoryKey(items[1]),
          catalogCategoryKey(items[0]),
        ],
      ),
    );
    expect(_ids(applyCatalogPreferences(items, preferences)), [
      'c',
      'a1',
      'a2',
      'd',
    ]);
  });

  test('Invalid serialized fields are ignored without losing valid rules', () {
    final parsed = CatalogPreferences.fromJson({
      'rules': {
        'live': {
          'order': 'titleAsc',
          'hiddenLanguages': ['en', 12, 'invented'],
        },
        'movie': {
          'order': 123,
          'hiddenCategories': ['saved|movie|films', false, ''],
          'categoryOrder': ['saved|movie|films', 'saved|movie|films', null],
          'languageOverrides': {'ok': 'fr', 'bad': 'invented', 12: 'en'},
        },
        'series': false,
        'unknownKind': {'order': 'titleDesc'},
      },
    });
    expect(parsed.ruleFor(MediaKind.live).order, CatalogOrder.titleAsc);
    expect(parsed.ruleFor(MediaKind.live).hiddenLanguages, {'en'});
    final movie = parsed.ruleFor(MediaKind.movie);
    expect(movie.order, CatalogOrder.source);
    expect(movie.hiddenCategories, {'saved|movie|films'});
    expect(movie.categoryOrder, ['saved|movie|films']);
    expect(movie.languageOverrides, {'ok': 'fr'});
    expect(
      CatalogPreferences.fromJson(parsed.toJson()).toJson(),
      parsed.toJson(),
    );
    for (final invalid in [
      null,
      1,
      'broken',
      [],
      {'rules': 12},
    ]) {
      expect(
        CatalogPreferences.fromJson(invalid).ruleFor(MediaKind.movie).order,
        CatalogOrder.source,
      );
    }
    final bounded = CatalogRule.fromJson({
      'hiddenCategories': List.generate(20020, (i) => 'category-$i'),
      'languageOverrides': {'x' * 5000: 'fr'},
    });
    expect(bounded.hiddenCategories.length, 20000);
    expect(bounded.languageOverrides, isEmpty);
    expect(() => movie.hiddenLanguages.add('fr'), throwsUnsupportedError);
    expect(() => movie.categoryOrder.add('other'), throwsUnsupportedError);
    expect(() => movie.languageOverrides['ok'] = 'en', throwsUnsupportedError);
  });

  test(
    'Controller caches lists and invalidates on rules and source revisions',
    () async {
      final client = _Client();
      final source = SourceController(
        repository: _repository([_item('one', title: 'FR| Film')]),
        client: client,
      );
      final controller = AppController(
        store: MemoryLocalStore(),
        sources: source,
      );
      addTearDown(() async {
        await controller.shutdown();
        controller.dispose();
        source.dispose();
      });
      await controller.init();
      final original = controller.items;
      expect(identical(original, controller.items), isTrue);
      controller.updateCatalogPreferences(
        const CatalogPreferences().copyWithRule(
          MediaKind.movie,
          const CatalogRule(hiddenLanguages: {'en'}),
        ),
      );
      final filtered = controller.items;
      expect(identical(original, filtered), isFalse);
      expect(identical(filtered, controller.items), isTrue);
      client.nextCatalog = SourceCatalog(
        items: [_item('one', title: 'EN: Film')],
      );
      await source.refresh('saved');
      expect(controller.items, isEmpty);
      expect(controller.allItems.single.title, 'EN: Film');
      expect(controller.itemById('one'), isNotNull);
      await controller.flush();
    },
  );

  test('Hidden favorites and episode progress survive restart and becoming visible', () async {
    final episode = const DemoEpisode(
      id: 'episode',
      title: 'Episode',
      number: 1,
      durationMinutes: 40,
    );
    final film = _item('film', title: 'EN: Film');
    final series = _item('series', kind: MediaKind.series, title: 'EN: Series')
        .copyWith(
          seasons: [
            DemoSeason(number: 1, episodes: [episode]),
          ],
        );
    final repository = _repository([film, series]);
    final store = MemoryLocalStore();
    final source = SourceController(repository: repository, client: _Client());
    final controller = AppController(store: store, sources: source);
    await controller.init();
    controller.toggleFavorite('film');
    controller.toggleFavorite('series');
    controller.recordProgress(
      'episode',
      WatchProgress(
        positionSeconds: 300,
        durationSeconds: 2400,
        lastWatched: DateTime.utc(2026, 11, 9),
      ),
    );
    controller.updateCatalogPreferences(
      const CatalogPreferences()
          .copyWithRule(
            MediaKind.movie,
            const CatalogRule(hiddenLanguages: {'en'}),
          )
          .copyWithRule(
            MediaKind.series,
            const CatalogRule(hiddenLanguages: {'en'}),
          ),
    );
    expect(controller.items, isEmpty);
    // Hidden media remain addressable for ongoing playback and actions.
    controller.markWatched('film');
    expect(controller.progress['film']!.durationSeconds, 5400);
    await controller.shutdown();
    controller.dispose();
    source.dispose();
    final restoredSource = SourceController(
      repository: repository,
      client: _Client(),
    );
    final restored = AppController(store: store, sources: restoredSource);
    addTearDown(() async {
      await restored.shutdown();
      restored.dispose();
      restoredSource.dispose();
    });
    await restored.init();
    expect(restored.items, isEmpty);
    expect(restored.favorites, {'film', 'series'});
    expect(restored.progress['episode']!.positionSeconds, 300);
    expect(restored.progress['film']!.completed, isTrue);
    expect(restored.recentIds, ['film', 'episode']);
    restored.updateCatalogPreferences(const CatalogPreferences());
    expect(_ids(restored.items), ['film', 'series']);
    expect(restored.favorites, {'film', 'series'});
    expect(restored.progress['episode']!.positionSeconds, 300);
    await restored.flush();
  });

  test(
    'Legacy state keeps favorites and reset restores default visibility',
    () async {
      final controller = AppController(
        store: MemoryLocalStore({
          'favorites': ['film-orbite'],
          'settings': {'volume': 45},
          'catalogPreferences': {'rules': 'broken'},
        }),
      );
      addTearDown(controller.dispose);
      await controller.init();
      expect(controller.favorites, {'film-orbite'});
      expect(controller.settings.volume, 45);
      expect(controller.items, hasLength(controller.allItems.length));
      controller.updateCatalogPreferences(
        const CatalogPreferences().copyWithRule(
          MediaKind.movie,
          const CatalogRule(hiddenLanguages: {'unknown'}),
        ),
      );
      expect(controller.items.length, lessThan(controller.allItems.length));
      controller.resetData();
      expect(controller.items, hasLength(controller.allItems.length));
      expect(
        controller.catalogPreferences.ruleFor(MediaKind.movie).hiddenLanguages,
        isEmpty,
      );
      await controller.flush();
    },
  );
}

List<String> _ids(List<MediaItem> items) =>
    items.map((item) => item.id).toList();

MediaItem _item(
  String id, {
  String title = 'Film',
  MediaKind kind = MediaKind.movie,
  String category = 'Catalogue',
  int year = 2026,
  String sourceId = 'saved',
}) => MediaItem(
  id: id,
  title: title,
  kind: kind,
  category: category,
  description: '',
  year: year,
  durationMinutes: 90,
  palette: 0xff8b5cf6,
  subtitle: '',
  art: 0,
  sourceId: sourceId,
  mediaUrl: 'https://example.test/movie/user/password/$id.mp4',
);

MemorySourceRepository _repository(List<MediaItem> items) =>
    MemorySourceRepository([
      SourceRecord(
        config: SourceConfig.fromDraft(
          'saved',
          const SourceDraft(
            name: 'Test source',
            kind: SourceKind.m3uUrl,
            address: 'https://example.test/list.m3u',
          ),
        ),
        catalog: SourceCatalog(items: items),
        programmes: const [],
        updatedAt: DateTime.utc(2026, 11, 9),
      ),
    ]);

class _Client extends IptvClient {
  SourceCatalog nextCatalog = const SourceCatalog(items: []);
  @override
  Future<SourceCatalog> loadCatalog(
    SourceConfig config, {
    CancellationToken? cancel,
  }) async => nextCatalog;
}
