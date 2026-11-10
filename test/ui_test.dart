import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_iptv/app.dart';
import 'package:nova_iptv/data/local_store.dart';
import 'package:nova_iptv/domain/models.dart';
import 'package:nova_iptv/state/app_controller.dart';
import 'package:nova_iptv/ui/pages/catalog_page.dart';
import 'package:nova_iptv/ui/pages/home_page.dart';
import 'package:nova_iptv/ui/pages/live_page.dart';
import 'package:nova_iptv/ui/pages/settings_page.dart';

void main() {
  testWidgets('Navigation, demo details and global search are usable', (
    tester,
  ) async {
    await _startApp(tester);
    expect(find.byType(HomePage), findsOneWidget);

    await _navigate(tester, 'Films');
    expect(find.byType(MediaCatalogPage), findsOneWidget);
    expect(
      tester.widget<MediaCatalogPage>(find.byType(MediaCatalogPage)).kind,
      MediaKind.movie,
    );
    await tester.tap(find.byType(MediaPoster).first);
    await tester.pumpAndSettle();
    final filmDialog = find.byType(Dialog);
    expect(filmDialog, findsOneWidget);
    expect(
      find.descendant(
        of: filmDialog,
        matching: find.textContaining('Aucun flux vidéo'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: filmDialog,
        matching: find.widgetWithText(FilledButton, 'Lecture'),
      ),
      findsNothing,
    );
    await tester.ensureVisible(find.byTooltip('Fermer'));
    await tester.tap(find.byTooltip('Fermer'));
    await tester.pumpAndSettle();

    await _navigate(tester, 'Séries');
    expect(
      tester.widget<MediaCatalogPage>(find.byType(MediaCatalogPage)).kind,
      MediaKind.series,
    );
    await tester.tap(find.byType(MediaPoster).first);
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);
    await tester.ensureVisible(find.byType(DropdownButton<int>));
    await tester.tap(find.byType(DropdownButton<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Saison 2').last);
    await tester.pumpAndSettle();
    expect(find.text('L’observatoire'), findsOneWidget);
    expect(find.text('Le premier signal'), findsNothing);
    await tester.ensureVisible(find.byTooltip('Fermer'));
    await tester.tap(find.byTooltip('Fermer'));
    await tester.pumpAndSettle();

    await _navigate(tester, 'TV en direct');
    expect(find.byType(LivePage), findsOneWidget);
    expect(find.text('Aucun programme disponible'), findsOneWidget);
    expect(find.text('Aucune source configurée'), findsOneWidget);

    // This is the global topbar field; the TV page has a separate local field.
    await tester.enterText(_globalSearch, 'derniere orbite');
    await tester.pumpAndSettle();
    expect(find.byType(SearchPage), findsOneWidget);
    expect(find.byType(MediaPoster), findsOneWidget);
    expect(
      tester.widget<MediaPoster>(find.byType(MediaPoster)).item.id,
      'film-orbite',
    );
    expect(tester.takeException(), isNull);

    await _navigate(tester, 'Accueil');
    expect(find.byType(HomePage), findsOneWidget);
  });

  testWidgets('Favorites and the chosen playback speed survive saving', (
    tester,
  ) async {
    final session = await _startApp(tester);
    await _navigate(tester, 'Films');
    await tester.tap(find.byTooltip('Ajouter Dernière orbite aux favoris'));
    await tester.pumpAndSettle();
    expect(session.controller.favorites, contains('film-orbite'));

    await _navigate(tester, 'Favoris');
    expect(find.byType(CollectionPage), findsOneWidget);
    expect(find.byType(MediaPoster), findsOneWidget);
    expect(
      tester.widget<MediaPoster>(find.byType(MediaPoster)).item.id,
      'film-orbite',
    );

    await _navigate(tester, 'Paramètres');
    final speed = find.byKey(const ValueKey('playback-speed'));
    await tester.scrollUntilVisible(
      speed,
      300,
      scrollable: find
          .descendant(
            of: find.byType(SettingsPage),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(speed, findsOneWidget);
    await tester.tap(speed);
    await tester.pumpAndSettle();
    await tester.tap(find.text('1,5×').last);
    await tester.pumpAndSettle();
    expect(session.controller.settings.playbackRate, 1.5);
    await session.controller.flush();

    final restored = AppController(store: session.store);
    await restored.init();
    expect(restored.favorites, contains('film-orbite'));
    expect(restored.settings.playbackRate, 1.5);
    restored.dispose();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Live categories, instant search and favorites filter channels', (
    tester,
  ) async {
    final session = await _startApp(tester);
    await _navigate(tester, 'TV en direct');
    final live = find.byType(LivePage);
    await tester.tap(
      find.descendant(of: live, matching: find.text('Découverte')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Terra'), findsWidgets);
    expect(find.text('NOVA One'), findsNothing);

    final localSearch = find.descendant(
      of: live,
      matching: find.byType(TextField),
    );
    await tester.enterText(localSearch, 'orbite');
    await tester.pumpAndSettle();
    expect(find.text('Orbite'), findsWidgets);
    expect(find.text('Terra'), findsNothing);
    // The last favorite action belongs to the currently selected preview.
    await tester.tap(find.byTooltip('Ajouter aux favoris').last);
    await tester.pumpAndSettle();
    expect(session.controller.favorites, contains('live-orbite'));

    await tester.enterText(localSearch, '');
    await tester.tap(
      find.descendant(of: live, matching: find.text('Mes favoris')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Orbite'), findsWidgets);
    expect(find.text('Terra'), findsNothing);
    await tester.enterText(localSearch, 'aucune correspondance');
    await tester.pumpAndSettle();
    expect(
      find.text('Aucune chaîne ne correspond à votre recherche.'),
      findsOneWidget,
    );
    expect(find.text('Orbite'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Minimum window size supports large posters and TV navigation', (
    tester,
  ) async {
    await _startApp(
      tester,
      size: const Size(1000, 680),
      settings: {'posterScale': 1.5},
    );
    expect(find.byType(HomePage), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'Home at 1000 × 680');
    for (final section in ['Films', 'Séries', 'TV en direct', 'Paramètres']) {
      await _navigate(tester, section);
      expect(
        tester.takeException(),
        isNull,
        reason: '$section at 1000 × 680 with large posters',
      );
    }
    await _navigate(tester, 'TV en direct');
    expect(find.text('Aucun programme disponible'), findsOneWidget);
  });
}

Finder get _globalSearch => find.byWidgetPredicate(
  (widget) =>
      widget is TextField &&
      (widget.decoration?.hintText?.startsWith('Un film,') ?? false),
);

Future<({AppController controller, MemoryLocalStore store})> _startApp(
  WidgetTester tester, {
  Size size = const Size(1440, 900),
  Map<String, dynamic> settings = const {},
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  final store = MemoryLocalStore({
    'settings': {'animations': false, ...settings},
  });
  final controller = AppController(store: store);
  await controller.init();
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    NovaApp(controller: controller, nativeReady: false, manageWindow: false),
  );
  await tester.pumpAndSettle();
  return (controller: controller, store: store);
}

Future<void> _navigate(WidgetTester tester, String label) async {
  final collapsedMenuItem = find.byTooltip(label);
  // Expanded sidebar labels are built before the duplicate topbar/page title.
  await tester.tap(
    collapsedMenuItem.evaluate().isNotEmpty
        ? collapsedMenuItem.first
        : find.text(label).first,
  );
  await tester.pumpAndSettle();
}
