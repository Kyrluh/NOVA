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
import 'package:nova_iptv/ui/tv/tv_details.dart';
import 'package:nova_iptv/ui/tv/tv_widgets.dart';

void main() {
  testWidgets('TV movie actions stay above an expandable long synopsis', (
    tester,
  ) async {
    final movie = demoCatalog
        .firstWhere((item) => item.kind == MediaKind.movie)
        .copyWith(
          description: List.filled(
            45,
            'Un long synopsis accompagne ce film pour raconter son histoire.',
          ).join(' '),
        );
    final app = await _mount(tester, movie);
    final primary = find.byKey(const ValueKey('tv-details-primary'));
    final initialTop = tester.getTopLeft(primary).dy;
    expect(find.text('Lire le film'), findsOneWidget);
    expect(tester.getBottomRight(primary).dy, lessThan(540));
    await tester.tap(find.text('Ajouter aux favoris'));
    await tester.pumpAndSettle();
    expect(app.favorites, contains(movie.id));
    expect(find.text('Dans les favoris'), findsOneWidget);
    await tester.tap(find.text('Lire la suite'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('tv-synopsis-expanded')), findsOneWidget);
    expect(find.text('Voir moins'), findsOneWidget);
    expect(tester.getTopLeft(primary).dy, initialTop);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Voir moins'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('tv-synopsis-expanded')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'TV series resume action precedes synopsis and keeps distant episode visible',
    (tester) async {
      final series = demoCatalog
          .firstWhere((item) => item.kind == MediaKind.series)
          .copyWith(
            description: List.filled(
              40,
              'Cette histoire se poursuit avec plusieurs saisons et de nombreux épisodes.',
            ).join(' '),
            seasons: [
              DemoSeason(
                number: 1,
                episodes: List.generate(
                  80,
                  (index) => DemoEpisode(
                    id: 'details-episode-$index',
                    title: 'Épisode de test $index',
                    number: index + 1,
                    durationMinutes: 24,
                    mediaUrl: 'https://example.test/$index.mp4',
                  ),
                ),
              ),
            ],
          );
      await _mount(tester, series, resumeId: 'details-episode-60');
      final resume = find.text('Reprendre l’épisode');
      expect(resume, findsOneWidget);
      expect(
        tester.getBottomRight(resume).dy,
        lessThan(tester.getTopLeft(find.text('Lire la suite')).dy),
      );
      expect(find.text('S01 · E61'), findsOneWidget);
      expect(find.text('À reprendre'), findsOneWidget);
      final episode = find.byKey(
        const ValueKey('tv-episode-details-episode-60'),
      );
      expect(tester.widget<TvTile>(episode).selected, isTrue);
      expect(
        tester.getBottomRight(find.text('Épisode de test 60')).dy,
        lessThanOrEqualTo(540),
      );
      await tester.tap(find.text('Lire la suite'));
      await tester.pumpAndSettle();
      expect(tester.getBottomRight(resume).dy, lessThan(540));
      expect(find.text('À reprendre'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

Future<AppController> _mount(
  WidgetTester tester,
  MediaItem original, {
  String? resumeId,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(960, 540);
  final item = original.copyWith(
    sourceId: 'details-ux',
    detailsLoaded: true,
    mediaUrl: 'https://example.test/movie.mp4',
  );
  final sources = SourceController(
    repository: MemorySourceRepository([
      SourceRecord(
        config: const SourceConfig(
          id: 'details-ux',
          name: 'Fixtures',
          kind: SourceKind.m3uUrl,
          address: 'https://example.test/list.m3u',
        ),
        catalog: SourceCatalog(items: [item]),
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
  if (resumeId != null) {
    app.recordProgress(
      resumeId,
      WatchProgress(
        positionSeconds: 60,
        durationSeconds: 200,
        lastWatched: DateTime.utc(2026),
      ),
    );
  }
  await tester.pumpWidget(
    MaterialApp(
      theme: novaTvTheme(app.settings.accent),
      home: TvDetails(controller: app, item: app.items.first),
    ),
  );
  await tester.pumpAndSettle();
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    app.dispose();
    sources.dispose();
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  return app;
}
