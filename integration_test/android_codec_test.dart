import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:nova_iptv/player/android_session_player.dart';
import 'package:nova_iptv/player/android_video_environment.dart';
import 'package:path_provider/path_provider.dart';

import 'support/compressed_fixtures.dart';
import 'support/local_transport_server.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized().framePolicy =
      LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  for (final codec in ['h264', 'hevc']) {
    testWidgets(
      'Native Android decodes original $codec and switches AAC/subtitle tracks',
      (tester) async {
        MediaKit.ensureInitialized();
        await AndroidVideoEnvironment.initialize();
        final directory = await getTemporaryDirectory();
        final file = File('${directory.path}/nova-original-$codec.mkv');
        await file.writeAsBytes(
          codec == 'h264' ? h264Fixture() : hevcFixture(),
        );
        final player = AndroidSessionPlayer(
          configuration: const PlayerConfiguration(muted: true),
        );
        final controller = createNovaVideoController(player);
        final report = <String, Object?>{
          'codecFixture': codec,
          'passed': false,
        };
        try {
          await tester.pumpWidget(_videoSurface(controller));
          await tester.pump();
          await player.open(Media(file.path));
          await _until(
            tester,
            () =>
                player.state.position.inMilliseconds > 300 &&
                player.state.width == 320 &&
                player.state.height == 180,
            '$codec playback and dimensions',
          );
          await _until(
            tester,
            () => controller.id.value != null,
            '$codec native texture',
          );
          await controller.waitUntilFirstFrameRendered.timeout(
            const Duration(seconds: 15),
          );
          await _until(
            tester,
            () =>
                player.state.tracks.audio
                        .where((t) => !{'auto', 'no'}.contains(t.id))
                        .length ==
                    2 &&
                player.state.tracks.subtitle
                        .where((t) => !{'auto', 'no'}.contains(t.id))
                        .length ==
                    2,
            'AAC and subtitle tracks',
          );
          final audio = player.state.tracks.audio
              .where((t) => !{'auto', 'no'}.contains(t.id))
              .toList();
          final subtitles = player.state.tracks.subtitle
              .where((t) => !{'auto', 'no'}.contains(t.id))
              .toList();
          await player.setAudioTrack(audio.first);
          await _until(
            tester,
            () => player.state.track.audio.id == audio.first.id,
            'First AAC language',
          );
          await player.setAudioTrack(audio.last);
          await _until(
            tester,
            () => player.state.track.audio.id == audio.last.id,
            'Second AAC language',
          );
          await player.setSubtitleTrack(subtitles.first);
          await player.seek(const Duration(milliseconds: 1500));
          await _until(
            tester,
            () => player.state.subtitle.join().trim().isNotEmpty,
            'First subtitle cue',
          );
          final firstCue = player.state.subtitle.join();
          await player.setSubtitleTrack(subtitles.last);
          await player.seek(const Duration(milliseconds: 1500));
          await _until(
            tester,
            () =>
                player.state.subtitle.join().trim().isNotEmpty &&
                player.state.subtitle.join() != firstCue,
            'Second subtitle language',
          );
          final native = player.platform! as NativePlayer;
          report.addAll({
            'passed': true,
            'videoCodec': await native.getProperty('video-codec'),
            'hwdecCurrent': await native.getProperty('hwdec-current'),
            'width': player.state.width,
            'height': player.state.height,
            'audioTrackCount': audio.length,
            'subtitleTrackCount': subtitles.length,
            'limits': 'Decoder success on this emulator is not hardware decoder validation on a physical Samsung.',
          });
        } finally {
          await tester.pumpWidget(const SizedBox());
          await player.dispose();
          await _writeReport('android-$codec-validation', report);
        }
      },
      timeout: const Timeout(Duration(seconds: 90)),
    );
  }

  testWidgets('Native Android reads original MPEG-TS and HLS over local HTTP', (
    tester,
  ) async {
    MediaKit.ensureInitialized();
    await AndroidVideoEnvironment.initialize();
    final bytes = transportStreamFixture();
    final server = await LocalTransportServer.start(bytes);
    final requests = server.requests;
    final player = AndroidSessionPlayer(
      configuration: const PlayerConfiguration(
        muted: true,
        logLevel: MPVLogLevel.debug,
      ),
    );
    final controller = createNovaVideoController(player);
    final passed = <String>[];
    final errors = <String>[];
    final logs = <String>[];
    final logListener = player.stream.log.listen((entry) {
      if (!entry.prefix.contains('ffmpeg') &&
          !entry.prefix.contains('demux') &&
          !entry.prefix.contains('lavf')) {
        return;
      }
      if (logs.length >= 150) logs.removeAt(0);
      logs.add(
        '${entry.prefix}:${entry.level}:${entry.text}'.replaceAll(
          RegExp(r'https?://[^\s]+'),
          '<fixture-http>',
        ),
      );
    });
    final listener = player.stream.error.listen(
      (error) => errors.add(
        error.replaceAll(RegExp(r'https?://[^\s]+'), '<fixture-http>'),
      ),
    );
    try {
      await tester.pumpWidget(_videoSurface(controller));
      await tester.pump();
      for (final (label, path) in const [
        ('HLS HTTP fresh player', 'original.m3u8'),
        ('MPEG-TS HTTP', 'original.ts'),
        ('HLS HTTP reused player', 'original.m3u8'),
      ]) {
        await player.open(Media('http://127.0.0.1:${server.port}/$path'));
        await _until(
          tester,
          () =>
              player.state.position.inMilliseconds > 300 &&
              player.state.width == 320,
          'Local HTTP $path',
        );
        await _until(
          tester,
          () => controller.id.value != null,
          'HTTP video texture',
        );
        passed.add(label);
        await player.stop();
      }
    } finally {
      await tester.pumpWidget(const SizedBox());
      final lastState = {
        'positionMs': player.state.position.inMilliseconds,
        'width': player.state.width,
        'playing': player.state.playing,
        'buffering': player.state.buffering,
        'completed': player.state.completed,
      };
      await listener.cancel();
      await logListener.cancel();
      await player.dispose();
      await server.close(force: true);
      await _writeReport('android-http-playback-validation', {
        'passed': passed,
        'requests': requests,
        'diagnostics': errors,
        'demuxerLogs': logs,
        'lastState': lastState,
        'limits': 'Original local HTTP fixture; not a live provider, DRM, reconnect stress or prolonged-use test.',
      });
    }
    expect(passed, hasLength(3));
  }, timeout: const Timeout(Duration(seconds: 90)));
}

Widget _videoSurface(VideoController controller) => MaterialApp(
  home: Scaffold(
    body: Video(
      controller: controller,
      controls: NoVideoControls,
      wakelock: false,
      pauseUponEnteringBackgroundMode: false,
      resumeUponEnteringForegroundMode: false,
    ),
  ),
);

Future<void> _until(
  WidgetTester tester,
  bool Function() ready,
  String label,
) async {
  final watch = Stopwatch()..start();
  while (!ready() && watch.elapsed < const Duration(seconds: 15)) {
    await tester.pump(const Duration(milliseconds: 80));
    await Future<void>.delayed(const Duration(milliseconds: 80));
  }
  expect(ready(), isTrue, reason: label);
}

Future<void> _writeReport(String name, Map<String, Object?> report) async {
  final directory = await getApplicationSupportDirectory();
  report['completedUtc'] = DateTime.now().toUtc().toIso8601String();
  await File('${directory.path}/$name.json')
      .writeAsString(const JsonEncoder.withIndent('  ').convert(report));
  // ignore: avoid_print
  print('NOVA_ANDROID_NATIVE_REPORT=${jsonEncode(report)}');
}
