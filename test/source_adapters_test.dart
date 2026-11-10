import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nova_iptv/domain/models.dart';
import 'package:nova_iptv/domain/source_models.dart';
import 'package:nova_iptv/sources/iptv_client.dart';
import 'package:nova_iptv/sources/m3u_parser.dart';
import 'package:nova_iptv/sources/xmltv_parser.dart';

void main() {
  test(
    'M3U keeps quoted commas, relative URLs, stable IDs and XMLTV address',
    () {
      const config = SourceConfig(
        id: 'personal',
        name: 'Ma source',
        kind: SourceKind.m3uUrl,
        address: 'https://example.test/lists/catalog.m3u',
      );
      const playlist =
          '\ufeff#EXTM3U x-tvg-url="../guide.xml"\n'
          '#EXTINF:-1 tvg-id="channel.one" tvg-logo="../logos/info.png" group-title="Info, Monde",La chaîne, actualité\n'
          'live/info.ts?token=private-token\n'
          '#EXTINF:-1 tvg-type="movie" group-title="Cinéma",Un film\n'
          '../vod/film.mkv\n';
      final catalog = parseM3u(playlist, config, Uri.parse(config.address));
      expect(catalog.items.length, 2);
      final channel = catalog.items.first;
      expect(channel.title, 'La chaîne, actualité');
      expect(channel.category, 'Info, Monde');
      expect(channel.tvgId, 'channel.one');
      expect(
        channel.mediaUrl,
        'https://example.test/lists/live/info.ts?token=private-token',
      );
      expect(channel.posterUrl, 'https://example.test/logos/info.png');
      expect(channel.id, isNot(contains('private-token')));
      expect(channel.sourceId, 'personal');
      expect(catalog.items.last.kind, MediaKind.movie);
      expect(catalog.suggestedEpgUrl, 'https://example.test/guide.xml');
      expect(
        parseM3u(
          '$playlist\n#EXTINF:-1,Renommée\nlive/info.ts?token=private-token',
          config,
          Uri.parse(config.address),
        ).items.length,
        2,
      );
      expect(
        parseM3u(playlist, config, Uri.parse(config.address)).items.first.id,
        channel.id,
      );
    },
  );

  test(
    'M3U rejects HLS media manifests, HTML and remote local-file references',
    () {
      const config = SourceConfig(
        id: 's',
        name: 'S',
        kind: SourceKind.m3uUrl,
        address: 'https://example.test/a.m3u',
      );
      for (final text in [
        '#EXTM3U\n#EXT-X-TARGETDURATION:10\nsegment.ts',
        '#EXTM3U\n   #EXT-X-STREAM-INF:BANDWIDTH=2000000\nvariant.m3u8',
        '<!doctype html><html>login</html>',
        '#EXTM3U\n#EXTINF:-1,Private\nfile:///C:/private.mkv',
      ]) {
        expect(
          () => parseM3u(text, config, Uri.parse(config.address)),
          throwsA(isA<SourceException>()),
        );
      }
    },
  );

  test(
    'XMLTV honors offsets, French labels and channel display-name aliases',
    () {
      final programs = parseXmltv(_guide);
      expect(programs.length, 1);
      final program = programs.single;
      expect(program.title, 'Le journal');
      expect(program.channelAliases, ['Ma chaîne']);
      expect(program.start, DateTime.utc(2026, 11, 9, 12));
      expect(program.end, DateTime.utc(2026, 11, 9, 13));
      expect(program.isCurrentAt(DateTime.utc(2026, 11, 9, 12, 30)), isTrue);
      expect(program.progressAt(DateTime.utc(2026, 11, 9, 12, 30)), .5);
      expect(
        parseXmltvTime('20261109173000 +0530'),
        DateTime.utc(2026, 11, 9, 12),
      );
      expect(
        parseXmltvTime('20261109083000 -0330'),
        DateTime.utc(2026, 11, 9, 12),
      );
      expect(parseXmltvTime('20261109120000'), DateTime.utc(2026, 11, 9, 12));
      expect(parseXmltvTime('20260231120000 +0000'), isNull);
      expect(EpgProgramme.fromJson(program.toJson()).start, program.start);
    },
  );

  test(
    'Local M3U imports a relative local video without network access',
    () async {
      final folder = await Directory.systemTemp.createTemp('nova-m3u-test-');
      addTearDown(() => folder.delete(recursive: true));
      final file = File('${folder.path}/playlist.m3u');
      await file.writeAsString(
        '#EXTM3U\n#EXTINF:-1 group-title="Films",Mon fichier\nvideo.mp4\n',
      );
      final config = SourceConfig(
        id: 'local',
        name: 'Disque',
        kind: SourceKind.m3uFile,
        address: file.path,
      );
      final catalog = await IptvClient().loadCatalog(config);
      expect(
        catalog.items.single.mediaUrl,
        file.uri.resolve('video.mp4').toString(),
      );
      expect(catalog.items.single.kind, MediaKind.movie);
      final absolute = parseM3u(
        '#EXTM3U\n#EXTINF:-1,Windows file\nC:\\films\\video.mp4\n',
        config,
        file.uri,
      );
      expect(absolute.items.single.mediaUrl, 'file:///C:/films/video.mp4');
      final unc = parseM3u(
        '#EXTM3U\n#EXTINF:-1,Network file\n\\\\server\\films\\video.mp4\n',
        config,
        file.uri,
      );
      expect(unc.items.single.mediaUrl, 'file://server/films/video.mp4');
    },
  );

  test('Xtream imports live, VOD, series and lazy episodes with encoded credentials', () async {
    final requests = <Uri>[];
    final server = await _server((request) async {
      requests.add(request.uri);
      expect(
        request.uri.path,
        anyOf('/proxy/player_api.php', '/proxy/xmltv.php'),
      );
      expect(request.uri.queryParameters['username'], 'u/name');
      expect(request.uri.queryParameters['password'], 'p?space é');
      expect(request.uri.queryParameters['token'], 'server-token');
      if (request.uri.path.endsWith('xmltv.php')) return _text(request, _guide);
      final action = request.uri.queryParameters['action'];
      switch (action) {
        case null:
          return _json(request, {
            'user_info': {
              'auth': 1,
              'status': 'Active',
              'allowed_output_formats': ['ts'],
            },
          });
        case 'get_live_categories':
        case 'get_vod_categories':
        case 'get_series_categories':
          return _json(request, [
            {'category_id': '7', 'category_name': 'Ma catégorie'},
          ]);
        case 'get_live_streams':
          return _json(request, [
            {
              'stream_id': 12,
              'name': 'Ma chaîne',
              'category_id': '7',
              'epg_channel_id': 'one',
              'stream_icon': '/logo.png',
            },
          ]);
        case 'get_vod_streams':
          return _json(request, [
            {
              'stream_id': 13,
              'name': 'Mon film',
              'category_id': '7',
              'container_extension': 'mkv',
            },
          ]);
        case 'get_series':
          return _json(request, [
            {
              'series_id': 14,
              'name': 'Ma série',
              'category_id': '7',
              'cover': '/poster.jpg',
            },
          ]);
        case 'get_vod_info':
          expect(request.uri.queryParameters['vod_id'], '13');
          return _json(request, {
            'info': {
              'plot': 'Un vrai synopsis fournisseur.',
              'releasedate': '2024-06-07',
              'duration_secs': 5400,
            },
            'movie_data': {'container_extension': 'mkv'},
          });
        case 'get_series_info':
          expect(request.uri.queryParameters['series_id'], '14');
          return _json(request, {
            'info': {'plot': 'Synopsis série'},
            'episodes': {
              '2': [
                {
                  'id': '142',
                  'episode_num': 2,
                  'title': 'Deuxième',
                  'container_extension': 'mp4',
                  'info': {'duration_secs': 1800},
                },
                {
                  'id': '141',
                  'episode_num': 1,
                  'title': 'Premier',
                  'container_extension': 'mkv',
                  'info': {'duration_secs': 1500},
                },
              ],
            },
          });
        default:
          throw StateError('Unexpected fixture action');
      }
    });
    addTearDown(() => server.close(force: true));
    final config = SourceConfig(
      id: 'account',
      name: 'Fournisseur',
      kind: SourceKind.xtream,
      address:
          'http://${server.address.host}:${server.port}/proxy/player_api.php?token=server-token&username=obsolete&password=obsolete',
      username: 'u/name',
      password: 'p?space é',
    );
    final client = IptvClient();
    expect(await client.testConnection(config.draft), contains('réussie'));
    final catalog = await client.loadCatalog(config);
    expect(catalog.items.length, 3);
    expect(catalog.warnings, isEmpty);
    final channel = catalog.items.firstWhere(
      (item) => item.kind == MediaKind.live,
    );
    expect(channel.id, 'account:live:12');
    expect(channel.category, 'Ma catégorie');
    final liveUri = Uri.parse(channel.mediaUrl!);
    expect(liveUri.pathSegments, [
      'proxy',
      'live',
      'u/name',
      'p?space é',
      '12.ts',
    ]);
    expect(liveUri.queryParameters, {'token': 'server-token'});
    final movie = await client.loadDetails(
      config,
      catalog.items.firstWhere((item) => item.kind == MediaKind.movie),
    );
    expect(movie.detailsLoaded, isTrue);
    expect(movie.year, 2024);
    expect(movie.durationMinutes, 90);
    expect(Uri.parse(movie.mediaUrl!).pathSegments.last, '13.mkv');
    final series = await client.loadDetails(
      config,
      catalog.items.firstWhere((item) => item.kind == MediaKind.series),
    );
    expect(series.detailsLoaded, isTrue);
    expect(series.seasons.single.number, 2);
    expect(series.seasons.single.episodes.map((e) => e.title), [
      'Premier',
      'Deuxième',
    ]);
    expect(series.seasons.single.episodes.first.id, 'account:episode:141');
    expect(
      Uri.parse(series.seasons.single.episodes.first.mediaUrl!).pathSegments,
      ['proxy', 'series', 'u/name', 'p?space é', '141.mkv'],
    );
    expect((await client.loadEpg(config)).single.channelId, 'one');
    expect(
      requests.any((uri) => uri.queryParameters['username'] == 'obsolete'),
      isFalse,
    );
  });

  test(
    'Unavailable optional Xtream catalog does not discard successful sections',
    () async {
      final server = await _server((request) async {
        switch (request.uri.queryParameters['action']) {
          case null:
            return _json(request, {
              'user_info': {'auth': '1', 'status': 'Active'},
            });
          case 'get_live_categories':
            request.response.statusCode = 404;
            return _text(request, 'Unsupported categories');
          case 'get_live_streams':
            return _json(request, [
              {'stream_id': '1', 'name': 'Live'},
            ]);
          case 'get_vod_streams':
            request.response.statusCode = 404;
            return _text(request, 'Unsupported VOD');
          default:
            return _json(request, []);
        }
      });
      addTearDown(() => server.close(force: true));
      final config = _account(server);
      final catalog = await IptvClient().loadCatalog(config);
      expect(catalog.items.single.kind, MediaKind.live);
      expect(catalog.items.single.category, 'Sans catégorie');
      expect(catalog.warnings.single, contains('films'));
      expect(catalog.failedKinds, {MediaKind.movie});
    },
  );

  test('Invalid auth and HTTP errors never include secrets in diagnostics', () async {
    final server = await _server((request) async {
      if (request.uri.path == '/denied') {
        request.response.statusCode = 403;
        return _text(request, 'private-password');
      }
      return _json(request, {
        'user_info': {'auth': 0, 'status': 'Disabled'},
        'secret': 'private-password',
      });
    });
    addTearDown(() => server.close(force: true));
    final client = IptvClient();
    for (final draft in [
      _account(server).draft,
      SourceDraft(
        name: 'URL',
        kind: SourceKind.m3uUrl,
        address:
            'http://${server.address.host}:${server.port}/denied?password=private-password',
      ),
    ]) {
      try {
        await client.testConnection(draft);
        fail('Expected source error');
      } on SourceException catch (error) {
        expect(error.message, isNot(contains('private-password')));
        expect(error.toString(), isNot(contains('http://')));
      }
    }
  });

  test('Requests time out and cancellation stops an in-flight response', () async {
    final received = StreamController<void>.broadcast();
    addTearDown(received.close);
    final server = await _server((request) async {
      received.add(null);
    });
    addTearDown(() => server.close(force: true));
    final config = SourceConfig(
      id: 'slow',
      name: 'Slow',
      kind: SourceKind.m3uUrl,
      address:
          'http://${server.address.host}:${server.port}/wait?secret=private-password',
    );
    await expectLater(
      IptvClient(timeout: const Duration(milliseconds: 80)).loadCatalog(config),
      throwsA(
        isA<SourceException>().having(
          (error) => error.message,
          'message',
          contains('temps'),
        ),
      ),
    );
    final token = CancellationToken();
    final seen = received.stream.first;
    final operation = IptvClient().loadCatalog(config, cancel: token);
    final expectation = expectLater(operation, throwsA(isA<SourceCancelled>()));
    await seen;
    token.cancel();
    await expectation;
  });

  test(
    'Oversize responses are rejected and gzipped XMLTV can be imported',
    () async {
      final server = await _server((request) async {
        if (request.uri.path == '/guide.xml.gz') {
          request.response.add(gzip.encode(utf8.encode(_guide)));
          return request.response.close();
        }
        return _text(request, '#' * 2048);
      });
      addTearDown(() => server.close(force: true));
      final root = 'http://${server.address.host}:${server.port}';
      final draft = SourceConfig(
        id: 'big',
        name: 'Big',
        kind: SourceKind.m3uUrl,
        address: '$root/large',
      );
      await expectLater(
        IptvClient(maxResponseBytes: 100).loadCatalog(draft),
        throwsA(
          isA<SourceException>().having(
            (error) => error.message,
            'message',
            contains('taille'),
          ),
        ),
      );
      final programs = await IptvClient().loadEpg(
        draft.copyWith(epgUrl: '$root/guide.xml.gz'),
      );
      expect(programs.single.title, 'Le journal');
    },
  );
}

const _guide =
    '<?xml version="1.0" encoding="UTF-8"?>'
    '<tv><channel id="one"><display-name>Ma chaîne</display-name></channel>'
    '<programme start="20261109130000 +0100" stop="20261109140000 +0100" channel="one">'
    '<title lang="en">News</title><title lang="fr">Le journal</title><desc>Informations</desc></programme>'
    '<programme start="bad" stop="bad" channel="one"><title>Invalid</title></programme></tv>';

SourceConfig _account(HttpServer server) => SourceConfig(
  id: 'account',
  name: 'Fixture',
  kind: SourceKind.xtream,
  address: 'http://${server.address.host}:${server.port}',
  username: 'user',
  password: 'private-password',
);

Future<HttpServer> _server(Future<void> Function(HttpRequest) handler) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((request) async {
    try {
      await handler(request);
    } catch (_) {
      request.response.statusCode = 500;
      await request.response.close();
    }
  });
  return server;
}

Future<void> _json(HttpRequest request, Object body) async {
  request.response.headers.contentType = ContentType.json;
  request.response.write(jsonEncode(body));
  await request.response.close();
}

Future<void> _text(HttpRequest request, String body) async {
  request.response.headers.contentType = ContentType.text;
  request.response.write(body);
  await request.response.close();
}
