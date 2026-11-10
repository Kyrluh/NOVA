import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nova_iptv/data/local_store.dart';
import 'package:nova_iptv/data/source_repository.dart';
import 'package:nova_iptv/domain/models.dart';
import 'package:nova_iptv/domain/source_models.dart';
import 'package:nova_iptv/sources/iptv_client.dart';
import 'package:nova_iptv/state/app_controller.dart';
import 'package:nova_iptv/state/source_controller.dart';
import 'package:nova_iptv/ui/widgets/source_startup_progress.dart';

MediaItem _item(String source, String title) => MediaItem(
  id: '$source:film',
  title: title,
  kind: MediaKind.movie,
  category: 'Films',
  description: '',
  year: 2026,
  durationMinutes: 90,
  palette: 0,
  subtitle: '',
  art: 0,
  sourceId: source,
  mediaUrl: 'https://example.test/video.mp4',
);
SourceRecord _record(String id) => SourceRecord(
  config: SourceConfig(
    id: id,
    name: 'Source $id',
    kind: SourceKind.m3uUrl,
    address: 'https://example.test/$id.m3u',
  ),
  catalog: SourceCatalog(items: [_item(id, 'Cache $id')]),
  programmes: const [],
  updatedAt: DateTime.utc(2026),
);
SourceController _sources(
  IptvClient client, {
  List<String> ids = const ['a'],
}) => SourceController(
  repository: MemorySourceRepository(ids.map(_record).toList()),
  client: client,
);

void main() {
  test('App opens cache first, refreshes automatically once and preserves favorite and progress', () async {
    final client = _Client()..gate = Completer<SourceCatalog>();
    final sources = _sources(client);
    addTearDown(sources.close);
    final app = AppController(
      store: MemoryLocalStore({
        'favorites': ['a:film'],
        'progress': {
          'a:film': WatchProgress(
            positionSeconds: 30,
            durationSeconds: 600,
            lastWatched: DateTime.utc(2026),
          ).toJson(),
        },
      }),
      sources: sources,
      refreshSourcesOnStartup: true,
    );
    addTearDown(app.dispose);
    await app.init();
    await Future<void>.delayed(Duration.zero);
    expect(app.isReady, isTrue);
    expect(app.items.single.title, 'Cache a');
    expect(sources.startupRefreshing, isTrue);
    final job = sources.refreshAtStartup();
    expect(identical(job, sources.refreshAtStartup()), isTrue);
    client.catalogProgress.value = const CatalogLoadProgress(
      'a',
      .5,
      'Téléchargement de la playlist',
    );
    expect(sources.startupProgress, .5);
    client.gate!.complete(SourceCatalog(items: [_item('a', 'Nouveau film')]));
    await job;
    expect(client.calls, ['a']);
    expect(app.items.single.title, 'Nouveau film');
    expect(app.favorites, contains('a:film'));
    expect(app.progress['a:film']!.positionSeconds, 30);
    expect(sources.startupProgress, 1);
    expect(sources.startupFinished, isTrue);
  });

  test(
    'An unavailable source keeps its cache and the next source still refreshes',
    () async {
      final client = _Client()..fail.add('a');
      final sources = _sources(client, ids: ['a', 'b']);
      addTearDown(sources.close);
      await sources.refreshAtStartup();
      expect(client.calls, ['a', 'b']);
      expect(sources.items.map((i) => i.title), ['Cache a', 'Actualisé b']);
      expect(sources.startupFailures, 1);
      expect(sources.startupCompleted, 2);
      expect(sources.startupProgress, 1);
      expect(sources.startupRefreshing, isFalse);
    },
  );

  testWidgets(
    'Startup banner fits compact and wide screens and uses indeterminate progress when size is unknown',
    (tester) async {
      final client = _Client()..gate = Completer<SourceCatalog>();
      final sources = _sources(client);
      addTearDown(sources.dispose);
      await sources.init();
      final job = sources.refreshAtStartup();
      await tester.pump();
      for (final width in [320.0, 1000.0]) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: width,
                child: SourceStartupProgress(controller: sources),
              ),
            ),
          ),
        );
        client.catalogProgress.value = const CatalogLoadProgress(
          'a',
          .5,
          'Téléchargement de la playlist',
        );
        await tester.pump();
        expect(
          tester
              .widget<LinearProgressIndicator>(
                find.byType(LinearProgressIndicator),
              )
              .value,
          .5,
        );
        expect(find.text('50 %'), findsOneWidget);
        client.catalogProgress.value = const CatalogLoadProgress(
          'a',
          null,
          'Téléchargement de la playlist',
        );
        await tester.pump();
        expect(
          tester
              .widget<LinearProgressIndicator>(
                find.byType(LinearProgressIndicator),
              )
              .value,
          isNull,
        );
        expect(tester.takeException(), isNull);
      }
      client.gate!.complete(SourceCatalog(items: [_item('a', 'Actualisé')]));
      await job;
      await tester.pump();
      expect(find.text('Sources à jour'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      expect(
        find.byKey(const ValueKey('source-startup-progress')),
        findsNothing,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final knownLength in [true, false]) {
    test(
      'M3U byte progress reports download and parsing with knownLength=$knownLength',
      () async {
        final bytes = utf8.encode(
          '#EXTM3U\n#EXTINF:-1 tvg-type="movie",Film\nhttps://example.test/video.mp4\n',
        );
        final client = IptvClient(
          clientFactory: () => MockClient.streaming(
            (request, body) async => http.StreamedResponse(
              Stream.fromIterable([bytes.sublist(0, 20), bytes.sublist(20)]),
              200,
              contentLength: knownLength ? bytes.length : null,
            ),
          ),
        );
        final reports = <CatalogLoadProgress>[];
        client.catalogProgress.addListener(
          () => reports.add(client.catalogProgress.value!),
        );
        final result = await client.loadCatalog(_record('a').config);
        expect(result.items.single.title, 'Film');
        expect(reports.last.phase, 'Lecture et classement du catalogue');
        final download = reports.where(
          (r) => r.phase == 'Téléchargement de la playlist',
        );
        expect(download, isNotEmpty);
        if (knownLength) {
          expect(
            download.any(
              (r) =>
                  r.fraction != null && r.fraction! > .05 && r.fraction! < .75,
            ),
            isTrue,
          );
        } else {
          expect(download.every((r) => r.fraction == null), isTrue);
        }
      },
    );
  }
}

class _Client extends IptvClient {
  final calls = <String>[];
  final fail = <String>{};
  Completer<SourceCatalog>? gate;
  @override
  Future<SourceCatalog> loadCatalog(
    SourceConfig config, {
    CancellationToken? cancel,
  }) async {
    calls.add(config.id);
    if (fail.contains(config.id)) throw StateError('Unavailable');
    if (gate != null) return gate!.future;
    return SourceCatalog(items: [_item(config.id, 'Actualisé ${config.id}')]);
  }
}
