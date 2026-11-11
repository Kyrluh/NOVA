import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_iptv/app.dart';
import 'package:nova_iptv/data/local_store.dart';
import 'package:nova_iptv/state/app_controller.dart';
import 'package:nova_iptv/player/desktop_fullscreen.dart';

import 'desktop_fullscreen_test.dart' show FakeFullscreenWindow;

void main() {
  testWidgets('Global search leaves the expanded live player active', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final app = AppController(store: MemoryLocalStore());
    await app.init();
    final desktop = DesktopFullscreen(window: FakeFullscreenWindow());
    final owner = Object();
    desktop.registerPlayer(
      owner,
      visible: () => true,
      expanded: () => true,
      toggle: () async {},
    );
    await tester.pumpWidget(
      NovaApp(
        controller: app,
        nativeReady: false,
        manageWindow: false,
        mobileUI: false,
        fullscreenController: desktop,
      ),
    );
    await tester.pumpAndSettle();
    final search = find.byKey(const ValueKey('desktop-global-search'));
    for (final key in [LogicalKeyboardKey.keyF, LogicalKeyboardKey.keyK]) {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(key);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(search).focusNode!.hasFocus, isFalse);
    }
    desktop.unregisterPlayer(owner);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await app.shutdown();
    app.dispose();
    desktop.dispose();
  });

  testWidgets(
    'F11 works with a search field focused and Escape restores window',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final app = AppController(store: MemoryLocalStore());
      await app.init();
      final window = FakeFullscreenWindow();
      final desktop = DesktopFullscreen(window: window);
      await tester.pumpWidget(
        NovaApp(
          controller: app,
          nativeReady: false,
          manageWindow: false,
          fullscreenController: desktop,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(TextField).first);
      await tester.sendKeyEvent(LogicalKeyboardKey.f11);
      await tester.pumpAndSettle();
      expect(window.calls, [true]);
      await tester.sendKeyEvent(LogicalKeyboardKey.f11);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.f11);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(window.calls, [true, false, true, false]);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await app.shutdown();
      desktop.dispose();
    },
  );
}
