import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_iptv/app.dart';
import 'package:nova_iptv/data/local_store.dart';
import 'package:nova_iptv/data/source_repository.dart';
import 'package:nova_iptv/domain/models.dart';
import 'package:nova_iptv/domain/source_models.dart';
import 'package:nova_iptv/sources/iptv_client.dart';
import 'package:nova_iptv/sources/m3u_parser.dart';
import 'package:nova_iptv/sources/m3u_series.dart';
import 'package:nova_iptv/state/app_controller.dart';
import 'package:nova_iptv/state/source_controller.dart';
import 'package:nova_iptv/ui/pages/catalog_page.dart';

const _config = SourceConfig(
  id: 'm3u',
  name: 'Original fixture',
  kind: SourceKind.m3uUrl,
  address: 'https://example.test/list.m3u',
);
String _playlist(
  List<String> names, {
  String attributes = '',
  String group = 'FR | Animes',
}) =>
    '#EXTM3U\n${names.indexed.map((e) => '#EXTINF:-1 tvg-logo="https://example.test/show.jpg" group-title="$group" $attributes,${e.$2}\nhttps://example.test/series/fixture/fixture/${e.$1}.mp4\n').join()}';

void main() {
  test('From S01 E08 groups spaced episode names with numeric season and episode ordering', () {
    final catalog = parseM3u(
      _playlist([
        'From S01 E08',
        'From S02 E01',
        'From S01 E10',
        'From S01 E07',
        'From S01E09',
      ], group: 'FR | Series'),
      _config,
      Uri.parse(_config.address),
    );
    final series = catalog.items.single;
    expect(series.title, 'From');
    expect(series.seasons.map((season) => season.number), [1, 2]);
    expect(series.seasons.first.episodes.map((episode) => episode.number), [
      7,
      8,
      9,
      10,
    ]);
    expect(series.seasons.first.episodes[1].title, 'From S01 E08');
    expect(series.seasons.last.episodes.single.number, 1);
  });

  for (final names in [
    ['Hajime no Ippo S02E01', 'Hajime no Ippo S01E02', 'Hajime no Ippo S01E01'],
    [
      'Hajime no Ippo Saison 2 Episode 1',
      'Hajime no Ippo Saison 1 Episode 2',
      'Hajime no Ippo Saison 1 Episode 1',
    ],
    ['Hajime no Ippo 2x01', 'Hajime no Ippo 1x02', 'Hajime no Ippo 1x01'],
  ]) {
    test('M3U groups and sorts seasons and episodes: ${names.first}', () {
      final items = parseM3u(
        _playlist(names),
        _config,
        Uri.parse(_config.address),
      ).items;
      expect(items, hasLength(1));
      final series = items.single;
      expect(series.title, 'Hajime no Ippo');
      expect(series.kind, MediaKind.series);
      expect(series.mediaUrl, isNull);
      expect(series.detailsLoaded, isTrue);
      expect(series.seasons.map((s) => s.number), [1, 2]);
      expect(series.seasons.first.episodes.map((e) => e.number), [1, 2]);
      expect(series.seasons.first.episodes.first.title, names[2]);
      expect(series.seasons.first.episodes.first.mediaUrl, endsWith('/2.mp4'));
      expect(series.posterUrl, 'https://example.test/show.jpg');
      expect(groupM3uSeries(items).single, same(series));
    });
  }

  test('Repeated M3U series names use one series and retain playlist order without claiming extra seasons', () {
    final items = parseM3u(
      _playlist(List.filled(4, 'Hajime no Ippo')),
      _config,
      Uri.parse(_config.address),
    ).items;
    expect(items, hasLength(1));
    expect(items.single.seasons, hasLength(1));
    expect(items.single.seasons.single.episodes.map((e) => e.number), [
      1,
      2,
      3,
      4,
    ]);
    expect(
      items.single.seasons.single.episodes.map((e) => e.id).toSet(),
      hasLength(4),
    );
  });

  test('Generic video URLs in an anime category group repeated titles; explicit films remain films', () {
    const document =
        '#EXTM3U\n'
        '#EXTINF:-1 group-title="FR | Animes",Hajime no Ippo\nhttps://example.test/1.mp4\n'
        '#EXTINF:-1 group-title="FR | Animes",Hajime no Ippo\nhttps://example.test/2.mp4\n'
        '#EXTINF:-1 tvg-type="movie" group-title="FR | Animes",Film anime\nhttps://example.test/3.mp4\n';
    final items = parseM3u(document, _config, Uri.parse(_config.address)).items;
    expect(items, hasLength(2));
    expect(items.first.kind, MediaKind.series);
    expect(items.first.seasons.single.episodes, hasLength(2));
    expect(items.last.kind, MediaKind.movie);
    expect(items.last.seasons, isEmpty);
    expect(
      groupM3uSeries([
        _legacy('Hajime no Ippo', 'old', 'https://example.test/4.mp4'),
      ]).single.seasons.single.episodes,
      hasLength(1),
    );
  });

  test('M3U episode attributes are respected even when all display names are identical', () {
    final document =
        '#EXTM3U\n'
        '#EXTINF:-1 tvg-type="series" series-name="Hajime no Ippo" season="2" episode="7",Episode\nhttps://example.test/7.mp4\n'
        '#EXTINF:-1 tvg-type="series" series-name="Hajime no Ippo" season="1" episode="3",Episode\nhttps://example.test/3.mp4\n';
    final series = parseM3u(
      document,
      _config,
      Uri.parse(_config.address),
    ).items.single;
    expect(series.title, 'Hajime no Ippo');
    expect(series.seasons.map((s) => s.number), [1, 2]);
    expect(series.seasons.first.episodes.single.number, 3);
    expect(series.seasons.last.episodes.single.number, 7);
  });

  test('Films, live channels, languages and separate sources are not merged', () {
    final document =
        '#EXTM3U\n'
        '#EXTINF:-1 tvg-type="movie",Venom\nhttps://example.test/movie/1.mp4\n'
        '#EXTINF:-1 tvg-type="movie",Venom 2\nhttps://example.test/movie/2.mp4\n'
        '#EXTINF:-1 tvg-type="live",TV E01\nhttps://example.test/live/1.ts\n'
        '#EXTINF:-1 tvg-type="series" group-title="FR",Hajime no Ippo S01E01\nhttps://example.test/series/fr/1.mp4\n'
        '#EXTINF:-1 tvg-type="series" group-title="EN",Hajime no Ippo S01E01\nhttps://example.test/series/en/1.mp4\n';
    final items = parseM3u(document, _config, Uri.parse(_config.address)).items;
    expect(items, hasLength(5));
    expect(items.where((i) => i.kind == MediaKind.movie), hasLength(2));
    expect(items.where((i) => i.kind == MediaKind.live), hasLength(1));
    expect(items.where((i) => i.kind == MediaKind.series), hasLength(2));
  });

  test('Series IDs and old episode progress IDs survive playlist reorder', () {
    final names = ['Hajime no Ippo S01E01', 'Hajime no Ippo S02E01'];
    final original = parseM3u(
      _playlist(names),
      _config,
      Uri.parse(_config.address),
    ).items.single;
    final episode = original.seasons.first.episodes.first;
    final legacy = _legacy(names.first, episode.id, episode.mediaUrl!);
    final migrated = groupM3uSeries([legacy]).single;
    expect(migrated.id, original.id);
    expect(migrated.seasons.single.episodes.single.id, episode.id);
  });

  testWidgets(
    'Offline cache migration shows one series card, seasons and episodes, preserving favorites and resume',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1440, 900);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final old = [
        _legacy(
          'Hajime no Ippo S01E01',
          'old-one',
          'https://example.test/series/1.mp4',
        ),
        _legacy(
          'Hajime no Ippo S02E02',
          'old-two',
          'https://example.test/series/2.mp4',
        ),
      ];
      final repository = MemorySourceRepository([
        SourceRecord(
          config: _config,
          catalog: SourceCatalog(items: old),
          programmes: const [],
          updatedAt: DateTime.utc(2026),
        ),
      ]);
      final sources = SourceController(
        repository: repository,
        client: IptvClient(),
      );
      final app = AppController(
        sources: sources,
        store: MemoryLocalStore({
          'favorites': ['old-two'],
          'progress': {
            'old-two': WatchProgress(
              positionSeconds: 55,
              durationSeconds: 100,
              lastWatched: DateTime.utc(2026),
            ).toJson(),
          },
          'settings': {'animations': false},
        }),
      );
      await tester.runAsync(app.init);
      addTearDown(() {
        app.dispose();
        sources.dispose();
      });
      expect(app.items, hasLength(1));
      final series = app.items.single;
      expect(app.favorites, contains(series.id));
      expect(app.resumeItems.single.id, series.id);
      expect(app.progress['old-two']!.positionSeconds, 55);
      expect((await repository.readAll()).single.catalog.items, hasLength(1));
      await tester.pumpWidget(
        NovaApp(controller: app, nativeReady: false, manageWindow: false),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Séries').first);
      await tester.pumpAndSettle();
      expect(find.byType(MediaPoster), findsOneWidget);
      await tester.tap(find.byType(MediaPoster));
      await tester.pumpAndSettle();
      expect(find.byType(DropdownButton<int>), findsOneWidget);
      expect(find.text('Hajime no Ippo S01E01'), findsOneWidget);
      expect(find.text('Hajime no Ippo S02E02'), findsNothing);
      await tester.tap(find.byType(DropdownButton<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Saison 2').last);
      await tester.pumpAndSettle();
      expect(find.text('Hajime no Ippo S02E02'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}

MediaItem _legacy(String title, String id, String url) => MediaItem(
  id: id,
  title: title,
  kind: MediaKind.series,
  category: 'FR | Animes',
  description: '',
  year: 0,
  durationMinutes: 0,
  palette: 0xff6752eb,
  subtitle: '',
  art: 0,
  sourceId: _config.id,
  mediaUrl: url,
  detailsLoaded: true,
);
