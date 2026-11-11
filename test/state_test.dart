import 'package:flutter_test/flutter_test.dart';
import 'package:nova_iptv/data/local_store.dart';
import 'package:nova_iptv/domain/models.dart';
import 'package:nova_iptv/state/app_controller.dart';

void main() {
  testWidgets(
    'TV playback ticks keep exact resume state without rebuilding menus every second',
    (tester) async {
      final store = MemoryLocalStore();
      final controller = AppController(store: store, television: true);
      await controller.init();
      addTearDown(controller.dispose);
      controller.toggleFavorite('film-orbite');
      WatchProgress progress(int position, {bool completed = false}) =>
          WatchProgress(
            positionSeconds: position,
            durationSeconds: 200,
            lastWatched: DateTime.utc(
              2026,
              11,
              11,
            ).add(Duration(seconds: position)),
            completed: completed,
          );
      controller.recordProgress('horizons-s1-e2', progress(60));
      await controller.flush();
      final favorites = controller.favorites;
      final seriesId = controller.resumeItems.single.id;
      var notifications = 0;
      controller.addListener(() => notifications++);

      controller.recordProgress('horizons-s1-e2', progress(61));
      controller.recordProgress('horizons-s1-e2', progress(62));
      expect(notifications, 0);
      expect(controller.progress['horizons-s1-e2']!.positionSeconds, 62);
      expect(controller.resumeItems.single.id, seriesId);
      expect(identical(controller.favorites, favorites), isTrue);
      await tester.pump(const Duration(seconds: 5));
      expect(notifications, 1);

      controller.dismissResume(seriesId);
      expect(controller.resumeItems, isEmpty);
      controller.recordProgress('horizons-s1-e2', progress(63));
      expect(controller.resumeItems.single.id, seriesId);
      expect(notifications, 3);
      controller.recordProgress(
        'horizons-s1-e2',
        progress(64, completed: true),
      );
      expect(controller.resumeItems, isEmpty);
      expect(notifications, 4);
      await controller.flush();
      final restored = AppController(store: store, television: true);
      addTearDown(restored.dispose);
      await restored.init();
      expect(restored.progress['horizons-s1-e2']!.positionSeconds, 64);
      expect(restored.progress['horizons-s1-e2']!.completed, isTrue);
      expect(restored.favorites, {'film-orbite'});
      expect(restored.resumeItems, isEmpty);
      await restored.flush();
    },
  );

  test(
    'Favorites, playback speed and episode progress survive a new controller',
    () async {
      final store = MemoryLocalStore();
      final controller = AppController(store: store);
      await controller.init();
      controller.toggleFavorite('film-orbite');
      controller.updateSettings(
        controller.settings.copyWith(playbackRate: 1.75),
      );
      controller.recordProgress(
        'horizons-s1-e2',
        WatchProgress(
          positionSeconds: 300,
          durationSeconds: 2760,
          lastWatched: DateTime.utc(2026, 11, 9),
        ),
      );
      await controller.flush();
      controller.dispose();
      final restored = AppController(store: store);
      addTearDown(restored.dispose);
      await restored.init();
      expect(restored.favorites, {'film-orbite'});
      expect(restored.settings.playbackRate, 1.75);
      expect(restored.progress['horizons-s1-e2']!.positionSeconds, 300);
      expect(restored.recentIds, ['horizons-s1-e2']);
    },
  );

  test('Unknown IDs and invalid persisted state are discarded', () async {
    final controller = AppController(
      store: MemoryLocalStore({
        'favorites': ['film-orbite', 'missing', 12],
        'settings': {'playbackRate': 'fast'},
        'progress': {
          'missing': {'positionSeconds': 12},
          'film-orbite': 'broken',
        },
        'recentIds': ['missing', 'film-orbite', 'film-orbite'],
      }),
    );
    addTearDown(controller.dispose);
    await controller.init();
    expect(controller.isReady, isTrue);
    expect(controller.favorites, {'film-orbite'});
    expect(controller.progress, isEmpty);
    expect(controller.settings.playbackRate, 1);
    expect(controller.recentIds, ['film-orbite']);
    controller.toggleFavorite('unknown');
    controller.markWatched('unknown');
    expect(controller.favorites, {'film-orbite'});
  });

  test(
    'Mark watched completes an episode independently and reset clears data',
    () async {
      final controller = AppController(store: MemoryLocalStore());
      addTearDown(controller.dispose);
      await controller.init();
      controller.markWatched('horizons-s1-e1');
      expect(controller.progress['horizons-s1-e1']!.completed, isTrue);
      expect(controller.progress['horizons-s1-e1']!.durationSeconds, 2640);
      expect(controller.progress.containsKey('horizons-s1-e2'), isFalse);
      controller.markWatched('live-nova');
      expect(controller.progress.containsKey('live-nova'), isFalse);
      controller.resetData();
      await controller.flush();
      expect(controller.progress, isEmpty);
      expect(controller.recentIds, isEmpty);
      expect(controller.settings.playbackRate, 1);
    },
  );

  test(
    'Storage errors are visible and do not prevent usable navigation state',
    () async {
      final controller = AppController(store: _FailingStore());
      addTearDown(controller.dispose);
      await controller.init();
      expect(controller.isReady, isTrue);
      expect(controller.items, isNotEmpty);
      expect(controller.storageError, isNotNull);
      controller.toggleFavorite('film-orbite');
      await controller.flush();
      expect(controller.favorites, {'film-orbite'});
      expect(controller.storageError, contains('sauvegarde'));
    },
  );
}

class _FailingStore implements LocalStore {
  @override
  Future<Map<String, dynamic>> load() async => throw const FormatException();

  @override
  Future<void> save(Map<String, dynamic> data) async =>
      throw StateError('disk');
}
