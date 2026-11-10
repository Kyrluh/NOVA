// User interaction checks with a fake media backend and no native GPU surface.
// Native subtitle decoding is covered by tool/subtitle_smoke_test.dart.
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:nova_iptv/player/nova_player.dart';
import 'package:nova_iptv/player/desktop_fullscreen.dart';

import 'desktop_fullscreen_test.dart' show FakeFullscreenWindow;

void main() {
  testWidgets('Windows central button pauses, resumes and hides with the HUD', (
    tester,
  ) async {
    final fixture = await _mount(tester);
    final button = find.byKey(const ValueKey('player-center-playback-button'));
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(fixture.platform.state.playing, isFalse);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(fixture.platform.state.playing, isTrue);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(button.hitTestable(), findsNothing);
  });

  testWidgets(
    'Windows two finger pinch changes framing without reopening the video',
    (tester) async {
      final fixture = await _mount(tester);
      final center = tester.getCenter(
        find.byKey(const ValueKey('player-touch-surface')),
      );
      for (final expand in [true, false]) {
        final start = expand ? 70.0 : 170.0;
        final end = expand ? 170.0 : 70.0;
        final left = await tester.startGesture(
          center - Offset(start, 0),
          pointer: 10,
        );
        final right = await tester.startGesture(
          center + Offset(start, 0),
          pointer: 11,
        );
        for (var step = 1; step <= 5; step++) {
          final delta = start + (end - start) * step / 5;
          await left.moveTo(center - Offset(delta, 0));
          await right.moveTo(center + Offset(delta, 0));
          await tester.pump(const Duration(milliseconds: 16));
        }
        await right.up();
        await left.up();
        await tester.pumpAndSettle();
        expect(
          tester.widget<Video>(find.byType(Video)).fit,
          expand ? BoxFit.cover : BoxFit.contain,
        );
      }
      expect(fixture.platform.openCount, 1);
      expect(fixture.brightness, isEmpty);
    },
  );

  testWidgets(
    'Windows multimedia keys and native commands control the visible player without player focus',
    (tester) async {
      final fixture = await _mount(tester);
      tester.binding.focusManager.rootScope.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.mediaPlayPause);
      await tester.pumpAndSettle();
      expect(fixture.platform.state.playing, isFalse);
      await tester.sendKeyEvent(LogicalKeyboardKey.mediaPlay);
      await tester.pumpAndSettle();
      expect(fixture.platform.state.playing, isTrue);
      for (final command in ['pause', 'pause', 'playPause', 'play']) {
        tester.binding.channelBuffers.push(
          'nova/media_keys',
          const StandardMethodCodec().encodeMethodCall(
            MethodCall('mediaCommand', command),
          ),
          (_) {},
        );
        await tester.pumpAndSettle();
        expect(
          fixture.platform.state.playing,
          command == 'playPause' || command == 'play',
        );
      }
      expect(fixture.platform.openCount, 1);
    },
  );
  for (final compact in [false, true]) {
    testWidgets(
      'Episode buttons invoke navigation without seeking ($compact)',
      (tester) async {
        var previous = 0;
        var next = 0;
        final fixture = await _mount(
          tester,
          compact: compact,
          episodeNavigation: true,
          autoNext: false,
          onPreviousEpisode: () => previous++,
          onNextEpisode: () => next++,
        );
        await tester.tap(find.byTooltip('Épisode précédent'));
        await tester.pump();
        await tester.tap(find.byTooltip('Épisode suivant'));
        await tester.pump();
        expect(previous, 1);
        expect(next, 1);
        expect(fixture.platform.seeks, isEmpty);
        expect(fixture.platform.openCount, 1);
        expect(fixture.platform.state.playing, isTrue);
        fixture.platform.complete();
        await tester.pump();
        expect(next, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('First episode keeps the previous button visible and disabled', (
    tester,
  ) async {
    await _mount(tester, episodeNavigation: true, onNextEpisode: () {});
    final previous = find.widgetWithIcon(
      IconButton,
      Icons.skip_previous_rounded,
    );
    final next = find.widgetWithIcon(IconButton, Icons.skip_next_rounded);
    expect(tester.widget<IconButton>(previous).onPressed, isNull);
    expect(tester.widget<IconButton>(next).onPressed, isNotNull);
  });

  testWidgets('Last episode keeps the next button visible and disabled', (
    tester,
  ) async {
    await _mount(tester, episodeNavigation: true, onPreviousEpisode: () {});
    final previous = find.widgetWithIcon(
      IconButton,
      Icons.skip_previous_rounded,
    );
    final next = find.widgetWithIcon(IconButton, Icons.skip_next_rounded);
    expect(tester.widget<IconButton>(previous).onPressed, isNotNull);
    expect(tester.widget<IconButton>(next).onPressed, isNull);
  });

  testWidgets('Film playback has no episode navigation buttons', (
    tester,
  ) async {
    await _mount(tester);
    expect(find.byTooltip('Épisode précédent'), findsNothing);
    expect(find.byTooltip('Épisode suivant'), findsNothing);
  });

  testWidgets('Live playback ignores episode navigation callbacks', (
    tester,
  ) async {
    var navigation = 0;
    final fixture = await _mount(
      tester,
      live: true,
      episodeNavigation: true,
      onPreviousEpisode: () => navigation++,
      onNextEpisode: () => navigation++,
    );
    expect(find.byTooltip('Épisode précédent'), findsNothing);
    expect(find.byTooltip('Épisode suivant'), findsNothing);
    fixture.platform.complete();
    await tester.pump();
    expect(navigation, 0);
    expect(fixture.platform.seeks, isEmpty);
  });

  testWidgets('Next episode callback still advances automatically only once', (
    tester,
  ) async {
    var next = 0;
    final fixture = await _mount(tester, onNextEpisode: () => next++);
    fixture.platform.complete();
    fixture.platform.complete();
    await tester.pumpAndSettle();
    expect(next, 1);
  });

  testWidgets(
    'Desktop fullscreen menus render above the player and preserve Escape behavior',
    (tester) async {
      final window = FakeFullscreenWindow();
      final desktop = DesktopFullscreen(window: window);
      final f = await _mount(tester, desktop: desktop);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Vitesse de lecture'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(CheckedPopupMenuItem<double>, '1,5×'),
      );
      await tester.pumpAndSettle();
      expect(f.platform.rates.last, 1.5);
      expect(desktop.hasExpandedPlayer, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(desktop.hasExpandedPlayer, isFalse);
      expect(f.platform.state.playing, isTrue);
      expect(window.calls, [true, false]);
    },
  );
  testWidgets(
    'Player hides title and controls after idle and on pointer exit',
    (tester) async {
      await _mount(tester);
      double opacity(String name) =>
          tester.widget<AnimatedOpacity>(find.byKey(ValueKey(name))).opacity;
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(opacity('player-header'), 0);
      expect(opacity('player-controls'), 0);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: const Offset(5, 500));
      await mouse.moveTo(tester.getCenter(find.byType(Video)));
      await tester.pumpAndSettle();
      expect(opacity('player-header'), 1);
      await mouse.moveTo(const Offset(5, 500));
      await tester.pumpAndSettle();
      expect(opacity('player-controls'), 0);
      await mouse.removePointer();
    },
  );

  testWidgets('Menu stays visible beyond idle delay', (tester) async {
    await _mount(tester);
    await tester.tap(find.byTooltip('Vitesse de lecture'));
    await tester.pump(const Duration(seconds: 5));
    expect(
      tester
          .widget<AnimatedOpacity>(
            find.byKey(const ValueKey('player-controls')),
          )
          .opacity,
      1,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<AnimatedOpacity>(
            find.byKey(const ValueKey('player-controls')),
          )
          .opacity,
      0,
    );
  });

  testWidgets('F and Escape expand and restore the same playback session', (
    tester,
  ) async {
    final window = FakeFullscreenWindow();
    final desktop = DesktopFullscreen(window: window);
    final fixture = await _mount(tester, desktop: desktop);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await tester.pumpAndSettle();
    expect(window.calls, [true]);
    expect(desktop.hasExpandedPlayer, isTrue);
    expect(find.byType(Video), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(window.calls, [true, false]);
    expect(desktop.hasExpandedPlayer, isFalse);
    expect(fixture.platform.state.playing, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await tester.pumpAndSettle();
    await desktop.toggle();
    await tester.pumpAndSettle();
    expect(window.calls, [true, false, true, false]);
  });
  testWidgets(
    'Speed choices appear on the next frame and apply the selected rate',
    (tester) async {
      final fixture = await _mount(tester);
      await tester.tap(find.byTooltip('Vitesse de lecture'));
      await tester.pump();
      final choice = find.text('1,5×');
      expect(choice, findsOneWidget);
      expect(tester.getSize(choice).height, greaterThan(0));
      await tester.tap(
        find.widgetWithText(CheckedPopupMenuItem<double>, '1,5×'),
      );
      await tester.pumpAndSettle();
      expect(fixture.platform.rates.last, 1.5);
      expect(find.text('1,5×'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Wheel adjusts volume and consumes scrolling inside the player', (
    tester,
  ) async {
    final parentScroll = ScrollController();
    addTearDown(parentScroll.dispose);
    final fixture = await _mount(
      tester,
      parentScroll: parentScroll,
      initialVolume: 50,
    );
    final position = tester.getCenter(find.byType(Video));
    await tester.sendEventToBinding(
      PointerScrollEvent(position: position, scrollDelta: const Offset(0, 120)),
    );
    await tester.pumpAndSettle();
    expect(fixture.platform.volumes.last, 45);
    expect(parentScroll.offset, 0);
    expect(find.text('Volume 45 %'), findsOneWidget);
    // Send several notches before another frame/native acknowledgement.
    for (var index = 0; index < 4; index++) {
      await tester.sendEventToBinding(
        PointerScrollEvent(
          position: position,
          scrollDelta: const Offset(0, -120),
        ),
      );
    }
    await tester.pumpAndSettle();
    expect(fixture.platform.volumes.last, 65);
    expect(find.text('Volume 65 %'), findsOneWidget);
    expect(parentScroll.offset, 0);
    // Prove the parent really is scrollable outside the player.
    await tester.sendEventToBinding(
      const PointerScrollEvent(
        position: Offset(790, 180),
        scrollDelta: Offset(0, 120),
      ),
    );
    await tester.pumpAndSettle();
    expect(parentScroll.offset, greaterThan(0));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Brightness buttons apply plus, minus and reset with feedback', (
    tester,
  ) async {
    final fixture = await _mount(tester);
    await tester.tap(find.byTooltip('Augmenter la luminosité'));
    await tester.pumpAndSettle();
    expect(fixture.brightness, [5]);
    expect(find.text('Luminosité +5'), findsOneWidget);
    await tester.tap(find.byTooltip('Diminuer la luminosité'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Diminuer la luminosité'));
    await tester.pumpAndSettle();
    expect(fixture.brightness, [5, 0, -5]);
    expect(find.text('Luminosité -5'), findsOneWidget);
    await tester.tap(find.byTooltip('Réinitialiser la luminosité'));
    await tester.pumpAndSettle();
    expect(fixture.brightness, [5, 0, -5, 0]);
    expect(find.text('Luminosité 0'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Subtitle menu remains available without embedded tracks', (
    tester,
  ) async {
    await _mount(tester, tracks: false);
    await tester.tap(find.byTooltip('Sous-titres'));
    await tester.pump();
    expect(find.text('Aucune piste intégrée détectée'), findsOneWidget);
    expect(find.text('Charger un fichier de sous-titres…'), findsOneWidget);
    expect(find.text('Désactivés'), findsOneWidget);
    await tester.tap(
      find.widgetWithText(CheckedPopupMenuItem<Object>, 'Désactivés'),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Unsupported bitmap subtitles are explained while text and external tracks stay available',
    (tester) async {
      final fixture = await _mount(tester);
      fixture.platform.advertiseTracks(
        Tracks(
          subtitle: [
            ...fixture.platform.state.tracks.subtitle,
            const SubtitleTrack(
              's-dvb',
              'DVB fixture',
              'fra',
              codec: 'dvb_subtitle',
            ),
            const SubtitleTrack(
              's-pgs',
              'PGS fixture',
              'fra',
              codec: 'hdmv_pgs_subtitle',
            ),
            const SubtitleTrack(
              's-dvd',
              'DVD fixture',
              'fra',
              codec: 'dvd_subtitle',
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Sous-titres'));
      await tester.pump();
      const warning = 'Pistes images DVB/PGS non prises en charge';
      final notice = find.widgetWithText(PopupMenuItem<Object>, warning);
      expect(notice, findsOneWidget);
      expect(tester.widget<PopupMenuItem<Object>>(notice).enabled, isFalse);
      expect(find.textContaining('DVB fixture'), findsNothing);
      expect(find.textContaining('PGS fixture'), findsNothing);
      expect(find.textContaining('DVD fixture'), findsNothing);
      expect(find.text('Charger un fichier de sous-titres…'), findsOneWidget);
      await tester.tap(notice);
      await tester.pumpAndSettle();
      expect(fixture.platform.selectedSubtitles, isEmpty);
      await tester.tap(
        find.widgetWithText(CheckedPopupMenuItem<Object>, 'fra · Français'),
      );
      await tester.pumpAndSettle();
      expect(fixture.platform.selectedSubtitles.map((track) => track.id), [
        's-fr',
      ]);
      expect(find.text('Bonjour NOVA, été français.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Compact live player selects subtitles and keeps readable text above controls',
    (tester) async {
      final fixture = await _mount(tester, compact: true, live: true);
      await tester.tap(find.byTooltip('Sous-titres'));
      await tester.pump();
      await tester.tap(
        find.widgetWithText(CheckedPopupMenuItem<Object>, 'fra · Français'),
      );
      await tester.pumpAndSettle();
      expect(fixture.platform.selectedSubtitles.last.id, 's-fr');
      expect(find.text('Bonjour NOVA, été français.'), findsOneWidget);
      final subtitle = tester.widget<SubtitleView>(find.byType(SubtitleView));
      expect(subtitle.configuration.textScaler, TextScaler.noScaling);
      expect(subtitle.configuration.style.fontSize, greaterThanOrEqualTo(14));
      expect(subtitle.configuration.padding.bottom, greaterThan(24));
      final renderedText = find.text('Bonjour NOVA, été français.');
      expect(
        tester.getBottomLeft(renderedText).dy,
        lessThan(tester.getTopLeft(find.byTooltip('Sous-titres')).dy),
      );
      await tester.tap(find.byTooltip('Sous-titres'));
      await tester.pump();
      await tester.tap(
        find.widgetWithText(CheckedPopupMenuItem<Object>, 'eng · English'),
      );
      await tester.pumpAndSettle();
      expect(fixture.platform.selectedSubtitles.last.id, 's-en');
      expect(find.text('Hello NOVA, English subtitles.'), findsOneWidget);
      expect(find.text('Bonjour NOVA, été français.'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}

Future<_Fixture> _mount(
  WidgetTester tester, {
  bool tracks = true,
  bool compact = false,
  bool live = false,
  double initialVolume = 80,
  ScrollController? parentScroll,
  DesktopFullscreen? desktop,
  bool episodeNavigation = false,
  bool autoNext = true,
  VoidCallback? onPreviousEpisode,
  VoidCallback? onNextEpisode,
}) async {
  final fixture = _Fixture(tracks);
  final player = SizedBox(
    width: compact ? 460 : 640,
    height: compact ? 258 : 360,
    child: NovaPlayer(
      fullscreenController: desktop,
      uri: 'http://localhost/original-test-fixture',
      title: 'Test NOVA',
      isLive: live,
      initialVolume: initialVolume,
      episodeNavigation: episodeNavigation,
      autoNext: autoNext,
      onPreviousEpisode: onPreviousEpisode,
      onNextEpisode: onNextEpisode,
      backendFactory: () => NovaPlayerBackend(
        player: fixture.player,
        videoController: fixture.controller,
        applyBrightness: (value) async {
          fixture.brightness.add(value);
        },
      ),
    ),
  );
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: parentScroll == null
            ? Align(alignment: Alignment.topCenter, child: player)
            : ListView(
                controller: parentScroll,
                children: [
                  Align(alignment: Alignment.topCenter, child: player),
                  const SizedBox(height: 1400),
                ],
              ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  // Flush the serialized async stop/open/rate/play chain as well as frames.
  await tester.pump();
  await tester.pumpAndSettle();
  expect(find.byType(CircularProgressIndicator), findsNothing);
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    fixture.controller.notifier.dispose();
  });
  return fixture;
}

class _Fixture {
  final _FakePlatform platform;
  late final Player player = Player(platformPlayer: platform);
  late final _FakeVideoController controller = _FakeVideoController(player);
  final brightness = <int>[];
  _Fixture(bool tracks) : platform = _FakePlatform(tracks);
}

class _FakeVideoController implements VideoController {
  @override
  final Player player;
  @override
  final notifier = ValueNotifier<PlatformVideoController?>(null);
  _FakeVideoController(this.player);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakePlatform extends PlatformPlayer {
  int openCount = 0;
  final seeks = <Duration>[];
  final volumes = <double>[];
  final rates = <double>[];
  final selectedSubtitles = <SubtitleTrack>[];
  void complete() {
    state = state.copyWith(playing: false, completed: true);
    playingController.add(false);
    completedController.add(true);
  }

  void advertiseTracks(Tracks tracks) {
    state = state.copyWith(tracks: tracks);
    tracksController.add(tracks);
  }

  _FakePlatform(bool withTracks)
    : super(configuration: const PlayerConfiguration()) {
    state = state.copyWith(
      duration: const Duration(minutes: 5),
      width: 640,
      height: 360,
      tracks: Tracks(
        subtitle: [
          SubtitleTrack.no(),
          SubtitleTrack.auto(),
          if (withTracks) ...[
            const SubtitleTrack('s-fr', 'Français', 'fra'),
            const SubtitleTrack('s-en', 'English', 'eng'),
          ],
        ],
      ),
    );
  }
  @override
  Future<void> open(Playable playable, {bool play = true}) async {
    openCount++;
    state = state.copyWith(
      playlist: playable is Media ? Playlist([playable]) : playable as Playlist,
    );
    playlistController.add(state.playlist);
    if (play) await this.play();
  }

  @override
  Future<void> stop() async {
    state = state.copyWith(playing: false, position: Duration.zero);
    playingController.add(false);
  }

  @override
  Future<void> play() async {
    state = state.copyWith(playing: true, position: const Duration(seconds: 1));
    playingController.add(true);
    positionController.add(state.position);
  }

  @override
  Future<void> pause() async {
    state = state.copyWith(playing: false);
    playingController.add(false);
  }

  @override
  Future<void> seek(Duration position) async {
    seeks.add(position);
    state = state.copyWith(position: position);
    positionController.add(position);
  }

  @override
  Future<void> setVolume(double volume) async {
    volumes.add(volume);
    state = state.copyWith(volume: volume);
    volumeController.add(volume);
  }

  @override
  Future<void> setRate(double rate) async {
    rates.add(rate);
    state = state.copyWith(rate: rate);
    rateController.add(rate);
  }

  @override
  Future<void> setSubtitleTrack(SubtitleTrack track) async {
    selectedSubtitles.add(track);
    final text = switch (track.id) {
      's-fr' => 'Bonjour NOVA, été français.',
      's-en' => 'Hello NOVA, English subtitles.',
      _ => '',
    };
    state = state.copyWith(
      track: state.track.copyWith(subtitle: track),
      subtitle: [text, ''],
    );
    trackController.add(state.track);
    subtitleController.add(state.subtitle);
  }
}
