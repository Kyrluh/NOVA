import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:nova_iptv/player/android_player_host.dart';
import 'package:nova_iptv/player/nova_player.dart';

void main() {
  for (final nativeFirst in [true, false]) {
    testWidgets(
      'onReleased waits for media and native cleanup ($nativeFirst)',
      (tester) async {
        var released = 0;
        final fixture = await _mount(tester, onReleased: () => released++);
        final mediaGate = fixture.platform.disposeGate = Completer<void>();
        final nativeGate = fixture.host.releaseGate = Completer<void>();
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        expect(released, 0);

        (nativeFirst ? nativeGate : mediaGate).complete();
        await tester.pumpAndSettle();
        expect(released, 0);

        (nativeFirst ? mediaGate : nativeGate).complete();
        await tester.pumpAndSettle();
        // Stream cancellation can complete in the real async zone.
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
        await tester.pump();
        expect(fixture.platform.disposed, isTrue);
        expect(released, 1);
        expect(fixture.host.cleanupCompleted, isTrue);
      },
    );
  }

  testWidgets('Failed source resumes its deferred retry after backgrounding', (
    tester,
  ) async {
    final fixture = await _mount(tester);
    await fixture.platform.seek(const Duration(seconds: 70));
    await fixture.platform.setAudioTrack(
      const AudioTrack('2', 'English', 'eng'),
    );
    await fixture.platform.setSubtitleTrack(
      const SubtitleTrack('s-fr', 'French', 'fra'),
    );
    fixture.platform.buffer();
    await tester.pump();
    await tester.pump(const Duration(seconds: 8));

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(seconds: 3));
    expect(fixture.platform.opened, hasLength(1));
    expect(fixture.platform.state.playing, isFalse);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(fixture.platform.opened, hasLength(2));
    expect(fixture.platform.opened.last.start, const Duration(seconds: 70));
    expect(fixture.platform.state.track.audio.id, '2');
    expect(fixture.platform.state.track.subtitle.id, 's-fr');
    expect(fixture.platform.state.playing, isTrue);
  });

  testWidgets('Slow open completed in background stays paused until resumed', (
    tester,
  ) async {
    final fixture = await _mount(tester, slowOpen: true);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(milliseconds: 400));
    fixture.platform.firstOpen!.complete();
    await tester.pumpAndSettle();
    expect(fixture.platform.state.playing, isFalse);
    expect(fixture.platform.playCalls, 0);
    expect(fixture.host.keepScreenOn, isFalse);
    expect(fixture.host.playbackActive, isFalse);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(fixture.platform.state.playing, isTrue);
    expect(fixture.platform.opened, hasLength(1));
    expect(fixture.platform.playCalls, 1);
  });

  testWidgets('Slow open failure cannot reconnect while hidden', (
    tester,
  ) async {
    final fixture = await _mount(tester, slowOpen: true, failFirstOpen: true);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await tester.pump(const Duration(milliseconds: 400));
    fixture.platform.firstOpen!.complete();
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 10));
    expect(fixture.platform.opened, hasLength(1));
    expect(fixture.platform.playCalls, 0);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(fixture.platform.opened, hasLength(2));
    expect(fixture.platform.state.playing, isTrue);
  });
}

Future<_Fixture> _mount(
  WidgetTester tester, {
  bool slowOpen = false,
  bool failFirstOpen = false,
  VoidCallback? onReleased,
}) async {
  tester.view.physicalSize = const Size(430, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final platform = _Platform(
    firstOpen: slowOpen ? Completer<void>() : null,
    failFirstOpen: failFirstOpen,
  );
  final player = Player(platformPlayer: platform);
  final video = _Video(player);
  final host = _Host();
  addTearDown(() async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    video.notifier.dispose();
    await host.eventsController.close();
  });
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: NovaPlayer(
          android: true,
          androidHost: host,
          uri: 'http://localhost/original-fixture.mp4',
          title: 'Original fixture',
          reconnectDelaySeconds: 1,
          onReleased: onReleased,
          backendFactory: () =>
              NovaPlayerBackend(player: player, videoController: video),
        ),
      ),
    ),
  );
  if (slowOpen) {
    await tester.pump();
  } else {
    await tester.pumpAndSettle();
  }
  return _Fixture(platform, host);
}

class _Fixture {
  _Fixture(this.platform, this.host);
  final _Platform platform;
  final _Host host;
}

class _Video implements VideoController {
  _Video(this.player);
  @override
  final Player player;
  @override
  final notifier = ValueNotifier<PlatformVideoController?>(null);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Host implements AndroidPlayerHost {
  final eventsController = StreamController<AndroidPlayerEvent>.broadcast();
  bool keepScreenOn = false;
  bool playbackActive = false;
  Completer<void>? releaseGate;
  bool cleanupCompleted = false;
  @override
  Stream<AndroidPlayerEvent> get events => eventsController.stream;
  @override
  Future<double> getVolume() async => 50;
  @override
  Future<double> getBrightness() async => .5;
  @override
  Future<bool> getPipSupported() async => true;
  @override
  Future<bool> enterPip() async => false;
  @override
  Future<void> setBrightness(double value) async {}
  @override
  Future<void> setVolume(double value) async {}
  @override
  Future<void> setPipEnabled(bool value) async {
    if (!value && releaseGate != null) {
      await releaseGate!.future;
      cleanupCompleted = true;
    }
  }

  @override
  Future<void> setFullscreen(bool value, {required bool landscape}) async {}
  @override
  Future<void> setKeepScreenOn(bool value) async => keepScreenOn = value;
  @override
  Future<void> setPlaybackActive(bool value) async => playbackActive = value;
}

class _Platform extends PlatformPlayer {
  _Platform({this.firstOpen, required this.failFirstOpen})
    : super(configuration: const PlayerConfiguration()) {
    state = state.copyWith(duration: const Duration(minutes: 5));
  }
  final Completer<void>? firstOpen;
  final bool failFirstOpen;
  final opened = <Media>[];
  int playCalls = 0;
  Completer<void>? disposeGate;
  bool disposed = false;

  void buffer() => bufferingController.add(true);

  @override
  Future<void> dispose() async {
    await disposeGate?.future;
    await super.dispose();
    disposed = true;
  }

  @override
  Future<void> open(Playable playable, {bool play = true}) async {
    final media = playable as Media;
    opened.add(media);
    if (opened.length == 1) {
      await firstOpen?.future;
      if (failFirstOpen) throw StateError('Original fixture unavailable');
    }
    state = state.copyWith(position: media.start ?? Duration.zero);
    if (play) await this.play();
  }

  @override
  Future<void> play() async {
    playCalls++;
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
  Future<void> stop() async {
    state = state.copyWith(playing: false, position: Duration.zero);
    playingController.add(false);
  }

  @override
  Future<void> pause() async {
    state = state.copyWith(playing: false);
    playingController.add(false);
  }

  @override
  Future<void> seek(Duration position) async {
    state = state.copyWith(position: position);
    positionController.add(position);
  }

  @override
  Future<void> setRate(double rate) async {
    state = state.copyWith(rate: rate);
    rateController.add(rate);
  }

  @override
  Future<void> setVolume(double volume) async {
    state = state.copyWith(volume: volume);
    volumeController.add(volume);
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
