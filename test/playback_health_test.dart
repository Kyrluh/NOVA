import 'package:flutter_test/flutter_test.dart';
import 'package:nova_iptv/player/playback_health.dart';

void main() {
  testWidgets(
    'Recoverable decoder diagnostics never block advancing playback',
    (tester) async {
      final health = _health();
      health.begin();
      health.diagnostic();
      await tester.pump(const Duration(seconds: 10));
      expect(health.failed, isFalse);
      health.advance(const Duration(milliseconds: 300), playing: true);
      expect(health.hasProgress, isTrue);
      for (var second = 1; second <= 12; second++) {
        health.diagnostic();
        await tester.pump(const Duration(seconds: 1));
        health.advance(
          Duration(milliseconds: 300 + second * 1000),
          playing: true,
        );
        expect(health.failed, isFalse);
      }
      await tester.pump(const Duration(seconds: 30));
      expect(health.failed, isFalse);
    },
  );

  testWidgets(
    'Playing flags, zero timestamps and paused seeks prove no start',
    (tester) async {
      final health = _health();
      health.begin();
      health.advance(Duration.zero, playing: true);
      health.advance(const Duration(seconds: 10), playing: false);
      health.advance(const Duration(seconds: 10), playing: true);
      expect(health.hasProgress, isFalse);
      await tester.pump(const Duration(seconds: 24));
      expect(health.failed, isFalse);
      await tester.pump(const Duration(seconds: 1));
      expect(health.failed, isTrue);
    },
  );

  testWidgets(
    'Startup diagnostics cannot shorten or extend the probing window',
    (tester) async {
      final health = _health();
      health.begin();
      for (var second = 0; second < 24; second++) {
        health.diagnostic();
        await tester.pump(const Duration(seconds: 1));
        expect(health.failed, isFalse);
      }
      health.diagnostic();
      await tester.pump(const Duration(seconds: 1));
      expect(health.failed, isTrue);
    },
  );

  testWidgets('Repeated logs cannot postpone a confirmed post-start stall', (
    tester,
  ) async {
    final health = _health();
    health.begin();
    health.advance(const Duration(seconds: 1), playing: true);
    for (var second = 0; second < 7; second++) {
      health.diagnostic();
      await tester.pump(const Duration(seconds: 1));
      expect(health.failed, isFalse);
    }
    health.diagnostic();
    await tester.pump(const Duration(seconds: 1));
    expect(health.failed, isTrue);
    expect(health.hasProgress, isTrue);
  });

  testWidgets('Clock recovery clears a failure without another open or begin', (
    tester,
  ) async {
    final health = _health();
    health.begin();
    health.advance(const Duration(seconds: 1), playing: true);
    health.fail();
    expect(health.failed, isTrue);
    health.advance(const Duration(seconds: 2), playing: true);
    expect(health.failed, isFalse);
    health.diagnostic();
    await tester.pump(const Duration(seconds: 5));
    health.advance(const Duration(seconds: 3), playing: true);
    await tester.pump(const Duration(seconds: 10));
    expect(health.failed, isFalse);
  });

  testWidgets('Seeking backward and resetting live timestamps allow recovery', (
    tester,
  ) async {
    final health = _health();
    health.begin();
    health.advance(const Duration(seconds: 100), playing: true);
    health.fail();
    health.advance(const Duration(seconds: 5), playing: true);
    expect(health.failed, isTrue);
    health.advance(const Duration(seconds: 6), playing: true);
    expect(health.failed, isFalse);
    health.fail();
    health.advance(Duration.zero, playing: true);
    expect(health.failed, isTrue);
    health.advance(const Duration(milliseconds: 100), playing: true);
    expect(health.failed, isFalse);
  });

  testWidgets(
    'A new channel invalidates previous startup and diagnostic timers',
    (tester) async {
      final health = _health();
      health.begin();
      await tester.pump(const Duration(seconds: 24));
      health.begin();
      await tester.pump(const Duration(seconds: 2));
      expect(health.failed, isFalse);
      health.advance(const Duration(seconds: 1), playing: true);
      health.diagnostic();
      await tester.pump(const Duration(seconds: 7));
      health.begin();
      expect(health.hasProgress, isFalse);
      await tester.pump(const Duration(seconds: 2));
      expect(health.failed, isFalse);
      health.advance(const Duration(milliseconds: 100), playing: true);
      await tester.pump(const Duration(seconds: 30));
      expect(health.failed, isFalse);
    },
  );

  testWidgets(
    'An intentional pause suspends timers and resume gets a new limit',
    (tester) async {
      final health = _health();
      health.begin();
      await tester.pump(const Duration(seconds: 20));
      health.setPaused(true);
      health.diagnostic();
      await tester.pump(const Duration(minutes: 2));
      expect(health.failed, isFalse);
      health.setPaused(false);
      await tester.pump(const Duration(seconds: 24));
      expect(health.failed, isFalse);
      await tester.pump(const Duration(seconds: 1));
      expect(health.failed, isTrue);
    },
  );

  testWidgets(
    'Pausing a loaded stream cancels diagnostics without hiding failure',
    (tester) async {
      final health = _health();
      health.begin();
      health.advance(const Duration(seconds: 2), playing: true);
      health.diagnostic();
      await tester.pump(const Duration(seconds: 7));
      health.setPaused(true);
      await tester.pump(const Duration(seconds: 30));
      expect(health.failed, isFalse);
      health.setPaused(false);
      await tester.pump(const Duration(seconds: 20));
      expect(health.failed, isFalse);
      health.advance(const Duration(seconds: 3), playing: true);
      await tester.pump(const Duration(seconds: 30));
      expect(health.failed, isFalse);
      health.fail();
      health.setPaused(true);
      health.setPaused(false);
      expect(health.failed, isTrue);
    },
  );

  testWidgets(
    'Disposal cancels callbacks and ignores late native observations',
    (tester) async {
      final health = PlaybackHealth();
      var notifications = 0;
      health.addListener(() => notifications++);
      health.begin();
      health.advance(const Duration(seconds: 1), playing: true);
      health.diagnostic();
      final count = notifications;
      health.dispose();
      health.begin();
      health.diagnostic();
      health.advance(const Duration(seconds: 2), playing: true);
      health.setPaused(false);
      health.fail();
      await tester.pump(const Duration(minutes: 1));
      expect(notifications, count);
      expect(tester.takeException(), isNull);
    },
  );
}

PlaybackHealth _health() {
  final health = PlaybackHealth();
  addTearDown(health.dispose);
  return health;
}
