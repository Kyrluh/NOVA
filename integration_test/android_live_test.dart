import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:nova_iptv/player/android_session_player.dart';
import 'package:nova_iptv/player/android_video_environment.dart';
import 'package:nova_iptv/player/nova_player.dart';
import 'package:path_provider/path_provider.dart';

import 'support/compressed_fixtures.dart';
import 'support/local_transport_server.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized().framePolicy =
      LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets(
    'Native Android live session survives compact, wide and compact layouts without seeking',
    (tester) async {
      MediaKit.ensureInitialized();
      await AndroidVideoEnvironment.initialize();
      final server = await LocalTransportServer.start(transportStreamFixture());
      final player = _ObservedLivePlayer();
      final controller = createNovaVideoController(player);
      final dimensions = ValueNotifier(const Size(412, 480));
      final playerIdentity = identityHashCode(player);
      final controllerIdentity = identityHashCode(controller);
      var factoryCalls = 0;
      var mounted = false;
      final report = <String, Object?>{
        'passed': false,
        'fixture': 'Original generated 12-second H264/AAC MPEG-TS over isolated loopback HTTP, opened through the live branch',
        'limitation': 'Finite local media exercises the live player policy; continuous provider TV, timeshift and physical Samsung decoding still require device testing. Decoded dimensions and a native frame event complement the separate host video pixel checks.',
      };
      try {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: ValueListenableBuilder<Size>(
                  valueListenable: dimensions,
                  builder: (_, size, _) => FittedBox(
                    child: SizedBox(
                      width: size.width,
                      height: size.height,
                      child: MediaQuery(
                        data: MediaQueryData(size: size),
                        child: NovaPlayer(
                          key: const ValueKey('native-live-session'),
                          uri: 'http://127.0.0.1:${server.port}/original.ts',
                          title: 'Validation TV originale NOVA',
                          android: true,
                          isLive: true,
                          reconnectEnabled: false,
                          autoNext: false,
                          initialVolume: 0,
                          backendFactory: () {
                            factoryCalls++;
                            return NovaPlayerBackend(
                              player: player,
                              videoController: controller,
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        mounted = true;
        await _until(
          tester,
          () =>
              player.state.position.inMilliseconds > 300 &&
              player.state.width == 320 &&
              player.state.height == 180 &&
              controller.id.value != null,
          'The real live-branch HTTP video must start',
        );
        await controller.waitUntilFirstFrameRendered.timeout(
          const Duration(seconds: 10),
        );
        await _until(
          tester,
          () => player.state.tracks.audio.any(
            (track) => !{'auto', 'no'}.contains(track.id),
          ),
          'The MPEG-TS AAC audio track must be available',
        );
        final audio = player.state.tracks.audio.firstWhere(
          (track) => !{'auto', 'no'}.contains(track.id),
        );
        await player.setAudioTrack(audio);
        await player.setSubtitleTrack(SubtitleTrack.no());
        await _until(
          tester,
          () =>
              player.state.track.audio.id == audio.id &&
              player.state.track.subtitle.id == 'no',
          'The selected live audio and subtitle state must settle',
        );
        final audioId = player.state.track.audio.id;
        final subtitleId = player.state.track.subtitle.id;
        final layouts = <Map<String, Object?>>[];
        var layoutIndex = 0;
        for (final size in const [
          Size(412, 480),
          Size(840, 680),
          Size(412, 480),
        ]) {
          final before = player.state.position.inMilliseconds;
          final minimumProgress = layoutIndex++ == 0 ? 500 : 1500;
          dimensions.value = size;
          await tester.pump(const Duration(milliseconds: 100));
          await _until(
            tester,
            () =>
                player.state.position.inMilliseconds > before + minimumProgress,
            'The live clock must advance after responsive reorganization',
          );
          expect(player.isLive, isTrue);
          expect(player.openCount, 1);
          expect(factoryCalls, 1);
          expect(identityHashCode(player), playerIdentity);
          expect(identityHashCode(controller), controllerIdentity);
          expect(
            tester.widget<Video>(find.byType(Video)).controller,
            same(controller),
          );
          expect(player.state.track.audio.id, audioId);
          expect(player.state.track.subtitle.id, subtitleId);
          expect(player.state.width, 320);
          expect(player.state.height, 180);
          expect(player.state.completed, isFalse);
          layouts.add({
            'width': size.width,
            'height': size.height,
            'beforeMs': before,
            'afterMs': player.state.position.inMilliseconds,
            'openCount': player.openCount,
            'audioId': player.state.track.audio.id,
            'subtitleId': player.state.track.subtitle.id,
          });
        }
        expect(
          player.seekAttempts.every((live) => live),
          isTrue,
          reason: 'Any Android Surface seek request must be suppressed by the live-session policy',
        );
        report.addAll({
          'passed': true,
          'openCount': player.openCount,
          'backendFactoryCalls': factoryCalls,
          'suppressedSurfaceSeekRequests': player.seekAttempts.length,
          'layouts': layouts,
          'httpRequests': server.requests,
        });
      } finally {
        if (mounted) {
          await tester.pumpWidget(const SizedBox.shrink());
          await player.released.future.timeout(const Duration(seconds: 10));
        } else {
          await player.dispose();
        }
        dimensions.dispose();
        await server.close(force: true);
        final directory = await getApplicationSupportDirectory();
        await File('${directory.path}/android-live-validation.json')
            .writeAsString(const JsonEncoder.withIndent('  ').convert(report));
        // Only generated media metadata is included; no provider credentials or URLs.
        // ignore: avoid_print
        print('NOVA_ANDROID_LIVE_REPORT=${jsonEncode(report)}');
      }
    },
    timeout: const Timeout(Duration(seconds: 45)),
  );
}

class _ObservedLivePlayer extends AndroidSessionPlayer {
  _ObservedLivePlayer()
    : super(
        isLive: true,
        configuration: const PlayerConfiguration(muted: true),
      );
  int openCount = 0;
  final seekAttempts = <bool>[];
  final released = Completer<void>();

  @override
  Future<void> open(Playable playable, {bool play = true}) {
    openCount++;
    return super.open(playable, play: play);
  }

  @override
  Future<void> seek(Duration duration) {
    seekAttempts.add(isLive);
    return super.seek(duration);
  }

  @override
  Future<void> dispose() async {
    try {
      await super.dispose();
    } finally {
      if (!released.isCompleted) released.complete();
    }
  }
}

Future<void> _until(
  WidgetTester tester,
  bool Function() condition,
  String reason,
) async {
  final watch = Stopwatch()..start();
  while (!condition() && watch.elapsed < const Duration(seconds: 8)) {
    await tester.pump(const Duration(milliseconds: 80));
    await Future<void>.delayed(const Duration(milliseconds: 80));
  }
  expect(condition(), isTrue, reason: reason);
}
