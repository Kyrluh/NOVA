import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';

import '../integration_test/support/compressed_fixtures.dart';

void main() {
  test(
    'Investigate original local HLS with desktop libmpv, without Android build',
    () async {
      MediaKit.ensureInitialized(
        libmpv: File('dist/NOVA-IPTV-0.5.0-windows-x64/libmpv-2.dll')
            .absolute
            .path,
      );
      final ts = transportStreamFixture();
      final requests = <String>[];
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        requests.add(request.uri.path);
        if (request.uri.path.endsWith('.m3u8')) {
          final bytes = utf8.encode(
            '#EXTM3U\n#EXT-X-VERSION:3\n#EXT-X-PLAYLIST-TYPE:VOD\n#EXT-X-TARGETDURATION:13\n#EXT-X-MEDIA-SEQUENCE:0\n#EXTINF:12.0,\nhttp://127.0.0.1:${server.port}/original.ts\n#EXT-X-ENDLIST\n',
          );
          request.response.headers.contentType = ContentType(
            'application',
            'vnd.apple.mpegurl',
          );
          request.response.contentLength = bytes.length;
          request.response.add(bytes);
        } else {
          request.response.headers.contentType = ContentType('video', 'mp2t');
          request.response.headers.set('accept-ranges', 'bytes');
          final range = RegExp(r'^bytes=(\d+)-(\d*)$')
              .firstMatch(request.headers.value('range') ?? '');
          final start = range == null ? 0 : int.parse(range[1]!);
          final end = range == null || range[2]!.isEmpty
              ? ts.length - 1
              : int.parse(range[2]!);
          if (range != null) {
            request.response.statusCode = 206;
            request.response.headers.set(
              'content-range',
              'bytes $start-$end/${ts.length}',
            );
          }
          request.response.contentLength = end - start + 1;
          request.response.add(ts.sublist(start, end + 1));
        }
        await request.response.close();
      });
      final results = <Map<String, Object?>>[];
      Player create() => Player(
        configuration: const PlayerConfiguration(
          vo: 'null',
          muted: true,
          logLevel: MPVLogLevel.debug,
        ),
      );
      Future<void> probe(Player player, String name, String file) async {
        final logs = <String>[];
        final listener = player.stream.log.listen((entry) {
          if (logs.length >= 150) logs.removeAt(0);
          logs.add(
            '${entry.prefix}:${entry.level}:${entry.text}'.replaceAll(
              RegExp(r'https?://\S+'),
              '<fixture-http>',
            ),
          );
        });
        try {
          await player.setVideoTrack(VideoTrack.auto());
          await player.open(Media('http://127.0.0.1:${server.port}/$file'));
          final watch = Stopwatch()..start();
          while (player.state.position.inMilliseconds < 350 &&
              watch.elapsed.inSeconds < 12) {
            await Future<void>.delayed(const Duration(milliseconds: 100));
          }
          final native = player.platform! as NativePlayer;
          results.add({
            'case': name,
            'positionMs': player.state.position.inMilliseconds,
            'width': player.state.width,
            'height': player.state.height,
            'playing': player.state.playing,
            'format': await native.getProperty('file-format'),
            'codec': await native.getProperty('video-codec'),
            'logs': logs,
          });
          // ignore: avoid_print
          print('NOVA_HOST_HLS_CASE=${jsonEncode(results.last)}');
          await player.stop();
        } finally {
          await listener.cancel();
        }
      }

      try {
        final fresh = create();
        try {
          await probe(fresh, 'fresh-hls', 'original.m3u8');
        } finally {
          await fresh.dispose();
        }
        final reused = create();
        try {
          await probe(reused, 'reused-ts', 'original.ts');
          await probe(reused, 'reused-hls', 'original.m3u8');
        } finally {
          await reused.dispose();
        }
        final forced = create();
        try {
          await (forced.platform! as NativePlayer).setProperty(
            'demuxer-lavf-format',
            'hls',
          );
          await probe(forced, 'forced-lavf-hls', 'original.m3u8');
        } finally {
          await forced.dispose();
        }
      } finally {
        await server.close(force: true);
      }
      await File('.tools/desktop-hls-probe-report.json').writeAsString(
        const JsonEncoder.withIndent('  ')
            .convert({'results': results, 'requests': requests}),
      );
    },
    timeout: const Timeout(Duration(seconds: 90)),
    skip: !Platform.isWindows,
  );
}
