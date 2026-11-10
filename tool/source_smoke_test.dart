// Native Windows integration: generated HTTP fixtures -> DPAPI/SQLite -> libmpv
// -> offline restart. This validates PCM playback, not GPU video rendering.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:nova_iptv/data/local_store.dart';
import 'package:nova_iptv/data/secret_store.dart';
import 'package:nova_iptv/data/source_repository.dart';
import 'package:nova_iptv/domain/models.dart';
import 'package:nova_iptv/domain/source_models.dart';
import 'package:nova_iptv/sources/iptv_client.dart';
import 'package:nova_iptv/state/app_controller.dart';
import 'package:nova_iptv/state/source_controller.dart';

void main() {
  test(
    'Real source import, protected cache, HTTP playback and offline restart',
    () async {
      final library = File('build/windows/x64/runner/Release/libmpv-2.dll')
          .absolute;
      expect(
        await library.exists(),
        isTrue,
        reason: 'A Windows Release build is required.',
      );
      final folder = Directory(
        '.tools/source-smoke-${DateTime.now().microsecondsSinceEpoch}',
      ).absolute;
      await folder.create(recursive: true);
      final database = '${folder.path}/catalogue.sqlite';
      final preferences = '${folder.path}/preferences.json';
      final now = DateTime.now().toUtc();
      final minute = DateTime.utc(
        now.year,
        now.month,
        now.day,
        now.hour,
        now.minute,
      );
      final start = minute.subtract(const Duration(minutes: 30));
      final end = minute.add(const Duration(minutes: 30));
      final pcm = _silentWav();
      var requestCount = 0;
      var episodeRequests = 0;
      var invalidAuth = false;
      HttpServer? server;
      AppController? app;
      SourceController? sources;
      Player? player;
      StreamSubscription<String>? errorsSubscription;
      final nativeErrors = <String>[];
      final results = <String, Object?>{};
      try {
        server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        final endpoint = 'http://${server.address.host}:${server.port}';
        final guide =
            '<tv><channel id="fixture.one"><display-name>Fixture live</display-name></channel>'
            '<programme channel="fixture.one" start="${_xmltv(start)}" stop="${_xmltv(end)}"><title>Programme actuel fictif</title></programme>'
            '<programme channel="fixture.one" start="${_xmltv(end)}" stop="${_xmltv(end.add(const Duration(hours: 1)))}"><title>Programme suivant fictif</title></programme></tv>';
        server.listen((request) async {
          requestCount++;
          if (request.uri.path == '/playlist.m3u') {
            return _reply(
              request,
              '#EXTM3U x-tvg-url="$endpoint/guide.xml"\n'
                  '#EXTINF:-1 tvg-id="fixture.one" group-title="Fixture",Fixture live\n'
                  '$endpoint/media.wav?token=m3u-synthetic\n',
              'application/x-mpegurl',
            );
          }
          if (request.uri.path == '/guide.xml' ||
              request.uri.path == '/xmltv.php') {
            return _reply(request, guide, 'application/xml');
          }
          if (request.uri.path == '/media.wav') return _media(request, pcm);
          if (request.uri.pathSegments.length == 4 &&
              request.uri.pathSegments.first == 'series') {
            final path = request.uri.pathSegments;
            if (path[1] != 'sample-user' ||
                path[2] != 'sample-secret' ||
                path[3] != '51.mp4') {
              invalidAuth = true;
              request.response.statusCode = 403;
              return request.response.close();
            }
            episodeRequests++;
            return _media(request, pcm);
          }
          if (request.uri.path == '/player_api.php') {
            final query = request.uri.queryParameters;
            if (query['username'] != 'sample-user' ||
                query['password'] != 'sample-secret') {
              invalidAuth = true;
              request.response.statusCode = 403;
              return request.response.close();
            }
            Object response;
            switch (query['action']) {
              case null:
                response = {
                  'user_info': {
                    'auth': 1,
                    'status': 'Active',
                    'allowed_output_formats': ['ts'],
                  },
                };
              case 'get_live_categories':
              case 'get_vod_categories':
              case 'get_series_categories':
                response = [
                  {'category_id': '1', 'category_name': 'Fixture'},
                ];
              case 'get_live_streams':
                response = [
                  {
                    'stream_id': 11,
                    'name': 'Fixture live',
                    'category_id': '1',
                    'epg_channel_id': 'fixture.one',
                  },
                ];
              case 'get_vod_streams':
                response = [
                  {
                    'stream_id': 21,
                    'name': 'Fixture film',
                    'category_id': '1',
                    'container_extension': 'mp4',
                  },
                ];
              case 'get_series':
                response = [
                  {
                    'series_id': 31,
                    'name': 'Fixture series',
                    'category_id': '1',
                  },
                ];
              case 'get_vod_info':
                response = {
                  'info': {
                    'plot': 'Metadata generated by this test.',
                    'duration_secs': 15,
                  },
                  'movie_data': {'container_extension': 'mp4'},
                };
              case 'get_series_info':
                response = {
                  'info': {'plot': 'Metadata generated by this test.'},
                  'episodes': {
                    '1': [
                      {
                        'id': 51,
                        'episode_num': 1,
                        'title': 'Fixture episode',
                        'container_extension': 'mp4',
                        'info': {'duration_secs': 15},
                      },
                    ],
                  },
                };
              default:
                request.response.statusCode = 404;
                return request.response.close();
            }
            return _reply(request, jsonEncode(response), 'application/json');
          }
          request.response.statusCode = 404;
          await request.response.close();
        });
        sources = SourceController(
          repository: SQLiteSourceRepository(
            path: database,
            secrets: const DpapiSecretStore(),
          ),
          client: IptvClient(timeout: const Duration(seconds: 4)),
        );
        app = AppController(
          store: FileLocalStore(preferences),
          sources: sources,
        );
        await app.init();
        await sources.add(
          SourceDraft(
            name: 'Fixture M3U',
            kind: SourceKind.m3uUrl,
            address: '$endpoint/playlist.m3u?token=m3u-synthetic',
          ),
        );
        await sources.add(
          SourceDraft(
            name: 'Fixture Xtream',
            kind: SourceKind.xtream,
            address: endpoint,
            username: 'sample-user',
            password: 'sample-secret',
          ),
        );
        expect(app.isDemo, isFalse);
        expect(sources.sources.length, 2);
        expect(app.items.length, 4);
        expect(sources.error, isNull);
        final m3uSource = sources.sources.firstWhere(
          (source) => source.kind == SourceKind.m3uUrl,
        );
        final xtreamSource = sources.sources.firstWhere(
          (source) => source.kind == SourceKind.xtream,
        );
        expect(sources.draftFor(m3uSource.id)!.epgUrl.isNotEmpty, isTrue);
        await sources.refreshEpg(m3uSource.id);
        await sources.refreshEpg(xtreamSource.id);
        final channel = app.items.firstWhere(
          (item) =>
              item.sourceId == xtreamSource.id && item.kind == MediaKind.live,
        );
        final programmes = app.guideFor(channel);
        expect(
          programmes.length,
          2,
          reason: 'Guides must remain isolated per source.',
        );
        expect(programmes.first.isCurrentAt(now), isTrue);
        expect(programmes.last.start.isAfter(now), isTrue);
        final film = await app.loadDetails(
          app.items.firstWhere((item) => item.kind == MediaKind.movie),
        );
        expect(film.detailsLoaded, isTrue);
        final series = await app.loadDetails(
          app.items.firstWhere((item) => item.kind == MediaKind.series),
        );
        expect(series.seasons.single.episodes.length, 1);
        final episode = series.seasons.single.episodes.single;
        expect(episode.mediaUrl, isNotNull);
        MediaKit.ensureInitialized(libmpv: library.path);
        player = Player(
          configuration: const PlayerConfiguration(
            vo: 'null',
            muted: true,
            title: 'NOVA source smoke test',
          ),
        );
        errorsSubscription = player.stream.error.listen(nativeErrors.add);
        await player
            .open(Media(episode.mediaUrl!), play: false)
            .timeout(const Duration(seconds: 5));
        await player.setRate(1.5);
        await player.play();
        await _until(
          () =>
              player!.state.duration.inSeconds == 15 &&
              player.state.position.inMilliseconds >= 400,
        );
        await player.pause();
        expect(player.state.rate, 1.5);
        expect(episodeRequests > 0, isTrue);
        expect(invalidAuth, isFalse);
        expect(
          nativeErrors.isEmpty,
          isTrue,
          reason: 'Native playback must not emit errors.',
        );
        results['nativeDurationSeconds'] = player.state.duration.inSeconds;
        results['nativeRate'] = player.state.rate;
        results['nativeProgressMilliseconds'] =
            player.state.position.inMilliseconds;
        await errorsSubscription.cancel();
        errorsSubscription = null;
        await player.dispose();
        player = null;
        app.toggleFavorite(film.id);
        app.recordProgress(
          episode.id,
          WatchProgress(
            positionSeconds: 2,
            durationSeconds: 15,
            lastWatched: now,
          ),
        );
        app.updateSettings(app.settings.copyWith(playbackRate: 1.5));
        await app.shutdown();
        app.dispose();
        app = null;
        sources.dispose();
        sources = null;
        await server.close(force: true);
        server = null;
        final onlineRequestCount = requestCount;
        sources = SourceController(
          repository: SQLiteSourceRepository(
            path: database,
            secrets: const DpapiSecretStore(),
          ),
          client: IptvClient(
            clientFactory: () =>
                throw StateError('Offline restart attempted network.'),
          ),
        );
        app = AppController(
          store: FileLocalStore(preferences),
          sources: sources,
        );
        await app.init();
        expect(sources.error, isNull);
        expect(sources.warnings, isEmpty);
        expect(app.isDemo, isFalse);
        expect(app.items.length, 4);
        expect(app.favorites.contains(film.id), isTrue);
        expect(app.progress[episode.id]!.positionSeconds, 2);
        expect(app.settings.playbackRate, 1.5);
        expect(
          app.itemById(series.id)!.seasons.single.episodes.single.id,
          episode.id,
        );
        expect(app.guideFor(app.itemById(channel.id)!).length, 2);
        expect(requestCount, onlineRequestCount);
        await app.shutdown();
        app.dispose();
        app = null;
        sources.dispose();
        sources = null;
        for (final suffix in ['', '-journal', '-wal', '-shm']) {
          final file = File('$database$suffix');
          if (!await file.exists()) continue;
          expect(
            latin1.decode(await file.readAsBytes()).contains('sample-secret'),
            isFalse,
            reason: 'Synthetic credentials must not occur in SQLite plaintext.',
          );
        }
        expect(
          (await File(preferences).readAsString()).contains('sample-secret'),
          isFalse,
        );
        results.addAll({
          'sourcesImported': 2,
          'catalogueItemsRestored': 4,
          'guideProgrammesPerSource': 2,
          'httpEpisodePlayback': true,
          'offlineRestart': true,
          'favoritesAndProgressRestored': true,
          'dpapiProtectedSqlite': true,
          'completedUtc': DateTime.now().toUtc().toIso8601String(),
          'fixture': 'Original silent PCM served by a loopback-only HTTP server; no provider account used.',
        });
        await File('.tools/source-smoke-results.json')
            .writeAsString(const JsonEncoder.withIndent('  ').convert(results));
      } finally {
        await errorsSubscription?.cancel();
        await player?.dispose();
        if (app != null) {
          await app.shutdown();
          app.dispose();
        }
        if (sources != null) {
          await sources.close();
          sources.dispose();
        }
        await server?.close(force: true);
      }
    },
    timeout: const Timeout(Duration(seconds: 20)),
    skip: Platform.isWindows ? false : 'Requires Windows DPAPI and libmpv.',
  );
}

Future<void> _reply(HttpRequest request, String body, String type) async {
  request.response.headers.contentType = ContentType.parse(
    '$type; charset=utf-8',
  );
  request.response.write(body);
  await request.response.close();
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

String _xmltv(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}'
    '${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}'
    '${date.hour.toString().padLeft(2, '0')}${date.minute.toString().padLeft(2, '0')}'
    '${date.second.toString().padLeft(2, '0')} +0000';

Future<void> _until(bool Function() ready) async {
  final timer = Stopwatch()..start();
  while (!ready()) {
    if (timer.elapsed > const Duration(seconds: 5)) {
      throw TimeoutException('Native HTTP media did not become ready.');
    }
    await Future<void>.delayed(const Duration(milliseconds: 40));
  }
}

Uint8List _silentWav() {
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
  return wav;
}
