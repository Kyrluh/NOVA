import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_iptv/data/local_store.dart';
import 'package:nova_iptv/state/app_controller.dart';
import 'package:nova_iptv/ui/adaptive.dart';
import 'package:nova_iptv/ui/pages/settings_page.dart';
import 'package:nova_iptv/ui/theme.dart';
import 'package:nova_iptv/ui/widgets/catalog_columns_setting.dart';

void main() {
  testWidgets(
    'Wide settings group Windows controls and preserve source access',
    (tester) async {
      _setSize(tester, const Size(1180, 900));
      final app = AppController(store: MemoryLocalStore());
      await app.init();
      var sourcesOpened = 0;
      await tester.pumpWidget(
        _settings(
          app,
          android: false,
          onManageSources: () => sourcesOpened++,
          onOrganize: () {},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('settings-split-view')), findsOneWidget);
      expect(find.text('Changer ou créer un profil'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('settings-category-library')));
      await tester.pumpAndSettle();
      expect(find.byType(CatalogColumnsSetting), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('settings-category-playback')),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('playback-speed')), findsOneWidget);
      expect(find.text('Raccourcis du lecteur'), findsOneWidget);
      expect(find.text('Gestes tactiles'), findsNothing);
      expect(find.text('Épisode suivant automatiquement'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('settings-category-sources')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('manage-sources')));
      expect(sourcesOpened, 1);
      await tester.tap(find.byKey(const ValueKey('settings-category-data')));
      await tester.pumpAndSettle();
      expect(find.text('Exporter les réglages'), findsOneWidget);
      expect(find.text('Importer les réglages'), findsOneWidget);
      expect(find.text('Réinitialiser les données'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await app.flush();
      app.dispose();
    },
  );

  testWidgets(
    'Compact Android settings open a category with Back and keep touch preferences on resize',
    (tester) async {
      _setSize(tester, const Size(430, 900));
      final app = AppController(store: MemoryLocalStore(), android: true);
      await app.init();
      await tester.pumpWidget(_settings(app, android: true));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('settings-category-hub')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey('settings-category-playback')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(BackButton), findsOneWidget);
      expect(find.byKey(const Key('playback-speed')), findsOneWidget);
      expect(find.text('Raccourcis du lecteur'), findsNothing);
      await tester.scrollUntilVisible(
        find.text('Gestes tactiles'),
        250,
        scrollable: find.byType(Scrollable).last,
      );
      final before = app.settings.touchGestures;
      await tester.tap(find.text('Gestes tactiles'));
      await tester.pumpAndSettle();
      expect(app.settings.touchGestures, !before);

      tester.view.physicalSize = const Size(1120, 900);
      await tester.pumpAndSettle();
      expect(find.byType(BackButton), findsOneWidget);
      expect(app.settings.touchGestures, !before);
      tester.view.physicalSize = const Size(430, 900);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('settings-category-hub')),
        findsOneWidget,
      );
      expect(app.settings.touchGestures, !before);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await app.flush();
      app.dispose();
    },
  );

  testWidgets(
    'Compact library settings close their route before opening catalog organisation',
    (tester) async {
      _setSize(tester, const Size(430, 900));
      final app = AppController(store: MemoryLocalStore(), android: true);
      await app.init();
      final navigator = GlobalKey<NavigatorState>();
      var opened = 0;
      bool? routeWasStillOpen;
      await tester.pumpWidget(
        _settings(
          app,
          android: true,
          navigatorKey: navigator,
          onOrganize: () {
            opened++;
            routeWasStillOpen = navigator.currentState!.canPop();
          },
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('settings-category-library')));
      await tester.pumpAndSettle();
      tester
          .widget<DropdownButtonFormField<int>>(
            find.descendant(
              of: find.byType(CatalogColumnsSetting),
              matching: find.byType(DropdownButtonFormField<int>),
            ),
          )
          .onChanged!(5);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('configure-catalog')),
        300,
        scrollable: find
            .descendant(
              of: find.byType(SettingsPage).last,
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('configure-catalog')));
      await tester.pumpAndSettle();
      expect(opened, 1);
      expect(routeWasStillOpen, isFalse);
      expect(
        find.byKey(const ValueKey('settings-category-hub')),
        findsOneWidget,
      );
      expect(app.settings.catalogColumns, 5);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await app.flush();
      app.dispose();
    },
  );
}

void _setSize(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

Widget _settings(
  AppController app, {
  required bool android,
  GlobalKey<NavigatorState>? navigatorKey,
  VoidCallback? onManageSources,
  VoidCallback? onOrganize,
}) => MaterialApp(
  navigatorKey: navigatorKey,
  theme: novaTheme(app.settings.accent),
  home: NovaAdaptiveScope(
    android: android,
    child: Scaffold(
      body: SettingsPage(
        controller: app,
        onManageSources: onManageSources,
        onOrganize: onOrganize,
      ),
    ),
  ),
);
