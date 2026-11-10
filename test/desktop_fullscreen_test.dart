import 'package:flutter_test/flutter_test.dart';
import 'package:nova_iptv/player/desktop_fullscreen.dart';

class FakeFullscreenWindow implements FullscreenWindow {
  final calls = <bool>[];
  bool fail = false;
  @override
  Future<void> setFullscreen(bool value) async {
    if (fail) throw StateError('Test failure');
    calls.add(value);
  }
}

void main() {
  test('Window toggles and restores its previous mode', () async {
    final window = FakeFullscreenWindow();
    final desktop = DesktopFullscreen(window: window);
    addTearDown(desktop.dispose);
    await desktop.toggle();
    expect(desktop.isFullscreen, isTrue);
    await desktop.toggle();
    expect(window.calls, [true, false]);
  });
  test(
    'Expanded player retains priority over a later visible player',
    () async {
      final desktop = DesktopFullscreen(window: FakeFullscreenWindow());
      addTearDown(desktop.dispose);
      final calls = <String>[];
      final owner = Object();
      desktop.registerPlayer(
        owner,
        visible: () => false,
        expanded: () => true,
        toggle: () async {
          calls.add('expanded');
        },
      );
      desktop.registerPlayer(
        Object(),
        visible: () => true,
        expanded: () => false,
        toggle: () async {
          calls.add('visible');
        },
      );
      await desktop.toggle();
      expect(calls, ['expanded']);
      desktop.unregisterPlayer(owner);
      await desktop.toggle();
      expect(calls, ['expanded', 'visible']);
    },
  );
  test('Failed native transition preserves mode and permits retry', () async {
    final window = FakeFullscreenWindow()..fail = true;
    final desktop = DesktopFullscreen(window: window);
    addTearDown(desktop.dispose);
    await expectLater(desktop.toggle(), throwsStateError);
    expect(desktop.isFullscreen, isFalse);
    window.fail = false;
    await desktop.toggle();
    expect(desktop.isFullscreen, isTrue);
  });
}
