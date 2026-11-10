import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nova_iptv/player/player_adjustments.dart';

void main() {
  test(
    'Rapid wheel changes accumulate and only latest queued value is applied',
    () async {
      final applied = <double>[];
      final controls = PlayerAdjustments(
        volume: 70,
        applyVolume: (value) async {
          applied.add(value);
        },
        applyBrightness: (_) async {},
      );
      addTearDown(controls.dispose);
      final pending = <Future<void>>[];
      for (var i = 0; i < 4; i++) {
        pending.add(controls.setVolume(controls.volume + 5));
      }
      expect(controls.volume, 90);
      await Future.wait(pending);
      expect(applied, [90]);
      await controls.setVolume(150);
      expect(controls.volume, 100);
      await controls.setVolume(-50);
      expect(controls.volume, 0);
    },
  );

  test(
    'Delayed native volume events cannot undo a pending wheel change',
    () async {
      final gate = Completer<void>();
      final applied = <double>[];
      final controls = PlayerAdjustments(
        volume: 70,
        applyVolume: (value) async {
          applied.add(value);
          if (value == 75) await gate.future;
        },
        applyBrightness: (_) async {},
      );
      addTearDown(controls.dispose);
      final first = controls.setVolume(75);
      await Future<void>.delayed(Duration.zero);
      final second = controls.setVolume(controls.volume + 5);
      controls.syncVolume(75);
      expect(controls.volume, 80);
      gate.complete();
      await Future.wait([first, second]);
      expect(applied, [75, 80]);
      controls.syncVolume(65);
      expect(controls.volume, 65);
    },
  );

  test(
    'Brightness is bounded, reset works, failed commands restore applied state',
    () async {
      var fail = false;
      final applied = <int>[];
      final controls = PlayerAdjustments(
        volume: 70,
        applyVolume: (_) async {},
        applyBrightness: (value) async {
          if (fail) throw StateError('fixture');
          applied.add(value);
        },
      );
      addTearDown(controls.dispose);
      await controls.setBrightness(200);
      expect(controls.brightness, 100);
      await controls.setBrightness(-200);
      expect(controls.brightness, -100);
      await controls.setBrightness(0);
      fail = true;
      await expectLater(controls.setBrightness(5), throwsStateError);
      expect(controls.brightness, 0);
      expect(applied, [100, -100, 0]);
    },
  );

  test(
    'Disposed controls do not apply queued volume or brightness commands',
    () async {
      var calls = 0;
      final controls = PlayerAdjustments(
        volume: 70,
        applyVolume: (_) async {
          calls++;
        },
        applyBrightness: (_) async {
          calls++;
        },
      );
      final a = controls.setVolume(75);
      final b = controls.setBrightness(5);
      controls.dispose();
      await Future.wait([a, b]);
      expect(calls, 0);
    },
  );
}
