import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nova_iptv/data/local_store.dart';
import 'package:nova_iptv/domain/models.dart';

void main() {
  test(
    'Invalid preferences fall back safely and numeric limits are enforced',
    () {
      final settings = AppSettings.fromJson({
        'accent': 'violet',
        'posterScale': 9,
        'animations': 'true',
        'autoPreview': 1,
        'playbackRate': 15,
        'volume': -20,
      });
      expect(settings.accent, const AppSettings().accent);
      expect(settings.posterScale, 1.5);
      expect(settings.animations, isTrue);
      expect(settings.autoPreview, isFalse);
      expect(settings.playbackRate, 1);
      expect(settings.volume, 0);
      expect(AppSettings.fromJson({'volume': double.nan}).volume, 70);
    },
  );

  test(
    'All offered playback rates round trip and invalid rates do not persist',
    () {
      for (final rate in playbackRates) {
        final settings = const AppSettings().copyWith(playbackRate: rate);
        expect(AppSettings.fromJson(settings.toJson()).playbackRate, rate);
      }
      expect(const AppSettings().copyWith(playbackRate: .6).playbackRate, 1);
    },
  );

  test('Progress rejects malformed records and clamps an overshoot', () {
    expect(WatchProgress.fromJson({'positionSeconds': -1}), isNull);
    final progress = WatchProgress.fromJson({
      'positionSeconds': 120,
      'durationSeconds': 100,
      'lastWatched': '2026-11-09T12:00:00Z',
    });
    expect(progress!.positionSeconds, 100);
    expect(progress.fraction, 1);
    expect(
      WatchProgress.fromJson(progress.toJson())!.lastWatched,
      progress.lastWatched,
    );
  });

  test(
    'File storage retains the previous valid save for crash recovery',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'nova-store-test-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final path = '${directory.path}${Platform.pathSeparator}settings.json';
      final store = FileLocalStore(path);
      expect(await store.load(), isEmpty);
      await store.save({
        'settings': {'playbackRate': 1.5},
      });
      await store.save({
        'settings': {'playbackRate': 2},
      });
      expect((await store.load())['settings']['playbackRate'], 2);
      await File(path).writeAsString('{invalid json');
      expect((await store.load())['settings']['playbackRate'], 1.5);
      await File(path).delete();
      expect((await store.load())['settings']['playbackRate'], 1.5);
      expect(jsonDecode(await File('$path.bak').readAsString()), isA<Map>());
    },
  );
}
