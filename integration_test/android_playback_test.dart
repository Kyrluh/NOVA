import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:nova_iptv/player/nova_player.dart';
import 'package:nova_iptv/player/android_session_player.dart';
import 'package:nova_iptv/player/android_video_environment.dart';
import 'package:path_provider/path_provider.dart';

import '../tool/subtitle_fixture.dart';
import 'android_codec_test.dart' as codec_checks;
import 'android_live_test.dart' as live_checks;
import 'support/long_fixture.dart';

const _nativeChannel = MethodChannel('nova/android');
const _nativeHandshake = bool.fromEnvironment('NOVA_FOLD_HANDSHAKE');
const _requestedSoakSeconds = int.fromEnvironment('NOVA_SOAK_SECONDS');

/// Real libmpv/Android texture test with an original generated long H.264.
/// Hardware decoder behavior still requires validation on a physical Samsung.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized().framePolicy =
      LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  codec_checks.main();
  live_checks.main();

  testWidgets(
    'Native Android playback preserves its session across responsive layouts',
    (tester) async {
      MediaKit.ensureInitialized();
      await AndroidVideoEnvironment.initialize();
      final directory = await getTemporaryDirectory();
      final subtitleFixture = await createSubtitleFixture(
        Directory('${directory.path}/nova-playback-validation'),
      );
      final video = File(
        '${directory.path}/nova-playback-validation/original-long-h264.mkv',
      );
      await video.writeAsBytes(longH264Fixture());
      final fixture = (video: video, external: subtitleFixture.external);
      final dimensions = ValueNotifier(const Size(412, 480));
      final player = _ObservedPlayer();
      final controller = createNovaVideoController(player);
      final playerIdentity = identityHashCode(player);
      final controllerIdentity = identityHashCode(controller);
      final errors = <String>[];
      final diagnostics = player.stream.error.listen(
        (_) => errors.add('native diagnostic'),
      );
      final report = <String, Object?>{
        'startedUtc': DateTime.now().toUtc().toIso8601String(),
        'fixture': 'Original generated long H264320x180 + AAC French/English + UTF8 French/English + external SRT',
        'nativeHandshakeEnabled': _nativeHandshake,
        'hardwareCodecsValidated': false,
      };
      HttpServer? server;
      var mounted = false;
      try {
        final initialActivity = await _diagnostics();
        report['activityBefore'] = initialActivity;
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
                          key: const ValueKey('native-owned-session'),
                          uri: fixture.video.path,
                          title: 'Validation originale NOVA',
                          android: true,
                          reconnectEnabled: false,
                          autoNext: false,
                          initialVolume: 0,
                          backendFactory: () => NovaPlayerBackend(
                            player: player,
                            videoController: controller,
                          ),
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
        await tester.pump();
        await _until(
          tester,
          () => player.state.position.inMilliseconds > 300,
          'Native playback clock starts',
        );
        await _until(
          tester,
          () => player.state.width == 320 && player.state.height == 180,
          'Original video frames decoded',
        );
        expect(
          player.state.duration.inSeconds,
          greaterThanOrEqualTo(110),
          reason:
              'The continuity fixture must outlast native transition checks',
        );
        report['fixtureSeconds'] = player.state.duration.inSeconds;
        if (_requestedSoakSeconds > 0) {
          expect(
            player.state.duration.inSeconds,
            greaterThan(_requestedSoakSeconds.clamp(0, 180) * 1.25 + 60),
            reason: 'The fixture must outlast the native transition and sustained playback checks',
          );
        }
        await _until(
          tester,
          () => controller.id.value != null && controller.rect.value != null,
          'Native Android video texture created',
        );
        await _until(
          tester,
          () =>
              player.state.tracks.subtitle
                  .where((t) => t.id != 'auto' && t.id != 'no')
                  .length ==
              2,
          'Both embedded subtitle tracks available',
        );
        await _until(
          tester,
          () => player.state.tracks.audio.any(
            (t) => t.id != 'auto' && t.id != 'no',
          ),
          'Original AAC audio track available',
        );

        final audio = player.state.tracks.audio.firstWhere(
          (t) => t.id != 'auto' && t.id != 'no',
        );
        final french = player.state.tracks.subtitle.firstWhere(
          (t) => const {'fra', 'fre', 'fr'}.contains(t.language),
        );
        final english = player.state.tracks.subtitle.firstWhere(
          (t) => const {'eng', 'en'}.contains(t.language),
        );
        await player.setAudioTrack(audio);
        await player.setSubtitleTrack(french);
        await player.seek(const Duration(milliseconds: 1500));
        await player.play();
        await _until(
          tester,
          () => player.state.subtitle.join().contains('Bonjour NOVA'),
          'French subtitle decoded',
        );
        await player.setSubtitleTrack(english);
        await player.seek(const Duration(milliseconds: 1500));
        await _until(
          tester,
          () => player.state.subtitle.join().contains('Hello NOVA'),
          'English subtitle selection decoded',
        );
        await player.setSubtitleTrack(
          SubtitleTrack.uri(
            fixture.external.uri.toString(),
            title: 'Original SRT',
            language: 'fra',
          ),
        );
        await player.seek(const Duration(milliseconds: 1500));
        await _until(
          tester,
          () => player.state.subtitle.join().contains('Sous-titre SRT externe'),
          'External SRT decoded',
        );
        await player.setSubtitleTrack(english);
        await player.setRate(1.25);
        await player.pause();
        await player.seek(const Duration(milliseconds: 3000));
        await _until(
          tester,
          () => (player.state.position.inMilliseconds - 3000).abs() < 450,
          'VOD seek applied',
        );
        await player.play();
        await _until(
          tester,
          () => player.state.position.inMilliseconds > 3300,
          'VOD resumes after seek',
        );
        report['subtitleAndAudioSelection'] = {
          'audioId': audio.id,
          'subtitleId': english.id,
          'rate': player.state.rate,
        };
        report['renderedVideo'] =
            '${player.state.width}x${player.state.height}';

        final selectedAudio = player.state.track.audio.id;
        final selectedSubtitle = player.state.track.subtitle.id;
        _NativeTransitionHandshake? handshake;
        if (_nativeHandshake) {
          handshake = await _NativeTransitionHandshake.start(
            () => _playbackSnapshot(tester, player),
          );
          server = handshake.server;
          final initialCapture = await handshake.initialCapture.future.timeout(
            const Duration(seconds: 100),
          );
          report['initialPixelCapture'] = initialCapture;
          expect(
            initialCapture is Map && initialCapture['passed'] == true,
            isTrue,
            reason: 'The original colored picture must be visible before any responsive resize',
          );
          handshake.phase = 'flutter-responsive-resizing';
        }
        final layouts = <Map<String, Object?>>[];
        for (final size in const [
          Size(412, 480),
          Size(840, 680),
          Size(412, 480),
          Size(760, 340),
          Size(360, 540),
        ]) {
          final before = player.state.position.inMilliseconds;
          dimensions.value = size;
          await tester.pump(const Duration(milliseconds: 120));
          await Future<void>.delayed(const Duration(milliseconds: 250));
          await tester.pump();
          expect(identityHashCode(player), playerIdentity);
          expect(identityHashCode(controller), controllerIdentity);
          expect(
            player.openCount,
            1,
            reason: 'Responsive resizing must not open the media again',
          );
          expect(player.state.track.audio.id, selectedAudio);
          expect(player.state.track.subtitle.id, selectedSubtitle);
          expect(player.state.rate, 1.25);
          layouts.add({
            'width': size.width,
            'height': size.height,
            'beforeMs': before,
            'afterMs': player.state.position.inMilliseconds,
            'playing': player.state.playing,
          });
        }
        report['flutterConstraintResizeOnly'] = layouts;

        if (_nativeHandshake) {
          handshake!.phase = 'waiting-native-transitions';
          final nativePlayingEvents = <bool>[];
          final watchPlaying = player.stream.playing.listen(
            nativePlayingEvents.add,
          );
          try {
            final hostTransitions = await handshake.transitions.future.timeout(
              const Duration(seconds: 100),
            );
            report['hostNativeTransitions'] = hostTransitions;
            expect(
              hostTransitions is Map && hostTransitions['passed'] == true,
              isTrue,
              reason: 'Host helper must report successful native transitions',
            );
            final samples = ((hostTransitions as Map)['transitions'] as List)
                .map(
                  (entry) =>
                      ((entry as Map)['state'] as Map)['positionMs'] as int,
                )
                .toList();
            expect(samples, hasLength(greaterThanOrEqualTo(6)));
            expect(
              samples.every((value) => value > 0),
              isTrue,
              reason:
                  'A playing flag alone is not proof that media time advances',
            );
            for (var index = 1; index < samples.length; index++) {
              expect(
                samples[index],
                greaterThanOrEqualTo(samples[index - 1] - 350),
                reason: 'Native transitions must not reset the VOD position',
              );
            }
            expect(
              samples.last - samples.first,
              greaterThan(1000),
              reason:
                  'Real media time must advance during the native transitions',
            );
            await tester.pump(const Duration(milliseconds: 150));
            expect(
              player.openCount,
              1,
              reason: 'Native transitions must retain the opened media',
            );
            expect(player.state.track.audio.id, selectedAudio);
            expect(player.state.track.subtitle.id, selectedSubtitle);
            expect(player.state.rate, 1.25);
            expect(player.state.width, 320);
            expect(player.state.height, 180);
            final afterNative = await _diagnostics();
            expect(
              afterNative['activityInstance'],
              initialActivity['activityInstance'],
              reason: 'Configuration changes must not recreate the activity',
            );
            expect(
              afterNative['configurationChanges'] as int,
              greaterThan(initialActivity['configurationChanges'] as int),
              reason: 'Actual native configuration changes must have occurred',
            );
            report['activityAfterNativeTransitions'] = afterNative;
            report['nativeTransitionPlayingEvents'] = nativePlayingEvents;
          } finally {
            await watchPlaying.cancel();
          }
        }

        final soakSeconds = _requestedSoakSeconds.clamp(0, 180);
        if (soakSeconds > 0) {
          final watch = Stopwatch()..start();
          final samples = <Map<String, Object?>>[];
          var previousPosition = player.state.position.inMilliseconds;
          var nextSample = 10;
          while (watch.elapsed.inSeconds < soakSeconds) {
            await tester.pump(const Duration(milliseconds: 250));
            await Future<void>.delayed(const Duration(milliseconds: 750));
            if (watch.elapsed.inSeconds >= nextSample) {
              final position = player.state.position.inMilliseconds;
              expect(
                position,
                greaterThan(previousPosition + 500),
                reason: 'The decoder clock must advance during the sustained playback sample',
              );
              expect(player.state.playing, isTrue);
              expect(player.openCount, 1);
              expect(player.state.track.audio.id, selectedAudio);
              expect(player.state.track.subtitle.id, selectedSubtitle);
              expect(player.state.rate, 1.25);
              samples.add({
                'elapsedSeconds': watch.elapsed.inSeconds,
                'positionMs': position,
                'playing': player.state.playing,
                'openCount': player.openCount,
              });
              previousPosition = position;
              nextSample += 10;
              // ignore: avoid_print
              print('NOVA_ANDROID_SOAK=${jsonEncode(samples.last)}');
            }
          }
          report['sustainedPlayback'] = {
            'requestedSeconds': soakSeconds,
            'elapsedSeconds': watch.elapsed.inSeconds,
            'samples': samples,
          };
        }

        final position = player.state.position;
        await _until(
          tester,
          () => player.state.position != position && player.state.playing,
          'Playback still progresses after all transitions',
        );
        await player.seek(const Duration(milliseconds: 1500));
        await _until(
          tester,
          () => player.state.subtitle.join().contains('Hello NOVA'),
          'Selected English subtitle still decodes after transitions',
        );
        report['selectedSubtitleDecodedAfterTransitions'] = true;
        await player.pause();
        await tester.pump(const Duration(milliseconds: 200));
        final afterPause = await _diagnostics();
        expect(
          afterPause['keepScreenOn'],
          isFalse,
          reason: 'Pausing playback must release screen-on flag',
        );
        report['activityAfterPause'] = afterPause;
        report['openCount'] = player.openCount;
        report['diagnosticEvents'] = errors.length;
        report['passed'] = true;
        report['limits'] = 'Original H264 fixture and same real player/texture controller; no physical Samsung hardware-decoder, prolonged-use or physical-fold proof. Native emulator transitions only when handshake enabled.';
      } finally {
        await server?.close(force: true);
        await diagnostics.cancel();
        if (mounted) {
          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(milliseconds: 100));
          await player.released.future.timeout(const Duration(seconds: 15));
        } else {
          await player.dispose();
        }
        dimensions.dispose();
        report['finishedUtc'] = DateTime.now().toUtc().toIso8601String();
        final support = await getApplicationSupportDirectory();
        await File('${support.path}/android-playback-validation.json')
            .writeAsString(const JsonEncoder.withIndent('  ').convert(report));
        // Reports contain generated fixture diagnostics, never private IPTV URLs.
        // ignore: avoid_print
        print('NOVA_ANDROID_PLAYBACK_REPORT=${jsonEncode(report)}');
      }
    },
    timeout: const Timeout(Duration(minutes: 8)),
  );
}

Future<Map<String, dynamic>> _diagnostics() async => Map<String, dynamic>.from(
  await _nativeChannel.invokeMapMethod<String, dynamic>('getDiagnostics') ?? {},
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

class _ObservedPlayer extends AndroidSessionPlayer {
  _ObservedPlayer()
    : super(
        configuration: const PlayerConfiguration(
          title: 'NOVA original Android validation',
          muted: true,
        ),
      );
  int openCount = 0;
  final released = Completer<void>();
  @override
  Future<void> open(Playable playable, {bool play = true}) {
    openCount++;
    return super.open(playable, play: play);
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

Future<Map<String, Object?>> _playbackSnapshot(
  WidgetTester tester,
  _ObservedPlayer player,
) async {
  final native = await _diagnostics();
  Map<String, Object?>? content;
  final video = find.byType(Video).evaluate().toList(growable: false);
  final renderObject = video.length == 1
      ? video.single.findRenderObject()
      : null;
  // The HTTP status callback can run while the test awaits pump. Read the
  // render tree directly: WidgetTester geometry helpers enter a test guard
  // and cannot overlap an outstanding pump.
  if (renderObject is RenderBox &&
      renderObject.attached &&
      renderObject.hasSize) {
    // Both corners must include FittedBox's scale in a small split window.
    final viewport = Rect.fromPoints(
      renderObject.localToGlobal(Offset.zero),
      renderObject.localToGlobal(renderObject.size.bottomRight(Offset.zero)),
    );
    final fit = applyBoxFit(
      BoxFit.contain,
      const Size(320, 180),
      viewport.size,
    );
    final picture = Alignment.center.inscribe(fit.destination, viewport);
    final ratio = tester.view.devicePixelRatio;
    final dx = (native['windowXPx'] as num?)?.toDouble() ?? 0;
    final dy = (native['windowYPx'] as num?)?.toDouble() ?? 0;
    content = {
      'left': picture.left * ratio + dx,
      'top': picture.top * ratio + dy,
      'right': picture.right * ratio + dx,
      'bottom': picture.bottom * ratio + dy,
      'ratio': ratio,
    };
  }
  return {
    'openCount': player.openCount,
    'positionMs': player.state.position.inMilliseconds,
    'playing': player.state.playing,
    'native': native,
    'videoContentPixels': content,
  };
}

class _NativeTransitionHandshake {
  _NativeTransitionHandshake._(this.server, this.snapshot);
  final HttpServer server;
  final Future<Map<String, Object?>> Function() snapshot;
  final initialCapture = Completer<Object?>();
  final transitions = Completer<Object?>();
  String phase = 'waiting-initial-capture';

  static Future<_NativeTransitionHandshake> start(
    Future<Map<String, Object?>> Function() snapshot,
  ) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 18757);
    final handshake = _NativeTransitionHandshake._(server, snapshot);
    server.listen(handshake._request);
    return handshake;
  }

  Future<void> _request(HttpRequest request) async {
    request.response.headers.contentType = ContentType.json;
    Completer<Object?>? completeAfterResponse;
    Object? payload;
    bool? pipRequested;
    if (request.method == 'POST' &&
        const {'/initial-captured', '/continue'}.contains(request.uri.path)) {
      try {
        payload = jsonDecode(await utf8.decoder.bind(request).join());
      } catch (_) {}
      if (request.uri.path == '/initial-captured') {
        phase = 'initial-capture-complete';
        completeAfterResponse = initialCapture;
      } else {
        phase = 'native-transitions-complete';
        completeAfterResponse = transitions;
      }
    } else if (request.method == 'POST' && request.uri.path == '/pip') {
      pipRequested =
          await _nativeChannel.invokeMethod<bool>('enterPip') ?? false;
    }
    request.response.write(
      jsonEncode({
        'phase': phase,
        'pipRequested': pipRequested,
        ...await snapshot(),
      }),
    );
    await request.response.close();
    if (completeAfterResponse != null && !completeAfterResponse.isCompleted) {
      completeAfterResponse.complete(payload);
    }
  }
}
