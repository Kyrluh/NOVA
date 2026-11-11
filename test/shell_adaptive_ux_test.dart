import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_iptv/app.dart';
import 'package:nova_iptv/data/local_store.dart';
import 'package:nova_iptv/data/source_repository.dart';
import 'package:nova_iptv/domain/models.dart';
import 'package:nova_iptv/domain/source_models.dart';
import 'package:nova_iptv/sources/iptv_client.dart';
import 'package:nova_iptv/state/app_controller.dart';
import 'package:nova_iptv/state/source_controller.dart';
import 'package:nova_iptv/ui/pages/home_hub.dart';
import 'package:nova_iptv/ui/pages/profiles_page.dart';
import 'package:nova_iptv/ui/pages/settings_page.dart';

void main() {
  testWidgets(
    'Windows global search shortcuts focus and select the query while profile and settings stay accessible',
    (tester) async {
      final app = await _start(tester, mobile: false);
      await tester.pumpWidget(_app(app, mobile: false));
      await tester.pumpAndSettle();
      final search = find.byKey(const ValueKey('desktop-global-search'));
      expect(find.byTooltip('Changer de profil'), findsOneWidget);
      expect(find.byTooltip('Paramètres'), findsOneWidget);

      await _shortcut(tester, LogicalKeyboardKey.keyF);
      expect(tester.widget<TextField>(search).focusNode!.hasFocus, isTrue);
      await tester.enterText(search, 'Film local');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      await _shortcut(tester, LogicalKeyboardKey.keyK);
      final field = tester.widget<TextField>(search);
      expect(field.focusNode!.hasFocus, isTrue);
      expect(
        field.controller!.selection,
        const TextSelection(baseOffset: 0, extentOffset: 10),
      );

      await tester.tap(find.byTooltip('Paramètres'));
      await tester.pumpAndSettle();
      expect(find.byType(SettingsPage), findsOneWidget);
      await tester.tap(find.byTooltip('Changer de profil'));
      await tester.pumpAndSettle();
      expect(find.byType(ProfilesPage), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Compact Android exposes topbar settings and grouped More with system Back to More',
    (tester) async {
      final app = await _start(tester, mobile: true);
      await tester.pumpWidget(_app(app, mobile: true));
      await tester.pumpAndSettle();
      expect(find.byType(HomeHub), findsOneWidget);
      expect(find.byTooltip('Changer de profil'), findsOneWidget);
      final settings = find.byTooltip('Paramètres');
      expect(settings, findsOneWidget);
      expect(tester.getRect(settings).bottom, lessThanOrEqualTo(56));
      expect(find.byTooltip('Recherche globale'), findsOneWidget);

      await tester.tap(settings);
      await tester.pumpAndSettle();
      expect(find.byType(SettingsPage), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(HomeHub), findsOneWidget);

      await tester.tap(find.text('Plus'));
      await tester.pumpAndSettle();
      final more = find.byKey(const PageStorageKey('mobile-more'));
      expect(more, findsOneWidget);
      final scrollable = find.descendant(
        of: more,
        matching: find.byType(Scrollable),
      );
      for (final group in [
        'Bibliothèque',
        'Découvrir',
        'Personnaliser',
        'Sources et fichiers',
      ]) {
        await tester.scrollUntilVisible(
          find.text(group),
          180,
          scrollable: scrollable,
        );
        expect(find.text(group).hitTestable(), findsOneWidget);
      }

      await tester.tap(find.byTooltip('Paramètres'));
      await tester.pumpAndSettle();
      expect(find.byType(SettingsPage), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(more, findsOneWidget);
      expect(find.byType(SettingsPage), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> _shortcut(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyEvent(key);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pumpAndSettle();
}

Widget _app(AppController controller, {required bool mobile}) => NovaApp(
  controller: controller,
  nativeReady: false,
  manageWindow: false,
  mobileUI: mobile,
  requireProfiles: true,
);

Future<AppController> _start(
  WidgetTester tester, {
  required bool mobile,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = mobile
      ? const Size(360, 800)
      : const Size(1366, 900);
  final sources = SourceController(
    repository: MemorySourceRepository([
      SourceRecord(
        config: const SourceConfig(
          id: 'shell-fixture',
          name: 'Source locale',
          kind: SourceKind.m3uUrl,
          address: 'https://example.test/fixture.m3u',
        ),
        catalog: SourceCatalog(items: const [_movie]),
        programmes: const [],
        updatedAt: DateTime.utc(2026),
      ),
    ]),
    client: IptvClient(),
  );
  final app = AppController(
    store: MemoryLocalStore({
      'settings': {'animations': false},
    }),
    sources: sources,
    android: mobile,
  );
  await app.init();
  app.selectProfile('main');
  app.updateProfile('Test', {});
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    app.dispose();
    sources.dispose();
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  return app;
}

const _movie = MediaItem(
  id: 'shell-movie',
  title: 'Film local',
  kind: MediaKind.movie,
  category: 'FR | Films',
  description: 'Un film utilisé pour vérifier la navigation.',
  year: 2026,
  durationMinutes: 90,
  palette: 0xff6752eb,
  subtitle: '',
  art: 0,
  sourceId: 'shell-fixture',
  mediaUrl: 'http://127.0.0.1/movie.mp4',
  detailsLoaded: true,
);
