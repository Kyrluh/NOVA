import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_iptv/app.dart';
import 'package:nova_iptv/data/local_store.dart';
import 'package:nova_iptv/state/app_controller.dart';
import 'package:nova_iptv/player/desktop_fullscreen.dart';

import 'desktop_fullscreen_test.dart' show FakeFullscreenWindow;

void main() {
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
