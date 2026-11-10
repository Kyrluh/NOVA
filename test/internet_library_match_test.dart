import 'package:flutter_test/flutter_test.dart';
import 'package:nova_iptv/data/local_store.dart';
import 'package:nova_iptv/domain/internet_catalog.dart';
import 'package:nova_iptv/domain/models.dart';
import 'package:nova_iptv/domain/platform_catalog.dart';
import 'package:nova_iptv/state/app_controller.dart';
import 'package:nova_iptv/state/internet_catalog_controller.dart';

const _film = InternetTitle(
  id: 'tt10000001',
  title: 'Venom',
  kind: MediaKind.movie,
  year: 2018,
);
MediaItem _local({
  String id = 'film',
  String title = 'Venom',
  int year = 2018,
  String? url = 'https://example.test/video.mp4',
  String? poster,
  MediaKind kind = MediaKind.movie,
  String? sourceId = 'local',
}) => MediaItem(
  id: id,
  title: title,
  kind: kind,
  category: 'Films',
  description: '',
  year: year,
  durationMinutes: 0,
  palette: 0xff6752eb,
  subtitle: '',
  art: 0,
  sourceId: sourceId,
  mediaUrl: url,
  posterUrl: poster,
);
InternetCatalogController _api(List<InternetTitle> titles) =>
    InternetCatalogController(
      store: MemoryLocalStore({
        'feeds': {
          for (final key in ['trends/movie', 'netflix/movie'])
            key: {
              'updated': '2026-11-10T00:00:00Z',
              'titles': titles.map((t) => t.toJson()).toList(),
            },
        },
      }),
    );

void main() {
  test('Only confirmed local videos are offered, including matches after the first twenty trends', () async {
    final titles = [
      for (var n = 0; n < 25; n++)
        InternetTitle(
          id: 'tt${20000000 + n}',
          title: 'Absent $n',
          kind: MediaKind.movie,
        ),
      _film,
    ];
    final api = _api(titles);
    addTearDown(api.dispose);
    await api.init();
    final library = [_local()];
    expect(api.availableTrending(MediaKind.movie, library).single.id, _film.id);
    expect(
      api.availableSelection(CatalogPlatform.netflix, library).single.id,
      _film.id,
    );
    expect(
      api.availableTrending(MediaKind.movie, [_local(url: null)]),
      isEmpty,
    );
    expect(
      api.availableTrending(MediaKind.movie, [_local(year: 2025)]),
      isEmpty,
    );
    expect(
      api.availableTrending(MediaKind.movie, [_local(title: 'Venom 2')]),
      isEmpty,
    );
    expect(api.availableTrending(MediaKind.movie, []), isEmpty);
  });

  test('Year tags and qualities match conservatively; undated ambiguities remain hidden', () async {
    final api = _api([_film]);
    addTearDown(api.dispose);
    await api.init();
    expect(
      api.libraryMatch(_film, [
        _local(title: '[FR] Venom (2018) [4K] VF', year: 0),
      ])?.id,
      'film',
    );
    expect(
      api.libraryMatch(_film, [_local(title: 'Venom (2025) HD', year: 0)]),
      isNull,
    );
    expect(
      api.libraryMatch(_film, [
        _local(id: 'a', year: 0),
        _local(id: 'b', year: 0),
      ]),
      isNull,
    );
    expect(
      api.availableTrending(MediaKind.movie, [
        _local(id: 'a'),
        _local(id: 'b'),
      ]),
      hasLength(1),
    );
    expect(api.libraryMatch(_film, [_local(sourceId: null)]), isNull);
  });

  test(
    'Grouped M3U episodes and lazy Xtream series count as available videos',
    () {
      final grouped = _local(kind: MediaKind.series, url: null).copyWith(
        seasons: const [
          DemoSeason(
            number: 1,
            episodes: [
              DemoEpisode(
                id: 'episode',
                title: 'Episode 1',
                number: 1,
                durationMinutes: 24,
                mediaUrl: 'https://example.test/1.mp4',
              ),
            ],
          ),
        ],
      );
      expect(InternetCatalogController.hasLibraryVideo(grouped), isTrue);
      expect(
        InternetCatalogController.hasLibraryVideo(
          grouped.copyWith(seasons: [], providerId: '123'),
        ),
        isTrue,
      );
      expect(
        InternetCatalogController.hasLibraryVideo(
          grouped.copyWith(seasons: []),
        ),
        isFalse,
      );
      expect(
        InternetCatalogController.hasLibraryVideo(_local(kind: MediaKind.live)),
        isFalse,
      );
    },
  );

  test('Public artwork with another embedded IMDb ID is discarded', () {
    final title = InternetTitle.parse({
      'id': _film.id,
      'name': _film.title,
      'poster': 'https://images.metahub.space/poster/medium/tt10000099/img',
    }, MediaKind.movie)!;
    expect(title.posterUrl, isNull);
  });

  test('Artwork shared by unrelated public titles is ignored; source posters remain authoritative', () async {
    const poster = 'https://image.tmdb.org/t/p/w500/shared.jpg';
    final api = _api([
      const InternetTitle(
        id: 'tt10000001',
        title: 'Venom',
        kind: MediaKind.movie,
        year: 2018,
        posterUrl: poster,
      ),
      const InternetTitle(
        id: 'tt10000002',
        title: 'Another film',
        kind: MediaKind.movie,
        year: 2026,
        posterUrl: poster,
      ),
    ]);
    addTearDown(api.dispose);
    await api.init();
    expect(api.posterFor(_local()), isNull);
    final app = AppController(store: MemoryLocalStore(), internetCatalog: api);
    addTearDown(app.dispose);
    expect(
      app.posterFor(_local(poster: 'https://source.test/correct.jpg')),
      'https://source.test/correct.jpg',
    );
    expect(app.posterFor(_local()), isNull);
  });
}
