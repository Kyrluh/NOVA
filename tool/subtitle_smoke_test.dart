// Tests actual native subtitle decoding separately from Flutter text layout.
// No provider account, downloaded film or GPU surface is used.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'subtitle_fixture.dart';

void main() {
  test(
    'Native embedded FR/EN and external SRT cues decode at their timestamps',
    () async {
      final dll = File('build/windows/x64/runner/Release/libmpv-2.dll')
          .absolute;
      expect(
        await dll.exists(),
        isTrue,
        reason: 'Build Windows Release first.',
      );
      final fixture = await createSubtitleFixture(
        Directory('.tools/subtitle-smoke').absolute,
      );
      MediaKit.ensureInitialized(libmpv: dll.path);
      final player = Player(
        configuration: const PlayerConfiguration(
          vo: 'null',
          muted: true,
          title: 'NOVA subtitle verification',
        ),
      );
      final events = <Map<String, Object?>>[];
      final errors = <String>[];
      final subtitles = player.stream.subtitle.listen((lines) {
        events.add({
          'positionMs': player.state.position.inMilliseconds,
          'text': lines.join('\n'),
        });
      });
      final diagnostics = player.stream.error.listen(errors.add);
      try {
        // VideoController normally enables video decoding; this headless test
        // deliberately avoids a texture but still decodes the original frames.
        await player.setVideoTrack(VideoTrack.auto());
        await player.open(Media(fixture.video.path));
        await _until(
          () =>
              player.state.tracks.subtitle
                  .where((t) => t.id != 'auto' && t.id != 'no')
                  .length ==
              2,
          'embedded tracks',
        );
        await _until(
          () => player.state.width == 64 && player.state.height == 36,
          'original raw video decoded',
        );
        final french = player.state.tracks.subtitle.singleWhere(
          (t) => t.language == 'fra',
        );
        final english = player.state.tracks.subtitle.singleWhere(
          (t) => t.language == 'eng',
        );
        Future<void> seek(int milliseconds) async {
          await player.pause();
          await player.seek(Duration(milliseconds: milliseconds));
          await _until(
            () =>
                (player.state.position.inMilliseconds - milliseconds).abs() <
                300,
            'seek $milliseconds',
          );
        }

        await player.setSubtitleTrack(french);
        await seek(250);
        expect(player.state.subtitle.join().trim(), isEmpty);
        await player.play();
        await _until(
          () => player.state.subtitle.join().contains(
            'Bonjour NOVA, été français.',
          ),
          'FR first cue',
        );
        expect(
          player.state.position.inMilliseconds,
          inInclusiveRange(750, 2200),
        );
        await player.setSubtitleTrack(english);
        await seek(1500);
        await player.play();
        await _until(
          () => player.state.subtitle.join().contains(
            'Hello NOVA, English subtitles.',
          ),
          'EN selection decodes current cue',
        );
        expect(player.state.subtitle.join(), isNot(contains('Bonjour')));
        await player.setSubtitleTrack(SubtitleTrack.no());
        await _until(
          () => player.state.subtitle.every((line) => line.trim().isEmpty),
          'disable clears text',
        );
        await seek(6500);
        await player.play();
        await Future<void>.delayed(const Duration(milliseconds: 350));
        expect(
          player.state.subtitle.join().trim(),
          isEmpty,
          reason: 'Disabled subtitles must remain absent during a cue.',
        );
        await player.setSubtitleTrack(french);
        await seek(6500);
        await player.play();
        await _until(
          () => player.state.subtitle.join().contains(
            'Deuxième réplique française.',
          ),
          'FR later cue',
        );
        await seek(4500);
        await player.play();
        await _until(
          () => player.state.subtitle.join().trim().isEmpty,
          'gap clears text',
        );
        await player.setSubtitleTrack(
          SubtitleTrack.uri(
            fixture.external.uri.toString(),
            title: 'Original SRT',
            language: 'fra',
          ),
        );
        await seek(1500);
        await player.play();
        await _until(
          () => player.state.subtitle.join().contains(
            'Sous-titre SRT externe : été.',
          ),
          'external UTF-8 SRT',
        );
        final native = player.platform! as NativePlayer;
        expect(
          await native.getProperty('sub-text'),
          contains('Sous-titre SRT externe'),
        );
        final brightnessReadback = <String, double>{};
        for (final value in [10, -10, 0]) {
          await native.setProperty('brightness', '$value');
          final actual = double.parse(await native.getProperty('brightness'));
          expect(actual, value.toDouble());
          brightnessReadback['$value'] = actual;
        }
        expect(errors, isEmpty, reason: 'Native errors: ${errors.join(', ')}');
        await File('.tools/subtitle-smoke-results.json').writeAsString(
          const JsonEncoder.withIndent('  ').convert({
            'completedUtc': DateTime.now().toUtc().toIso8601String(),
            'mpvVersion': await native.getProperty('mpv-version'),
            'fixture': 'Original raw BGR video 64x36, PCM silence, embedded UTF-8 French/English, external UTF-8 SRT.',
            'decodedVideo': '${player.state.width}x${player.state.height}',
            'passed': [
              'delayed first FR cue',
              'English selection and decoded text',
              'disable during active cue',
              'later French cue',
              'empty gap',
              'external SRT and native sub-text',
            ],
            'subtitleEvents': events,
            'nativeBrightnessReadback': brightnessReadback,
            'limits': 'vo:null decoder/clock test; brightness API accepted but pixels not measured; no native GPU, bitmap subtitles or provider stream tested.',
          }),
        );
      } finally {
        await subtitles.cancel();
        await diagnostics.cancel();
        await player.dispose();
      }
    },
    timeout: const Timeout(Duration(seconds: 30)),
    skip: !Platform.isWindows,
  );

  testWidgets(
    'Video with NoVideoControls retains and updates its Flutter subtitle overlay',
    (tester) async {
      final platform = _WidgetSubtitlePlayer();
      final player = Player(platformPlayer: platform);
      final controller = _TextOnlyVideoController(player);
      try {
        await tester.pumpWidget(
          MaterialApp(
            home: SizedBox(
              width: 640,
              height: 360,
              child: Video(
                controller: controller,
                controls: NoVideoControls,
                wakelock: false,
              ),
            ),
          ),
        );
        expect(find.byType(SubtitleView), findsOneWidget);
        // A widget-only input: native decoding is independently checked above.
        // ignore: invalid_use_of_protected_member
        player.platform!.subtitleController.add([
          'Bonjour NOVA, été français.',
          '',
        ]);
        await tester.pumpAndSettle();
        expect(find.text('Bonjour NOVA, été français.'), findsOneWidget);
        // ignore: invalid_use_of_protected_member
        player.platform!.subtitleController.add([
          'Hello NOVA, English subtitles.',
          '',
        ]);
        await tester.pumpAndSettle();
        expect(find.text('Hello NOVA, English subtitles.'), findsOneWidget);
        expect(find.text('Bonjour NOVA, été français.'), findsNothing);
        // ignore: invalid_use_of_protected_member
        player.platform!.subtitleController.add(['', '']);
        await tester.pumpAndSettle();
        expect(find.text('Hello NOVA, English subtitles.'), findsNothing);
        await tester.pumpWidget(const SizedBox());
      } finally {
        controller.notifier.dispose();
        await player.dispose();
      }
    },
    skip: !Platform.isWindows,
  );
}

Future<void> _until(bool Function() condition, String label) async {
  final watch = Stopwatch()..start();
  while (!condition()) {
    if (watch.elapsed > const Duration(seconds: 4)) {
      throw TimeoutException(label);
    }
    await Future<void>.delayed(const Duration(milliseconds: 25));
  }
}

// Avoids creating any native texture or requiring a GPU in a widget test.
class _TextOnlyVideoController implements VideoController {
  @override
  final Player player;
  @override
  final notifier = ValueNotifier<PlatformVideoController?>(null);
  _TextOnlyVideoController(this.player);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _WidgetSubtitlePlayer extends PlatformPlayer {
  _WidgetSubtitlePlayer() : super(configuration: const PlayerConfiguration());
}
