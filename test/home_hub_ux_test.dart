import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_iptv/data/local_store.dart';
import 'package:nova_iptv/state/app_controller.dart';
import 'package:nova_iptv/ui/pages/home_hub.dart';
import 'package:nova_iptv/ui/tv/tv_widgets.dart';

void main() {
  testWidgets(
    'TV home puts all six shortcuts before the compact suggestion and supports remote OK',
    (tester) async {
      tester.view.physicalSize = const Size(840, 500);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final app = AppController(store: MemoryLocalStore());
      await app.init();
      addTearDown(app.dispose);
      String? destination;
      await tester.pumpWidget(
        MaterialApp(
          theme: novaTvTheme(0xff8257e5),
          home: Scaffold(
            body: HomeHub(
              controller: app,
              television: true,
              showHeader: false,
              onNavigate: (value) => destination = value,
              onDetails: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final banner = tester.getRect(
        find.byKey(const ValueKey('home-featured')),
      );
      final first = tester.getRect(
        find.byKey(const ValueKey('home-shortcut-resume')),
      );
      for (final id in [
        'resume',
        'favorites',
        'live',
        'movies',
        'series',
        'platforms',
      ]) {
        final tile = tester.getRect(find.byKey(ValueKey('home-shortcut-$id')));
        expect(tile.top, first.top);
        expect(tile.bottom, lessThan(banner.top));
        expect(tile.bottom, lessThan(500));
      }
      expect(banner.height, lessThanOrEqualTo(190));
      expect(find.byTooltip('Changer de profil'), findsNothing);
      expect(find.byTooltip('Paramètres'), findsNothing);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();
      expect(destination, 'favorites');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Compact home keeps shortcuts above suggestions and profile settings accessible',
    (tester) async {
      tester.view.physicalSize = const Size(430, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final app = AppController(store: MemoryLocalStore());
      await app.init();
      addTearDown(app.dispose);
      String? destination;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HomeHub(
              controller: app,
              onNavigate: (value) => destination = value,
              onDetails: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final lastShortcut = tester.getRect(
        find.byKey(const ValueKey('home-shortcut-platforms')),
      );
      final banner = tester.getRect(
        find.byKey(const ValueKey('home-featured')),
      );
      expect(lastShortcut.bottom, lessThan(banner.top));
      expect(find.byTooltip('Changer de profil'), findsOneWidget);
      await tester.tap(find.byTooltip('Paramètres'));
      expect(destination, 'settings');
      expect(tester.takeException(), isNull);
    },
  );
}
