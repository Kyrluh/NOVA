import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_iptv/data/local_store.dart';
import 'package:nova_iptv/data/source_repository.dart';
import 'package:nova_iptv/domain/models.dart';
import 'package:nova_iptv/domain/source_models.dart';
import 'package:nova_iptv/sources/iptv_client.dart';
import 'package:nova_iptv/state/app_controller.dart';
import 'package:nova_iptv/state/source_controller.dart';
import 'package:nova_iptv/ui/episode_navigation.dart';
import 'package:nova_iptv/ui/pages/live_page.dart';
import 'package:nova_iptv/ui/pages/playback_page.dart';
import 'package:nova_iptv/ui/shell.dart';
import 'package:nova_iptv/ui/theme.dart';

void main() {
  test('Episode order crosses seasons, respects boundaries and invents no M3U grouping', () {
    final first = EpisodeNavigation(_series, 'episode-1');
    expect(first.isResolved, isTrue);
    expect(first.previous, isNull);
    expect(first.next?.id, 'episode-2');
    expect(EpisodeNavigation(_series, 'episode-2').next?.id, 'episode-3');
    expect(EpisodeNavigation(_series, 'episode-3').previous?.id, 'episode-2');
    expect(EpisodeNavigation(_series, 'episode-3').next, isNull);
    expect(EpisodeNavigation(_series, 'unknown').isResolved, isFalse);
    expect(
      EpisodeNavigation(
        _series.copyWith(seasons: const []),
        'episode-1',
      ).isResolved,
      isFalse,
    );
    final missingUrl = _series.copyWith(
      seasons: const [
        DemoSeason(
          number: 1,
          episodes: [
            _first,
            DemoEpisode(
              id: 'missing',
              title: 'Épisode indisponible',
              number: 2,
              durationMinutes: 10,
            ),
          ],
        ),
      ],
    );
    expect(EpisodeNavigation(missingUrl, 'episode-1').next, isNull);
  });

  testWidgets(
    'Manual previous and next keep one playback State, resume positions and unfinished progress',
    (tester) async {
      final app = await _app(tester);
      app.recordProgress('episode-1', _progress(120));
      app.recordProgress('episode-2', _progress(45));
      await tester.pumpWidget(
        MaterialApp(
          theme: novaTheme(app.settings.accent),
          home: NovaPlaybackPage(
            controller: app,
            uri: _first.mediaUrl!,
            title: _first.title,
            live: false,
            mediaId: _first.id,
            seriesId: _series.id,
            playerBuilder: (spec) =>
                _EpisodeProbe(key: const ValueKey('episode-probe'), spec: spec),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final state = tester.state(find.byType(_EpisodeProbe));
      EpisodePlaybackSpec spec() =>
          tester.widget<_EpisodeProbe>(find.byType(_EpisodeProbe)).spec;
      expect(spec().episodeNavigation, isTrue);
      expect(spec().onPreviousEpisode, isNull);
      expect(spec().start, const Duration(seconds: 120));
      await tester.tap(find.byKey(const ValueKey('next-episode')));
      await tester.pumpAndSettle();
      expect(
        identical(tester.state(find.byType(_EpisodeProbe)), state),
        isTrue,
      );
      expect(spec().mediaId, 'episode-2');
      expect(spec().start, const Duration(seconds: 45));
      expect(app.progress['episode-1']!.positionSeconds, 120);
      expect(app.progress['episode-1']!.completed, isFalse);
      await tester.tap(find.byKey(const ValueKey('next-episode')));
      await tester.pumpAndSettle();
      expect(spec().mediaId, 'episode-3');
      expect(spec().onNextEpisode, isNull);
      expect(
        tester
            .widget<IconButton>(find.byKey(const ValueKey('next-episode')))
            .onPressed,
        isNull,
      );
      await tester.tap(find.byKey(const ValueKey('previous-episode')));
      await tester.pumpAndSettle();
      expect(spec().mediaId, 'episode-2');
      expect(spec().start, const Duration(seconds: 45));
      expect(app.progress['episode-2']!.completed, isFalse);
      spec().onProgress!(
        const Duration(seconds: 590),
        const Duration(seconds: 600),
      );
      await tester.pumpAndSettle();
      expect(app.progress['episode-2']!.completed, isTrue);
      await app.flush();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'TV and route native leases never overlap, including both 12 second release timeouts',
    (tester) async {
      final app = await _app(tester);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      final tvGate = Completer<void>();
      final routeGate = Completer<void>();
      final leases = _Leases();
      addTearDown(() {
        if (!tvGate.isCompleted) tvGate.complete();
        if (!routeGate.isCompleted) routeGate.complete();
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: novaTheme(app.settings.accent),
          home: NovaShell(
            controller: app,
            nativeReady: true,
            manageWindow: false,
            mobileUI: true,
            livePlayerBuilder: (item, released) => _LeaseProbe(
              label: 'TV ${item.title}',
              onCreate: () {
                leases.liveCreations++;
                leases.enter();
              },
              releaseGate: () => leases.liveCreations == 1
                  ? tvGate.future
                  : Future<void>.value(),
              onReleased: () {
                leases.leave();
                released();
              },
            ),
            playbackBuilder: (spec) => _LeaseProbe(
              label: 'Route ${spec.title}',
              onCreate: () {
                leases.routeCreations++;
                leases.enter();
              },
              releaseGate: () => routeGate.future,
              onReleased: () {
                leases.leave();
                spec.onReleased();
              },
              onClose: spec.onClose,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('TV'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(InkWell, _channel.title).first);
      await tester.pumpAndSettle();
      final liveState = tester.state<LivePageState>(find.byType(LivePage));
      expect(liveState.selectedId, _channel.id);
      expect(leases.active, 1);
      await _openUrlDialog(tester);
      // The setup dialog does not stop the current TV session.
      expect(leases.active, 1);
      expect(find.byType(_LeaseProbe), findsOneWidget);
      await _submitUrl(tester);
      expect(leases.routeCreations, 0);
      expect(find.byType(_LeaseProbe), findsNothing);
      expect(liveState.playbackSuspended, isTrue);
      await tester.pump(const Duration(seconds: 13));
      await tester.pump();
      await _openUrlDialog(tester);
      await _submitUrl(tester);
      expect(leases.routeCreations, 0);
      expect(leases.active, 1);
      tvGate.complete();
      await tester.pumpAndSettle();
      expect(liveState.selectedId, _channel.id);
      expect(leases.liveCreations, 2);
      expect(leases.active, 1);
      await _openUrlDialog(tester);
      await _submitUrl(tester);
      await tester.pumpAndSettle();
      expect(leases.routeCreations, 1);
      expect(leases.active, 1);
      expect(liveState.playbackSuspended, isTrue);
      await tester.tap(find.text('Fermer la lecture test'));
      await tester.pumpAndSettle();
      expect(liveState.playbackSuspended, isTrue);
      expect(leases.liveCreations, 2);
      await tester.pump(const Duration(seconds: 13));
      await tester.pump();
      await _openUrlDialog(tester);
      await _submitUrl(tester);
      expect(leases.routeCreations, 1);
      expect(leases.active, 1);
      routeGate.complete();
      await tester.pumpAndSettle();
      expect(liveState.playbackSuspended, isFalse);
      expect(liveState.selectedId, _channel.id);
      expect(leases.liveCreations, 3);
      expect(leases.active, 1);
      expect(leases.maximum, 1);
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> _openUrlDialog(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Ouvrir un média'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Ouvrir une URL vidéo'));
  await tester.pumpAndSettle();
}

Future<void> _submitUrl(WidgetTester tester) async {
  final field = find.byWidgetPredicate(
    (widget) =>
        widget is TextField && widget.decoration?.labelText == 'URL du média',
  );
  await tester.enterText(field, 'http://127.0.0.1/fixture-not-fetched.mp4');
  await tester.tap(find.text('Lire le flux'));
  await tester.pumpAndSettle();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump();
  await tester.pumpAndSettle();
}

WatchProgress _progress(int seconds) => WatchProgress(
  positionSeconds: seconds,
  durationSeconds: 600,
  lastWatched: DateTime.utc(2026),
);
Future<AppController> _app(WidgetTester tester) async {
  final sources = SourceController(
    repository: MemorySourceRepository([
      SourceRecord(
        config: const SourceConfig(
          id: 'episode-source',
          name: 'Fixtures originales',
          kind: SourceKind.m3uUrl,
          address: 'https://example.test/not-fetched.m3u',
        ),
        catalog: const SourceCatalog(items: [_series, _channel]),
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
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    app.dispose();
    sources.dispose();
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  return app;
}

class _EpisodeProbe extends StatefulWidget {
  const _EpisodeProbe({super.key, required this.spec});
  final EpisodePlaybackSpec spec;
  @override
  State<_EpisodeProbe> createState() => _EpisodeProbeState();
}

class _EpisodeProbeState extends State<_EpisodeProbe> {
  @override
  Widget build(BuildContext context) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Text(widget.spec.title),
      IconButton(
        key: const ValueKey('previous-episode'),
        onPressed: widget.spec.onPreviousEpisode,
        icon: const Icon(Icons.skip_previous),
      ),
      IconButton(
        key: const ValueKey('next-episode'),
        onPressed: widget.spec.onNextEpisode,
        icon: const Icon(Icons.skip_next),
      ),
    ],
  );
  @override
  void dispose() {
    widget.spec.onReleased();
    super.dispose();
  }
}

class _Leases {
  int active = 0, maximum = 0, liveCreations = 0, routeCreations = 0;
  void enter() {
    active++;
    if (active > maximum) maximum = active;
  }

  void leave() {
    active--;
  }
}

class _LeaseProbe extends StatefulWidget {
  const _LeaseProbe({
    required this.label,
    required this.onCreate,
    required this.onReleased,
    required this.releaseGate,
    this.onClose,
  });
  final String label;
  final VoidCallback onCreate, onReleased;
  final Future<void> Function() releaseGate;
  final VoidCallback? onClose;
  @override
  State<_LeaseProbe> createState() => _LeaseProbeState();
}

class _LeaseProbeState extends State<_LeaseProbe> {
  late final Future<void> _release;
  @override
  void initState() {
    super.initState();
    widget.onCreate();
    _release = widget.releaseGate();
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Colors.black,
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.label),
          if (widget.onClose != null)
            TextButton(
              onPressed: widget.onClose,
              child: const Text('Fermer la lecture test'),
            ),
        ],
      ),
    ),
  );
  @override
  void dispose() {
    final done = widget.onReleased;
    unawaited(_release.then((_) => done()));
    super.dispose();
  }
}

const _first = DemoEpisode(
  id: 'episode-1',
  title: 'Anime · S1 E1',
  number: 1,
  durationMinutes: 10,
  mediaUrl: 'http://127.0.0.1/e1.mkv',
);
const _second = DemoEpisode(
  id: 'episode-2',
  title: 'Anime · S1 E2',
  number: 2,
  durationMinutes: 10,
  mediaUrl: 'http://127.0.0.1/e2.mkv',
);
const _third = DemoEpisode(
  id: 'episode-3',
  title: 'Anime · S2 E1',
  number: 1,
  durationMinutes: 10,
  mediaUrl: 'http://127.0.0.1/e3.mkv',
);
const _series = MediaItem(
  id: 'episode-series',
  title: 'Anime original',
  kind: MediaKind.series,
  category: 'FR | Anime',
  description: '',
  year: 2026,
  durationMinutes: 0,
  palette: 0xff6752eb,
  subtitle: '',
  art: 0,
  sourceId: 'episode-source',
  detailsLoaded: true,
  seasons: [
    DemoSeason(number: 2, episodes: [_third]),
    DemoSeason(number: 1, episodes: [_second, _first]),
  ],
);
const _channel = MediaItem(
  id: 'episode-live',
  title: 'Chaîne de test',
  kind: MediaKind.live,
  category: 'FR | TV',
  description: '',
  year: 0,
  durationMinutes: 0,
  palette: 0xff6752eb,
  subtitle: '',
  art: 0,
  sourceId: 'episode-source',
  mediaUrl: 'http://127.0.0.1/live.ts',
);
