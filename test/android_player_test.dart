import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:nova_iptv/player/android_player_host.dart';
import 'package:nova_iptv/player/nova_player.dart';
import 'package:nova_iptv/player/tv_channel_panel.dart';

void main() {
  testWidgets(
    'TV Back dismisses HUD and channel panel before closing the fullscreen live player',
    (tester) async {
      final f = await _mount(tester, television: true);
      await f.remount(television: true, live: true, closeable: true);
      f.fullscreenRequests.value++;
      await tester.pumpAndSettle();
      f.backRequests.value++;
      await tester.pumpAndSettle();
      expect(f.closed, 0);
      expect(f.host.fullscreenCalls.last, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();
      expect(find.byType(TvChannelPanel), findsOneWidget);
      f.backRequests.value++;
      await tester.pumpAndSettle();
      expect(find.byType(TvChannelPanel), findsNothing);
      expect(f.closed, 0);
      expect(f.host.fullscreenCalls.last, isTrue);
      f.backRequests.value++;
      await tester.pumpAndSettle();
      expect(f.closed, 1);
      expect(f.host.fullscreenCalls.last, isFalse);
    },
  );
  testWidgets(
    'TV remote controls playback and navigating the toolbar does not seek',
    (tester) async {
      final f = await _mount(tester, television: true);
      Focus.of(
        tester.element(find.byKey(const ValueKey('player-touch-surface'))),
      ).requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();
      expect(f.platform.state.playing, isFalse);
      tester.binding.focusManager.rootScope.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.mediaPlayPause);
      await tester.pumpAndSettle();
      expect(f.platform.state.playing, isTrue);
      Focus.of(
        tester.element(find.byKey(const ValueKey('player-touch-surface'))),
      ).requestFocus();
      await tester.pump();
      await f.platform.seek(const Duration(seconds: 40));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(f.platform.state.position, const Duration(seconds: 50));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      final seeks = f.platform.seeks.length;
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(f.platform.seeks.length, seeks);
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();
      expect(find.byType(CheckedPopupMenuItem<double>), findsWidgets);
      expect(f.platform.opened, hasLength(1));
    },
  );

  testWidgets('TV live remote changes channels without seeking', (
    tester,
  ) async {
    final f = await _mount(tester, television: true);
    await f.remount(television: true, live: true);
    Focus.of(tester.element(find.byKey(const ValueKey('player-touch-surface'))))
        .requestFocus();
    await tester.pump();
    f.platform.seeks.clear();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.sendKeyEvent(LogicalKeyboardKey.channelDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.mediaFastForward);
    await tester.pumpAndSettle();
    expect(f.channelNext, 1);
    expect(f.channelPrevious, 1);
    expect(f.platform.seeks, isEmpty);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(f.channelNext, 1);
    expect(find.byTooltip('Langue audio'), findsNothing);
    expect(find.byTooltip('Sous-titres'), findsNothing);
    expect(find.byTooltip('Réactualiser la chaîne'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(find.byType(CheckedPopupMenuItem<BoxFit>), findsWidgets);
    expect(f.channelNext, 1);
    expect(f.platform.seeks, isEmpty);
  });
  testWidgets(
    'TV held seek accelerates and coalesces requests in both directions',
    (tester) async {
      final f = await _mount(tester, television: true);
      Focus.of(
        tester.element(find.byKey(const ValueKey('player-touch-surface'))),
      ).requestFocus();
      await f.platform.seek(const Duration(seconds: 40));
      f.platform.seeks.clear();
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
      for (var n = 0; n < 6; n++) {
        await tester.sendKeyRepeatEvent(LogicalKeyboardKey.arrowRight);
      }
      expect(f.platform.seeks, isEmpty);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(f.platform.seeks, [const Duration(seconds: 130)]);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowLeft);
      for (var n = 0; n < 6; n++) {
        await tester.sendKeyRepeatEvent(LogicalKeyboardKey.arrowLeft);
      }
      await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(f.platform.state.position, const Duration(seconds: 40));
      expect(f.platform.opened, hasLength(1));
    },
  );
  testWidgets(
    'TV hidden HUD opens channel categories without leaving fullscreen',
    (tester) async {
      final f = await _mount(tester, television: true);
      await f.remount(television: true, live: true);
      f.fullscreenRequests.value++;
      await tester.pumpAndSettle();
      final fullscreenCount = f.host.fullscreenCalls.where((v) => v).length;
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();
      expect(find.byType(TvChannelPanel), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();
      expect(f.selectedChannel, 'b2');
      expect(find.byType(TvChannelPanel), findsNothing);
      expect(f.host.fullscreenCalls.where((v) => v).length, fullscreenCount);
      expect(f.platform.opened, hasLength(2));
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();
      expect(find.byType(TvChannelPanel), findsOneWidget);
      f.fullscreenRequests.value++;
      await tester.pumpAndSettle();
      expect(find.byType(TvChannelPanel), findsNothing);
      expect(f.host.fullscreenCalls.last, isTrue);
      f.fullscreenRequests.value++;
      await tester.pumpAndSettle();
    },
  );
  testWidgets(
    'Android central control pauses and resumes and hides with the HUD',
    (tester) async {
      final f = await _mount(tester);
      final button = find.byKey(
        const ValueKey('player-center-playback-button'),
      );
      expect(button.hitTestable(), findsOneWidget);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(f.platform.state.playing, isFalse);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(f.platform.state.playing, isTrue);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(button.hitTestable(), findsNothing);
    },
  );

  testWidgets(
    'Two fingers switch between fill and original without changing volume, brightness or the session',
    (tester) async {
      final f = await _mount(tester);
      final opens = f.platform.opened.length;
      final center = tester.getCenter(
        find.byKey(const ValueKey('player-touch-surface')),
      );
      await _pinch(tester, center, expand: true);
      expect(tester.widget<Video>(find.byType(Video)).fit, BoxFit.cover);
      expect(f.host.volumeCalls, isEmpty);
      expect(f.host.brightnessCalls, isEmpty);
      await _pinch(tester, center, expand: false);
      expect(tester.widget<Video>(find.byType(Video)).fit, BoxFit.contain);
      expect(f.platform.opened.length, opens);
      await f.remount(gestures: false);
      await _pinch(tester, center, expand: true);
      expect(tester.widget<Video>(find.byType(Video)).fit, BoxFit.contain);
      await f.remount();
      await tester.tap(find.byTooltip('Verrouiller les commandes tactiles'));
      await tester.pumpAndSettle();
      await _pinch(tester, center, expand: true);
      expect(tester.widget<Video>(find.byType(Video)).fit, BoxFit.contain);
    },
  );
  testWidgets(
    'Small TV controls keep fullscreen inside the video and external fullscreen keeps one session',
    (tester) async {
      final f = await _mount(tester);
      for (final width in [180.0, 240.0, 350.0]) {
        await f.remount(live: true, width: width, height: 145);
        final rect = tester.getRect(
          find.byKey(const ValueKey('player-touch-surface')),
        );
        final fullscreen = find.byTooltip('Plein écran');
        expect(fullscreen.hitTestable(), findsOneWidget);
        expect(rect.contains(tester.getCenter(fullscreen)), isTrue);
        expect(tester.takeException(), isNull);
      }
      final opens = f.platform.opened.length;
      f.fullscreenRequests.value++;
      await tester.pumpAndSettle();
      expect(f.host.fullscreenCalls.last, isTrue);
      expect(f.platform.opened.length, opens);
      f.fullscreenRequests.value++;
      await tester.pumpAndSettle();
      expect(f.host.fullscreenCalls.last, isFalse);
      expect(f.platform.opened.length, opens);
    },
  );
  testWidgets(
    'Android folded/unfolded/orientation sizes retain one engine, texture, position and selected tracks',
    (tester) async {
      final f = await _mount(tester);
      final videoElement = tester.element(find.byType(Video));
      await f.platform.seek(const Duration(seconds: 70));
      await f.platform.setAudioTrack(const AudioTrack('2', 'English', 'eng'));
      await f.platform.setSubtitleTrack(
        const SubtitleTrack('s-fr', 'Français', 'fra'),
      );
      for (final size in [
        const Size(840, 740),
        const Size(430, 900),
        const Size(900, 430),
        const Size(520, 600),
      ]) {
        tester.view.physicalSize = size;
        await tester.pumpAndSettle();
        expect(f.platform.opened, hasLength(1));
        expect(f.platform.state.position, const Duration(seconds: 70));
        expect(f.platform.state.track.audio.id, '2');
        expect(f.platform.state.track.subtitle.id, 's-fr');
        expect(tester.element(find.byType(Video)), same(videoElement));
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets('Android side double taps seek VOD and never seek live', (
    tester,
  ) async {
    final f = await _mount(tester);
    await f.platform.seek(const Duration(seconds: 50));
    final rect = tester.getRect(
      find.byKey(const ValueKey('player-touch-surface')),
    );
    await _doubleTap(tester, Offset(rect.right - 28, rect.center.dy));
    expect(f.platform.state.position, const Duration(seconds: 60));
    await _doubleTap(tester, Offset(rect.left + 28, rect.center.dy));
    expect(f.platform.state.position, const Duration(seconds: 50));
    await f.remount(live: true);
    f.platform.seeks.clear();
    await _doubleTap(tester, Offset(rect.right - 28, rect.center.dy));
    expect(f.platform.seeks, isEmpty);
  });

  testWidgets(
    'Android vertical gestures adjust window brightness and system volume, not image filtering',
    (tester) async {
      final f = await _mount(tester);
      final rect = tester.getRect(
        find.byKey(const ValueKey('player-touch-surface')),
      );
      await tester.dragFrom(
        Offset(rect.left + 24, rect.center.dy),
        const Offset(0, -50),
      );
      await tester.pumpAndSettle();
      expect(f.host.brightnessCalls.last, greaterThan(.5));
      await tester.dragFrom(
        Offset(rect.right - 24, rect.center.dy),
        const Offset(0, -50),
      );
      await tester.pumpAndSettle();
      expect(f.host.volumeCalls.last, greaterThan(55));
      expect(f.platform.state.volume, 100);
    },
  );

  testWidgets(
    'Disabled gestures and touch lock prevent accidental adjustments',
    (tester) async {
      final f = await _mount(tester, gestures: false);
      final rect = tester.getRect(
        find.byKey(const ValueKey('player-touch-surface')),
      );
      await tester.dragFrom(
        Offset(rect.right - 24, rect.center.dy),
        const Offset(0, -50),
      );
      await tester.pumpAndSettle();
      expect(f.host.volumeCalls, isEmpty);
      await f.remount(gestures: true);
      await tester.tap(find.byTooltip('Verrouiller les commandes tactiles'));
      await tester.pumpAndSettle();
      await tester.dragFrom(
        Offset(rect.right - 24, rect.center.dy),
        const Offset(0, -50),
      );
      await tester.pumpAndSettle();
      expect(f.host.volumeCalls, isEmpty);
      await tester.tap(find.text('Déverrouiller'));
      await tester.pumpAndSettle();
      await tester.dragFrom(
        Offset(rect.right - 24, rect.center.dy),
        const Offset(0, -50),
      );
      await tester.pumpAndSettle();
      expect(f.host.volumeCalls, isNotEmpty);
    },
  );

  testWidgets(
    'Android fullscreen and PiP preserve the same playing engine and release keep-screen-on',
    (tester) async {
      final f = await _mount(tester);
      await tester.tap(find.byTooltip('Plein écran'));
      await tester.pumpAndSettle();
      expect(f.host.fullscreenCalls.last, isTrue);
      expect(f.platform.opened, hasLength(1));
      await tester.tap(find.byTooltip('Options du lecteur'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lecture dans une fenêtre flottante'));
      await tester.pumpAndSettle();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(f.platform.state.playing, isTrue);
      expect(f.host.keepScreenCalls.last, isFalse);
      expect(f.platform.opened, hasLength(1));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      f.host.event('pipChanged', false);
      await tester.pumpAndSettle();
      expect(f.platform.state.playing, isTrue);
      expect(f.platform.opened, hasLength(1));
    },
  );

  testWidgets(
    'Background pauses without stopping the source and foreground resumes existing position',
    (tester) async {
      final f = await _mount(tester);
      await f.platform.seek(const Duration(seconds: 70));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump(const Duration(milliseconds: 400));
      expect(f.platform.state.playing, isTrue);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(f.platform.state.playing, isFalse);
      expect(f.host.keepScreenCalls.last, isFalse);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(f.platform.state.playing, isTrue);
      expect(f.platform.state.position, const Duration(seconds: 70));
      expect(f.platform.opened, hasLength(1));
    },
  );

  testWidgets(
    'Network recovery resumes VOD position, rate, audio and subtitle instead of restarting',
    (tester) async {
      final f = await _mount(tester, reconnectDelay: 1);
      await f.platform.seek(const Duration(seconds: 70));
      await f.platform.setRate(1.5);
      await f.platform.setAudioTrack(const AudioTrack('2', 'English', 'eng'));
      await f.platform.setSubtitleTrack(
        const SubtitleTrack('s-fr', 'Français', 'fra'),
      );
      f.platform.buffer();
      await tester.pump();
      await tester.pump(const Duration(seconds: 8));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(f.platform.opened, hasLength(2));
      expect(f.platform.opened.last.start, const Duration(seconds: 70));
      expect(f.platform.state.rate, 1.5);
      expect(f.platform.state.track.audio.id, '2');
      expect(f.platform.state.track.subtitle.id, 's-fr');
    },
  );

  testWidgets('Reconnect attempts are bounded and next episode fires once', (
    tester,
  ) async {
    var next = 0;
    final f = await _mount(
      tester,
      reconnectDelay: 1,
      reconnectAttempts: 2,
      onNext: () => next++,
    );
    f.platform.failOpen = true;
    f.platform.buffer();
    await tester.pump();
    await tester.pump(const Duration(seconds: 8));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 40));
    await tester.pumpAndSettle();
    expect(f.platform.opened, hasLength(3));
    f.platform.failOpen = false;
    await tester.tap(find.text('Réessayer'));
    await tester.pumpAndSettle();
    await tester.pump();
    await tester.pumpAndSettle();
    expect(f.platform.state.playing, isTrue);
    f.platform.complete();
    f.platform.complete();
    await tester.pumpAndSettle();
    expect(next, 1);
    expect(f.host.keepScreenCalls.last, isFalse);
  });
}

Future<void> _doubleTap(WidgetTester tester, Offset position) async {
  await tester.tapAt(position);
  await tester.pump(const Duration(milliseconds: 50));
  await tester.tapAt(position);
  await tester.pumpAndSettle();
}

Future<void> _pinch(
  WidgetTester tester,
  Offset center, {
  required bool expand,
}) async {
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
    final distance = start + (end - start) * step / 5;
    await left.moveTo(center - Offset(distance, 0));
    await right.moveTo(center + Offset(distance, 0));
    await tester.pump(const Duration(milliseconds: 16));
  }
  await right.up();
  await left.moveBy(const Offset(0, -20));
  await left.up();
  await tester.pumpAndSettle();
}

Future<_Fixture> _mount(
  WidgetTester tester, {
  bool gestures = true,
  int reconnectDelay = 3,
  int reconnectAttempts = 3,
  VoidCallback? onNext,
  bool television = false,
}) async {
  tester.view.physicalSize = const Size(430, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final f = _Fixture(tester, reconnectDelay, reconnectAttempts, onNext);
  await f.remount(gestures: gestures, television: television);
  addTearDown(() async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    f.video.notifier.dispose();
    await f.host.dispose();
  });
  return f;
}

class _Fixture {
  int closed = 0;
  final backRequests = ValueNotifier<int>(0);
  String? selectedChannel;
  int channelNext = 0;
  int channelPrevious = 0;
  _Fixture(this.tester, this.delay, this.attempts, this.onNext);
  final WidgetTester tester;
  final int delay;
  final int attempts;
  final VoidCallback? onNext;
  final host = _FakeHost();
  final platform = _FakePlatform();
  late final player = Player(platformPlayer: platform);
  late final video = _FakeVideo(player);
  final key = GlobalKey();
  final fullscreenRequests = ValueNotifier<int>(0);
  Future<void> remount({
    bool television = false,
    bool gestures = true,
    bool live = false,
    bool closeable = false,
    double? width,
    double height = 340,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              height: height,
              width: width,
              child: NovaPlayer(
                television: television,
                onNextChannel: () => channelNext++,
                onPreviousChannel: () => channelPrevious++,
                channelChoices: const [
                  TvChannelOption(id: 'a1', title: 'A1', category: 'A'),
                  TvChannelOption(id: 'a2', title: 'A2', category: 'A'),
                  TvChannelOption(id: 'b1', title: 'B1', category: 'B'),
                  TvChannelOption(id: 'b2', title: 'B2', category: 'B'),
                ],
                selectedChannelId: 'a1',
                onSelectChannel: (id) => selectedChannel = id,
                key: key,
                fullscreenRequests: fullscreenRequests,
                backRequests: backRequests,
                onClose: closeable ? () => closed++ : null,
                android: true,
                androidHost: host,
                uri: 'http://localhost/original-fixture.mp4',
                title: 'Création originale',
                isLive: live,
                touchGestures: gestures,
                reconnectDelaySeconds: delay,
                reconnectAttempts: attempts,
                onNext: onNext,
                backendFactory: () =>
                    NovaPlayerBackend(player: player, videoController: video),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pump();
    await tester.pumpAndSettle();
  }
}

class _FakeVideo implements VideoController {
  _FakeVideo(this.player);
  @override
  final Player player;
  @override
  final notifier = ValueNotifier<PlatformVideoController?>(null);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHost implements AndroidPlayerHost {
  final _events = StreamController<AndroidPlayerEvent>.broadcast(sync: true);
  final volumeCalls = <double>[];
  final brightnessCalls = <double>[];
  final fullscreenCalls = <bool>[];
  final keepScreenCalls = <bool>[];
  @override
  Stream<AndroidPlayerEvent> get events => _events.stream;
  void event(String name, Object? value) =>
      _events.add(AndroidPlayerEvent(name, value));
  @override
  Future<double> getVolume() async => 55;
  @override
  Future<double> getBrightness() async => .5;
  @override
  Future<bool> getPipSupported() async => true;
  @override
  Future<bool> enterPip() async {
    event('pipChanged', true);
    return true;
  }

  @override
  Future<void> setVolume(double value) async {
    volumeCalls.add(value);
  }

  @override
  Future<void> setBrightness(double value) async {
    brightnessCalls.add(value);
  }

  @override
  Future<void> setKeepScreenOn(bool value) async {
    keepScreenCalls.add(value);
  }

  @override
  Future<void> setFullscreen(bool enabled, {required bool landscape}) async {
    fullscreenCalls.add(enabled);
  }

  @override
  Future<void> setPlaybackActive(bool value) async {}
  @override
  Future<void> setPipEnabled(bool value) async {}
  Future<void> dispose() => _events.close();
}

class _FakePlatform extends PlatformPlayer {
  _FakePlatform() : super(configuration: const PlayerConfiguration()) {
    state = state.copyWith(
      duration: const Duration(minutes: 5),
      width: 640,
      height: 360,
      tracks: Tracks(
        audio: [
          AudioTrack.auto(),
          const AudioTrack('1', 'Français', 'fra'),
          const AudioTrack('2', 'English', 'eng'),
        ],
        subtitle: [
          SubtitleTrack.auto(),
          SubtitleTrack.no(),
          const SubtitleTrack('s-fr', 'Français', 'fra'),
        ],
      ),
    );
  }
  final opened = <Media>[];
  final seeks = <Duration>[];
  bool failOpen = false;
  void buffer() {
    state = state.copyWith(buffering: true);
    bufferingController.add(true);
  }

  void complete() {
    state = state.copyWith(playing: false, completed: true);
    playingController.add(false);
    completedController.add(true);
  }

  @override
  Future<void> open(Playable playable, {bool play = true}) async {
    final media = playable as Media;
    opened.add(media);
    if (failOpen) throw StateError('fixture connection failure');
    state = state.copyWith(
      position: media.start ?? Duration.zero,
      buffering: false,
    );
    bufferingController.add(false);
    if (play) await this.play();
  }

  @override
  Future<void> stop() async {
    state = state.copyWith(playing: false, position: Duration.zero);
    playingController.add(false);
  }

  @override
  Future<void> play() async {
    state = state.copyWith(
      playing: true,
      position: state.position == Duration.zero
          ? const Duration(seconds: 1)
          : state.position,
    );
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
    state = state.copyWith(volume: volume);
    volumeController.add(volume);
  }

  @override
  Future<void> setRate(double rate) async {
    state = state.copyWith(rate: rate);
    rateController.add(rate);
  }

  @override
  Future<void> setAudioTrack(AudioTrack track) async {
    state = state.copyWith(track: state.track.copyWith(audio: track));
    trackController.add(state.track);
  }

  @override
  Future<void> setSubtitleTrack(SubtitleTrack track) async {
    state = state.copyWith(track: state.track.copyWith(subtitle: track));
    trackController.add(state.track);
  }
}
