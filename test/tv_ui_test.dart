import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_iptv/app.dart';
import 'package:nova_iptv/data/demo_catalog.dart';
import 'package:nova_iptv/data/local_store.dart';
import 'package:nova_iptv/data/source_repository.dart';
import 'package:nova_iptv/domain/models.dart';
import 'package:nova_iptv/domain/source_models.dart';
import 'package:nova_iptv/sources/iptv_client.dart';
import 'package:nova_iptv/state/app_controller.dart';
import 'package:nova_iptv/state/source_controller.dart';
import 'package:nova_iptv/ui/tv/tv_catalog.dart';
import 'package:nova_iptv/ui/tv/tv_details.dart';
import 'package:nova_iptv/ui/tv/tv_live.dart';
import 'package:nova_iptv/ui/tv/tv_widgets.dart';

void main() {
  testWidgets(
    'TV series details select the season and resume the episode already in progress',
    (tester) async {
      final app = await _start(
        tester,
        series: demoCatalog
            .firstWhere((i) => i.kind == MediaKind.series)
            .copyWith(
              seasons: const [
                DemoSeason(
                  number: 1,
                  episodes: [
                    DemoEpisode(
                      id: 'tv-episode-one',
                      title: 'Premier épisode',
                      number: 1,
                      durationMinutes: 24,
                      mediaUrl: 'https://example.test/1.mp4',
                    ),
                  ],
                ),
                DemoSeason(
                  number: 2,
                  episodes: [
                    DemoEpisode(
                      id: 'tv-episode-two',
                      title: 'Épisode en cours',
                      number: 9,
                      durationMinutes: 24,
                      mediaUrl: 'https://example.test/2.mp4',
                    ),
                  ],
                ),
              ],
            ),
      );
      app.recordProgress(
        'tv-episode-two',
        WatchProgress(
          positionSeconds: 90,
          durationSeconds: 200,
          lastWatched: DateTime.utc(2026),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: novaTvTheme(app.settings.accent),
          home: TvDetails(
            controller: app,
            item: app.items.firstWhere((i) => i.kind == MediaKind.series),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Saison 2'), findsOneWidget);
      expect(find.text('Épisode en cours'), findsOneWidget);
      expect(find.text('Premier épisode'), findsNothing);
      expect(
        Focus.of(tester.element(find.text('Reprendre l’épisode'))).hasFocus,
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'TV application navigates with D-pad and Select from live to films and movie details',
    (tester) async {
      await _start(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();
      expect(find.byType(TvLive), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();
      expect(find.byType(TvCatalog), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      final card = find.byKey(ValueKey('tv-card-${demoCatalog.first.id}'));
      for (
        var n = 0;
        n < 3 && tester.widget<TvTile>(card).focusNode?.hasFocus != true;
        n++
      ) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
      }
      expect(tester.widget<TvTile>(card).focusNode!.hasFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();
      expect(find.byType(TvDetails), findsOneWidget);
      expect(find.text('Lire le film'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'TV layouts stay usable at HD and full HD logical sizes with sources and platforms reachable',
    (tester) async {
      await _start(tester);
      for (final size in [
        const Size(960, 540),
        const Size(1280, 720),
        const Size(720, 400),
      ]) {
        tester.view.physicalSize = size;
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('mobile-navigation')), findsNothing);
        expect(tester.takeException(), isNull);
      }
      for (var n = 0; n < 9; n++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('add-source')), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );
}

Future<AppController> _start(WidgetTester tester, {MediaItem? series}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(960, 540);
  final sources = SourceController(
    repository: MemorySourceRepository([
      SourceRecord(
        config: const SourceConfig(
          id: 'tv',
          name: 'TV fixtures',
          kind: SourceKind.m3uUrl,
          address: 'https://example.test/list.m3u',
        ),
        catalog: SourceCatalog(
          items: demoCatalog.map((original) {
            final i = original.kind == MediaKind.series && series != null
                ? series
                : original;
            return i.copyWith(
              sourceId: 'tv',
              detailsLoaded: true,
              mediaUrl: i.kind == MediaKind.live
                  ? null
                  : 'https://example.test/video.mp4',
            );
          }).toList(),
        ),
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
  await tester.pumpWidget(
    NovaApp(
      controller: app,
      nativeReady: false,
      manageWindow: false,
      television: true,
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
