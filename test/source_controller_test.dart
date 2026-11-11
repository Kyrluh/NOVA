import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nova_iptv/data/source_repository.dart';
import 'package:nova_iptv/domain/models.dart';
import 'package:nova_iptv/domain/source_models.dart';
import 'package:nova_iptv/sources/iptv_client.dart';
import 'package:nova_iptv/state/source_controller.dart';

void main() {
  test(
    'Automatic guide shares requests and avoids full catalogue writes',
    () async {
      final client = _Client()..epgWaiter = Completer<List<EpgProgramme>>();
      final repository = _FailingRepository([_record()])..fail = true;
      final controller = SourceController(
        repository: repository,
        client: client,
      );
      addTearDown(controller.close);
      await controller.init();
      final revision = controller.catalogRevision;
      final first = controller.ensureEpg('saved');
      await controller.ensureEpg('saved');
      expect(client.epgCalls, 1);
      expect(controller.epgLoading('saved'), isTrue);
      client.epgWaiter!.complete([
        EpgProgramme(
          channelId: 'channel',
          title: 'Current',
          description: '',
          start: DateTime.now(),
          end: DateTime.now().add(const Duration(hours: 1)),
        ),
      ]);
      await first;
      await controller.ensureEpg('saved');
      expect(client.epgCalls, 1);
      expect(controller.programmesFor('saved').single.title, 'Current');
      expect(controller.catalogRevision, revision);
      expect(controller.epgLoading('saved'), isFalse);
      expect(controller.error, isNull);
    },
  );

  test(
    'Automatic guide failure is nonblocking and backs off retries',
    () async {
      final client = _Client()..failEpg = true;
      final controller = SourceController(
        repository: MemorySourceRepository([_record()]),
        client: client,
      );
      addTearDown(controller.close);
      await controller.init();
      final items = controller.items;
      await controller.ensureEpg('saved');
      await controller.ensureEpg('saved');
      expect(client.epgCalls, 1);
      expect(controller.error, isNull);
      expect(controller.epgError('saved'), isNotNull);
      expect(controller.items, same(items));
      expect(controller.busyIds, isEmpty);
    },
  );

  test(
    'Leaving a detail cancels its request without cancelling a reopened detail',
    () async {
      final client = _Client()..detailWaiter = Completer<MediaItem>();
      final repository = MemorySourceRepository([_record()]);
      final controller = SourceController(
        repository: repository,
        client: client,
      );
      await controller.init();
      final item = controller.items.single;
      final oldRequest = controller.details(item);
      final cancelled = expectLater(
        oldRequest,
        throwsA(isA<SourceCancelled>()),
      );
      controller.cancelDetails(item.id);
      final current = controller.details(item);
      client.detailWaiter!.complete(
        item.copyWith(detailsLoaded: true, description: 'Fiche actuelle'),
      );
      await cancelled;
      expect((await current).description, 'Fiche actuelle');
      expect(controller.items.single.detailsLoaded, isTrue);
      expect(client.detailCalls, 2);
      await controller.close();
    },
  );
  test(
    'Recent additions keep legacy cache dates across refresh and restart',
    () async {
      final original = _record();
      final repository = MemorySourceRepository([original]);
      final client = _Client()..nextCatalog = original.catalog;
      final controller = SourceController(
        repository: repository,
        client: client,
      );
      await controller.init();
      expect(controller.items.single.addedAt, original.updatedAt);
      await controller.refresh(original.config.id);
      expect(controller.items.single.addedAt, original.updatedAt);
      await controller.close();
      final restored = SourceController(
        repository: repository,
        client: _Client(),
      );
      addTearDown(restored.close);
      await restored.init();
      expect(restored.items.single.addedAt, original.updatedAt);
    },
  );
  test('Recycled provider IDs cannot inherit artwork or seasons from another title', () async {
    final previous = _series(detailsLoaded: true)
        .copyWith(posterUrl: 'https://example.test/old.jpg');
    final original = SourceRecord(
      config: SourceConfig.fromDraft('saved', _draft),
      catalog: SourceCatalog(items: [previous]),
      programmes: const [],
      updatedAt: DateTime.utc(2026),
    );
    final client = _Client()
      ..nextCatalog = SourceCatalog(
        items: [
          _series(
            detailsLoaded: false,
            withEpisodes: false,
          ).copyWith(title: 'Different series'),
        ],
      );
    final sources = SourceController(
      repository: MemorySourceRepository([original]),
      client: client,
    );
    addTearDown(sources.close);
    await sources.init();
    await sources.refresh('saved');
    expect(sources.items.single.title, 'Different series');
    expect(sources.items.single.posterUrl, isNull);
    expect(sources.items.single.seasons, isEmpty);
  });
  test(
    'Cached sources restore without a provider request at startup',
    () async {
      final client = _Client();
      final repository = MemorySourceRepository([_record()]);
      final controller = SourceController(
        repository: repository,
        client: client,
      );
      addTearDown(controller.close);
      await controller.init();
      expect(client.loads, 0);
      expect(controller.items.single.id, 'saved:movie:1');
      expect(controller.sources.single.itemCount, 1);
      expect(controller.hasConfiguredSources, isTrue);
      expect(controller.isInitializing, isFalse);
    },
  );

  test(
    'Imported source, suggested guide and credentials survive restart',
    () async {
      final repository = MemorySourceRepository();
      final client = _Client()
        ..suggestedGuide = 'https://example.test/guide.xml';
      final controller = SourceController(
        repository: repository,
        client: client,
      );
      await controller.init();
      await controller.add(_draft);
      final id = controller.sources.single.id;
      expect(controller.items.single.sourceId, id);
      expect(controller.draftFor(id)!.epgUrl, client.suggestedGuide);
      expect(controller.programmesFor(id), isEmpty);
      await controller.close();
      final restoredClient = _Client();
      final restored = SourceController(
        repository: repository,
        client: restoredClient,
      );
      addTearDown(restored.close);
      await restored.init();
      expect(restoredClient.loads, 0);
      expect(restored.draftFor(id)!.password, 'private-password');
      expect(restored.items.single.id, '$id:movie:1');
    },
  );

  test('Refresh and storage failures preserve the previous catalogue without leaking errors', () async {
    final client = _Client();
    final repository = _FailingRepository([_record()]);
    final controller = SourceController(repository: repository, client: client);
    addTearDown(controller.close);
    await controller.init();
    client.failLoad = true;
    await expectLater(
      controller.refresh('saved'),
      throwsA(isA<SourceException>()),
    );
    expect(controller.items.single.title, 'Saved film');
    expect(controller.error, isNot(contains('private-password')));
    client.failLoad = false;
    repository.fail = true;
    await expectLater(
      controller.refresh('saved'),
      throwsA(isA<SourceException>()),
    );
    expect(controller.items.single.title, 'Saved film');
    expect(
      (await repository.readAll()).single.catalog.items.single.title,
      'Saved film',
    );
    expect(controller.busyIds, isEmpty);
  });

  test(
    'Deleting a source while its refresh is running cannot resurrect it',
    () async {
      final client = _Client();
      final repository = MemorySourceRepository([_record()]);
      final controller = SourceController(
        repository: repository,
        client: client,
      );
      addTearDown(controller.close);
      await controller.init();
      client.loadWaiter = Completer<SourceCatalog>();
      final refresh = controller.refresh('saved');
      final expected = expectLater(refresh, throwsA(isA<SourceCancelled>()));
      await controller.remove('saved');
      client.loadWaiter!.complete(SourceCatalog(items: [_item('saved')]));
      await expected;
      expect(controller.sources, isEmpty);
      expect(await repository.readAll(), isEmpty);
    },
  );

  test(
    'Cancelling during a protected save rolls back before publishing',
    () async {
      final repository = _BlockingRepository();
      final controller = SourceController(
        repository: repository,
        client: _Client(),
      );
      addTearDown(controller.close);
      await controller.init();
      final token = CancellationToken();
      final import = controller.add(_draft, cancel: token);
      final expected = expectLater(import, throwsA(isA<SourceCancelled>()));
      await repository.started.future;
      token.cancel();
      repository.release.complete();
      await expected;
      expect(controller.sources, isEmpty);
      expect(await repository.readAll(), isEmpty);
    },
  );

  test(
    'Lazy details are deduplicated and retained in the saved catalogue',
    () async {
      final client = _Client()..detailWaiter = Completer<MediaItem>();
      final repository = MemorySourceRepository([_record()]);
      final controller = SourceController(
        repository: repository,
        client: client,
      );
      addTearDown(controller.close);
      await controller.init();
      final first = controller.details(controller.items.single);
      final second = controller.details(controller.items.single);
      expect(identical(first, second), isTrue);
      expect(client.detailCalls, 1);
      client.detailWaiter!.complete(
        _item('saved')
            .copyWith(detailsLoaded: true, description: 'Loaded synopsis'),
      );
      await Future.wait([first, second]);
      expect(controller.items.single.description, 'Loaded synopsis');
      expect(
        (await repository.readAll()).single.catalog.items.single.detailsLoaded,
        isTrue,
      );
    },
  );

  test('Refreshing summaries preserves known episode IDs and retries details lazily', () async {
    final series = _series(detailsLoaded: true);
    final original = SourceRecord(
      config: SourceConfig.fromDraft('saved', _draft),
      catalog: SourceCatalog(items: [series]),
      programmes: const [],
      updatedAt: DateTime.utc(2026, 11, 9),
    );
    final client = _Client()
      ..nextCatalog = SourceCatalog(
        items: [_series(detailsLoaded: false, withEpisodes: false)],
      );
    final repository = MemorySourceRepository([original]);
    final controller = SourceController(repository: repository, client: client);
    addTearDown(controller.close);
    await controller.init();
    await controller.refresh('saved');
    expect(
      controller.items.single.seasons.single.episodes.single.id,
      'saved:episode:11',
    );
    expect(controller.items.single.detailsLoaded, isFalse);
    final cached = (await repository.readAll()).single.catalog.items.single;
    expect(cached.seasons.single.episodes.single.id, 'saved:episode:11');
    await controller.details(controller.items.single);
    expect(client.detailCalls, 1);
  });

  test(
    'Partial provider failures retain the unavailable catalogue section',
    () async {
      final original = SourceRecord(
        config: SourceConfig.fromDraft('saved', _draft),
        catalog: SourceCatalog(
          items: [_item('saved'), _series(detailsLoaded: true)],
        ),
        programmes: const [],
        updatedAt: DateTime.utc(2026, 11, 9),
      );
      final client = _Client()
        ..nextCatalog = SourceCatalog(
          items: [_item('saved', title: 'New title')],
          failedKinds: {MediaKind.series},
          warnings: ['Les séries sont temporairement indisponibles.'],
        );
      final repository = MemorySourceRepository([original]);
      final controller = SourceController(
        repository: repository,
        client: client,
      );
      addTearDown(controller.close);
      await controller.init();
      await controller.refresh('saved');
      expect(controller.items, hasLength(2));
      expect(controller.items.first.title, 'New title');
      expect(
        controller.items.last.seasons.single.episodes.single.id,
        'saved:episode:11',
      );
      expect(controller.warnings, hasLength(1));
      expect((await repository.readAll()).single.catalog.failedKinds, {
        MediaKind.series,
      });
    },
  );

  test('Updating credentials never resurrects cached episode URLs with the old password', () async {
    final original = SourceRecord(
      config: SourceConfig.fromDraft('saved', _draft),
      catalog: SourceCatalog(items: [_series(detailsLoaded: true)]),
      programmes: const [],
      updatedAt: DateTime.utc(2026, 11, 9),
    );
    final client = _Client()
      ..nextCatalog = SourceCatalog(
        items: [_series(detailsLoaded: false, withEpisodes: false)],
      );
    final controller = SourceController(
      repository: MemorySourceRepository([original]),
      client: client,
    );
    addTearDown(controller.close);
    await controller.init();
    await controller.update(
      'saved',
      const SourceDraft(
        name: 'Personal source',
        kind: SourceKind.xtream,
        address: 'https://example.test',
        username: 'private-user',
        password: 'new-password',
      ),
    );
    expect(controller.items.single.seasons, isEmpty);
    expect(controller.draftFor('saved')!.password, 'new-password');
  });

  test('Guide refresh keeps its source namespace and retains the old guide on failure', () async {
    final client = _Client();
    final controller = SourceController(
      repository: MemorySourceRepository([_record()]),
      client: client,
    );
    addTearDown(controller.close);
    await controller.init();
    final catalogRevision = controller.catalogRevision;
    final epgRevision = controller.epgRevision;
    await controller.refreshEpg('saved');
    expect(controller.programmesFor('saved'), hasLength(1));
    expect(controller.programmesFor('different-source'), isEmpty);
    expect(controller.catalogRevision, catalogRevision);
    expect(controller.epgRevision, greaterThan(epgRevision));
    client.failEpg = true;
    await expectLater(
      controller.refreshEpg('saved'),
      throwsA(isA<SourceException>()),
    );
    expect(controller.programmesFor('saved').single.title, 'Programme');
  });
}

const _draft = SourceDraft(
  name: 'Personal source',
  kind: SourceKind.xtream,
  address: 'https://example.test',
  username: 'private-user',
  password: 'private-password',
);

MediaItem _item(String sourceId, {String title = 'Imported film'}) => MediaItem(
  id: '$sourceId:movie:1',
  title: title,
  kind: MediaKind.movie,
  category: 'Films',
  description: '',
  year: 2026,
  durationMinutes: 90,
  palette: 0xff8b5cf6,
  subtitle: '',
  art: 0,
  sourceId: sourceId,
  providerId: '1',
  mediaUrl: 'https://example.test/movie/private-user/private-password/1.mp4',
);

SourceRecord _record() => SourceRecord(
  config: SourceConfig.fromDraft('saved', _draft),
  catalog: SourceCatalog(items: [_item('saved', title: 'Saved film')]),
  programmes: const [],
  updatedAt: DateTime.utc(2026, 11, 9),
);

MediaItem _series({required bool detailsLoaded, bool withEpisodes = true}) =>
    MediaItem(
      id: 'saved:series:2',
      title: 'Series',
      kind: MediaKind.series,
      category: 'Series',
      description: '',
      year: 2026,
      durationMinutes: 45,
      palette: 0xff8b5cf6,
      subtitle: '',
      art: 0,
      sourceId: 'saved',
      providerId: '2',
      detailsLoaded: detailsLoaded,
      seasons: withEpisodes
          ? const [
              DemoSeason(
                number: 1,
                episodes: [
                  DemoEpisode(
                    id: 'saved:episode:11',
                    title: 'Episode',
                    number: 1,
                    durationMinutes: 45,
                    mediaUrl: 'https://example.test/series/private-user/private-password/11.mp4',
                  ),
                ],
              ),
            ]
          : const [],
    );

class _Client extends IptvClient {
  int epgCalls = 0;
  Completer<List<EpgProgramme>>? epgWaiter;
  int loads = 0;
  int detailCalls = 0;
  bool failLoad = false;
  bool failEpg = false;
  String? suggestedGuide;
  SourceCatalog? nextCatalog;
  Completer<SourceCatalog>? loadWaiter;
  Completer<MediaItem>? detailWaiter;
  @override
  Future<SourceCatalog> loadCatalog(
    SourceConfig config, {
    CancellationToken? cancel,
  }) async {
    loads++;
    if (failLoad) throw StateError('private-password');
    if (loadWaiter != null) return loadWaiter!.future;
    if (nextCatalog != null) return nextCatalog!;
    return SourceCatalog(
      items: [_item(config.id)],
      suggestedEpgUrl: suggestedGuide,
    );
  }

  @override
  Future<MediaItem> loadDetails(
    SourceConfig config,
    MediaItem item, {
    CancellationToken? cancel,
  }) async {
    detailCalls++;
    return detailWaiter?.future ??
        Future.value(item.copyWith(detailsLoaded: true));
  }

  @override
  Future<List<EpgProgramme>> loadEpg(
    SourceConfig config, {
    CancellationToken? cancel,
  }) async {
    epgCalls++;
    if (epgWaiter != null) return epgWaiter!.future;
    if (failEpg) throw StateError('private-password');
    return [
      EpgProgramme(
        channelId: 'channel',
        title: 'Programme',
        description: '',
        start: DateTime.utc(2026, 11, 9),
        end: DateTime.utc(2026, 11, 9, 1),
      ),
    ];
  }
}

class _FailingRepository extends MemorySourceRepository {
  _FailingRepository(super.initial);
  bool fail = false;
  @override
  Future<void> write(SourceRecord record) async {
    if (fail) throw StateError('private-password');
    await super.write(record);
  }
}

class _BlockingRepository extends MemorySourceRepository {
  final started = Completer<void>();
  final release = Completer<void>();
  @override
  Future<void> write(SourceRecord record) async {
    if (!started.isCompleted) {
      started.complete();
      await release.future;
    }
    await super.write(record);
  }
}
