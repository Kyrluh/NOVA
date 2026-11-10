// Real libmpv + loopback HTTP checks for nonfatal diagnostic recovery.
// The recoverable diagnostic is injected into media_kit's error stream; this
// does not induce a real codec fault or validate the Flutter GPU surface.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:nova_iptv/player/playback_health.dart';

void main() {
  test(
    'Native playback survives diagnostics, fails on 404 and recovers',
    () async {
      final library = File('build/windows/x64/runner/Release/libmpv-2.dll')
          .absolute;
      expect(
        await library.exists(),
        isTrue,
        reason: 'Build Windows Release first.',
      );
      MediaKit.ensureInitialized(libmpv: library.path);
      final player = Player(
        configuration: const PlayerConfiguration(
          vo: 'null',
          muted: true,
          title: 'NOVA live-error verification',
        ),
      );
      final health = PlaybackHealth(
        diagnosticGrace: const Duration(seconds: 1),
        startupTimeout: const Duration(seconds: 3),
      );
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final endpoint = 'http://${server.address.host}:${server.port}';
      final pcm = _silentWav();
      var mediaRequests = 0;
      var missingRequests = 0;
      var diagnostics = 0;
      var generation = 0;
      var activeGeneration = -1;
      var acceptEvents = false;
      String? activeUri;
      StreamSubscription<String>? errors;
      StreamSubscription<Duration>? positions;
      final requests = server.listen((request) async {
        try {
          if (request.uri.path == '/valid.wav') {
            mediaRequests++;
            await _media(request, pcm);
          } else {
            missingRequests++;
            request.response.statusCode = HttpStatus.notFound;
            await request.response.close();
          }
        } on HttpException {
          // A client may cancel an in-flight response while changing media.
        } on SocketException {
          // The test intentionally stops the player between sessions.
        }
      });

      bool current(int session) =>
          acceptEvents &&
          activeGeneration == session &&
          generation == session &&
          player.state.playlist.medias.any((m) => m.uri == activeUri);

      Future<void> load(String address, {bool resetHealth = true}) async {
        acceptEvents = false;
        activeGeneration = -1;
        generation++;
        await errors?.cancel();
        await positions?.cancel();
        await player.stop();
        // Drain stop/reset events before attaching this generation's listeners.
        await Future<void>.delayed(const Duration(milliseconds: 35));
        final session = generation;
        if (resetHealth) health.begin();
        final media = Media(address); // No forced start/seek on a live source.
        activeUri = media.uri;
        errors = player.stream.error.listen((_) {
          if (!current(session)) return;
          diagnostics++;
          health.diagnostic();
        });
        positions = player.stream.position.listen((position) {
          if (!current(session)) return;
          health.advance(position, playing: player.state.playing);
        });
        activeGeneration = session;
        acceptEvents = true;
        await player.open(media);
      }

      final results = <String, Object?>{};
      try {
        await load('$endpoint/valid.wav');
        await _until(
          () =>
              health.hasProgress && player.state.position.inMilliseconds > 150,
          'initial native playback',
        );
        final beforeDiagnostic = player.state.position.inMilliseconds;
        final diagnosticCount = diagnostics;
        // Fixture-only injection through the same public stream the widget uses.
        // ignore: invalid_use_of_protected_member
        player.platform!.errorController.add('Recoverable decoder fixture');
        await _until(
          () => diagnostics > diagnosticCount,
          'diagnostic stream delivery',
        );
        var blockedDuringPlayback = false;
        final graceWatch = Stopwatch()..start();
        while (graceWatch.elapsed < const Duration(milliseconds: 1350)) {
          blockedDuringPlayback = blockedDuringPlayback || health.failed;
          await Future<void>.delayed(const Duration(milliseconds: 25));
        }
        final advancedAfterDiagnostic =
            player.state.position.inMilliseconds - beforeDiagnostic;
        expect(advancedAfterDiagnostic, greaterThan(750));
        expect(blockedDuringPlayback, isFalse);
        expect(health.failed, isFalse);
        results['recoverableDiagnosticInjectedThroughPlayerStream'] = true;
        results['diagnosticGraceMilliseconds'] = 1000;
        results['observationMilliseconds'] = graceWatch.elapsedMilliseconds;
        results['mediaProgressAfterDiagnosticMilliseconds'] =
            advancedAfterDiagnostic;
        results['blockedDuringContinuedPlayback'] = blockedDuringPlayback;

        final beforeMissingDiagnostics = diagnostics;
        final failureWatch = Stopwatch()..start();
        await load('$endpoint/missing.wav');
        await _until(
          () => missingRequests > 0 && diagnostics > beforeMissingDiagnostics,
          'actual HTTP 404 diagnostic',
        );
        await _until(
          () => health.failed,
          'unreadable source failure',
          timeout: const Duration(milliseconds: 3500),
        );
        expect(
          health.hasProgress,
          isFalse,
          reason: 'Old-source progress must not satisfy the new generation.',
        );
        expect(failureWatch.elapsedMilliseconds, lessThan(3600));
        results['actualHttp404Observed'] = true;
        results['unreadableSourceFailureMilliseconds'] =
            failureWatch.elapsedMilliseconds;

        // Keep the same failed health session: progress itself must clear failure.
        await load('$endpoint/valid.wav', resetHealth: false);
        await _until(
          () =>
              health.hasProgress &&
              !health.failed &&
              player.state.position.inMilliseconds > 150,
          'recovery without health.begin',
        );
        expect(mediaRequests, greaterThanOrEqualTo(2));
        results['recoveryWithoutBegin'] = true;
        results['recoveredNativePositionMilliseconds'] =
            player.state.position.inMilliseconds;
        results['completedUtc'] = DateTime.now().toUtc().toIso8601String();
        results['fixture'] = 'Original silent PCM over loopback HTTP; injected recoverable diagnostic and real HTTP 404. No provider account or GPU test.';
        await File('.tools/live-error-smoke-results.json')
            .writeAsString(const JsonEncoder.withIndent('  ').convert(results));
      } finally {
        acceptEvents = false;
        activeGeneration = -1;
        generation++;
        await errors?.cancel();
        await positions?.cancel();
        health.dispose();
        await player.dispose();
        await requests.cancel();
        await server.close(force: true);
      }
    },
    timeout: const Timeout(Duration(seconds: 15)),
    skip: Platform.isWindows
        ? false
        : 'Requires Windows and the libmpv Release library.',
  );
}

Future<void> _until(
  bool Function() condition,
  String label, {
  Duration timeout = const Duration(seconds: 3),
}) async {
  final watch = Stopwatch()..start();
  while (!condition()) {
    if (watch.elapsed > timeout) throw TimeoutException(label);
    await Future<void>.delayed(const Duration(milliseconds: 25));
  }
}

Uint8List _silentWav() {
  const rate = 16000;
  const dataBytes = rate * 20 * 2;
  final wav = Uint8List(44 + dataBytes);
  final header = ByteData.sublistView(wav);
  wav.setRange(0, 4, ascii.encode('RIFF'));
  header.setUint32(4, 36 + dataBytes, Endian.little);
  wav.setRange(8, 16, ascii.encode('WAVEfmt '));
  header.setUint32(16, 16, Endian.little);
  header.setUint16(20, 1, Endian.little);
  header.setUint16(22, 1, Endian.little);
  header.setUint32(24, rate, Endian.little);
  header.setUint32(28, rate * 2, Endian.little);
  header.setUint16(32, 2, Endian.little);
  header.setUint16(34, 16, Endian.little);
  wav.setRange(36, 40, ascii.encode('data'));
  header.setUint32(40, dataBytes, Endian.little);
  return wav;
}

Future<void> _media(HttpRequest request, Uint8List bytes) async {
  request.response.headers.contentType = ContentType('audio', 'wav');
  request.response.headers.set('accept-ranges', 'bytes');
  var start = 0;
  var end = bytes.length - 1;
  final range = request.headers.value('range');
  if (range != null) {
    final match = RegExp(r'^bytes=(\d+)-(\d*)$').firstMatch(range);
    if (match != null) {
      start = int.parse(match[1]!);
      if (match[2]!.isNotEmpty) end = int.parse(match[2]!).clamp(0, end);
      if (start > end || start >= bytes.length) {
        request.response.statusCode = HttpStatus.requestedRangeNotSatisfiable;
        request.response.headers.set(
          'content-range',
          'bytes */${bytes.length}',
        );
        await request.response.close();
        return;
      }
      request.response.statusCode = HttpStatus.partialContent;
      request.response.headers.set(
        'content-range',
        'bytes $start-$end/${bytes.length}',
      );
    }
  }
  request.response.contentLength = end - start + 1;
  request.response.add(Uint8List.sublistView(bytes, start, end + 1));
  await request.response.close();
}
