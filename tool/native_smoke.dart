// Native libmpv smoke test using original, locally generated PCM audio.
// This exercises the decoder and playback clock, not the Flutter GPU surface.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:media_kit/media_kit.dart';

Future<void> main(List<String> args) async {
  if (args.length != 1) {
    stderr.writeln('Usage: dart run tool/native_smoke.dart <libmpv-2.dll>');
    exitCode = 64;
    return;
  }
  final dll = File(args.first).absolute;
  if (!await dll.exists()) {
    throw StateError('Native library missing. Build Windows first.');
  }
  final fixture = File('.tools/nova-test.wav').absolute;
  const sampleRate = 16000;
  const pcmBytes = sampleRate * 15 * 2;
  final wav = Uint8List(44 + pcmBytes);
  final header = ByteData.sublistView(wav);
  wav.setRange(0, 4, ascii.encode('RIFF'));
  header.setUint32(4, 36 + pcmBytes, Endian.little);
  wav.setRange(8, 16, ascii.encode('WAVEfmt '));
  header.setUint32(16, 16, Endian.little);
  header.setUint16(20, 1, Endian.little);
  header.setUint16(22, 1, Endian.little);
  header.setUint32(24, sampleRate, Endian.little);
  header.setUint32(28, sampleRate * 2, Endian.little);
  header.setUint16(32, 2, Endian.little);
  header.setUint16(34, 16, Endian.little);
  wav.setRange(36, 40, ascii.encode('data'));
  header.setUint32(40, pcmBytes, Endian.little);
  await fixture.writeAsBytes(wav, flush: true);
  MediaKit.ensureInitialized(libmpv: dll.path);
  final player = Player(
    configuration: const PlayerConfiguration(
      vo: 'null',
      muted: true,
      title: 'NOVA native verification',
      logLevel: MPVLogLevel.error,
    ),
  );
  final errors = <String>[];
  final subscription = player.stream.error.listen(errors.add);
  final results = <String, Object?>{};
  try {
    await player
        .open(Media(fixture.path), play: false)
        .timeout(const Duration(seconds: 15));
    await player.play();
    await _until(() => player.state.duration.inSeconds >= 14, 'duration');
    await player.pause();
    await player.setVolume(35);
    await _until(() => (player.state.volume - 35).abs() < .1, 'volume');
    results['durationSeconds'] = player.state.duration.inSeconds;
    final native = player.platform;
    if (native is NativePlayer) {
      results['mpvVersion'] = await native.getProperty('mpv-version');
      results['ffmpegVersion'] = await native.getProperty('ffmpeg-version');
    }
    for (final rate in [.25, .5, .75, 1.0, 1.25, 1.5, 1.75, 2.0, 2.5, 3.0]) {
      await player.setRate(rate);
      await _until(() => (player.state.rate - rate).abs() < .01, 'rate $rate');
    }
    results['ratesAccepted'] = [.25, .5, .75, 1, 1.25, 1.5, 1.75, 2, 2.5, 3];
    final measurements = <String, double>{};
    for (final rate in [1.0, 2.0]) {
      await player.pause();
      await player.setRate(rate);
      await player.seek(const Duration(seconds: 1));
      await _until(
        () => (player.state.position.inMilliseconds - 1000).abs() < 300,
        'seek',
      );
      await player.play();
      await Future<void>.delayed(const Duration(milliseconds: 200));
      final start = player.state.position.inMilliseconds;
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      final advanced = (player.state.position.inMilliseconds - start) / 1000;
      await player.pause();
      measurements['${rate}x'] = advanced;
      if (advanced < rate * .65 || advanced > rate * 1.55) {
        throw StateError(
          'Playback clock did not follow $rate× ($advanced sec).',
        );
      }
    }
    results['elapsedMediaOver1_1Seconds'] = measurements;
    await player.pause();
    final pausedAt = player.state.position.inMilliseconds;
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if ((player.state.position.inMilliseconds - pausedAt).abs() > 200) {
      throw StateError('Pause did not stop the playback clock.');
    }
    if (errors.isNotEmpty) throw StateError('Native decoder emitted errors.');
    results['pauseAndSeek'] = 'passed';
    results['completedUtc'] = DateTime.now().toUtc().toIso8601String();
    await File('.tools/native-smoke-results.json')
        .writeAsString(const JsonEncoder.withIndent('  ').convert(results));
    stdout.writeln(
      'PASS native PCM decoder, 10 playback speeds, measured 1×/2× clock, volume, pause and seek.',
    );
    stdout.writeln(jsonEncode(measurements));
  } finally {
    await subscription.cancel();
    await player.dispose();
  }
}

Future<void> _until(bool Function() condition, String label) async {
  final watch = Stopwatch()..start();
  while (!condition()) {
    if (watch.elapsed > const Duration(seconds: 10)) {
      throw TimeoutException(label);
    }
    await Future<void>.delayed(const Duration(milliseconds: 40));
  }
}
