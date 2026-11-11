import 'package:flutter/material.dart';

import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:nova_iptv/app.dart';
import 'package:nova_iptv/data/local_store.dart';
import 'package:nova_iptv/data/source_repository.dart';
import 'package:nova_iptv/domain/models.dart';
import 'package:nova_iptv/domain/source_models.dart';
import 'package:nova_iptv/sources/iptv_client.dart';
import 'package:nova_iptv/state/app_controller.dart';
import 'package:nova_iptv/state/source_controller.dart';
import 'package:nova_iptv/ui/adaptive.dart';
import 'package:nova_iptv/ui/pages/catalog_page.dart';
import 'package:nova_iptv/ui/pages/live_page.dart';
import 'package:nova_iptv/ui/pages/home_hub.dart';
import 'package:nova_iptv/ui/pages/settings_page.dart';
import 'package:nova_iptv/ui/theme.dart';
import 'package:nova_iptv/ui/widgets/media_artwork.dart';

void main() {
  testWidgets(
    'Home with a large catalogue scrolls vertically over its horizontal posters',
    (tester) async {
      final app = await _app(
        tester,
        items: List.generate(1500, (i) => _fixtureItem(i, MediaKind.movie)),
      );
      _size(tester, const Size(673, 700));
      await tester.pumpWidget(
        NovaApp(
          controller: app,
          nativeReady: false,
          manageWindow: false,
          mobileUI: true,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(HomeHub), findsOneWidget);
      final rail = tester.widget<MediaRail>(find.byType(MediaRail).first);
      expect(rail.items.length, lessThanOrEqualTo(24));
      expect(app.items.length, 1500);
      await tester.ensureVisible(find.byType(MediaPoster).first);
      await tester.pumpAndSettle();
      final vertical = tester
          .state<ScrollableState>(
            find
                .descendant(
                  of: find.byKey(const PageStorageKey('home-scroll')),
                  matching: find.byType(Scrollable),
                )
                .first,
          )
          .position;
      final before = vertical.pixels;
      await tester.drag(find.byType(MediaPoster).first, const Offset(0, 200));
      await tester.pumpAndSettle();
      expect(vertical.pixels, lessThan(before));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Android compact home has no clipped content', (tester) async {
    final app = await _app(tester);
    _size(tester, const Size(360, 800));
    await tester.pumpWidget(
      NovaApp(
        controller: app,
        nativeReady: false,
        manageWindow: false,
        mobileUI: true,
      ),
    );
    await tester.pumpAndSettle();
  });
  testWidgets(
    'Long TV lists scroll by touch in dense cover and inner layouts without replacing playback',
    (tester) async {
      final app = await _app(
        tester,
        items: List.generate(80, (i) => _fixtureItem(i, MediaKind.live)),
      );
      _size(tester, const Size(390, 700));
      var created = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: novaTheme(app.settings.accent),
          home: NovaAdaptiveScope(
            android: true,
            child: Scaffold(
              body: LivePage(
                controller: app,
                onOpenUrl: () {},
                playerBuilder: (item, released) => _PlayerProbe(
                  onCreate: () => created++,
                  onDispose: released,
                  title: item.title,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(InkWell, 'Chaîne 000').first);
      await tester.pumpAndSettle();
      final playing = tester.state(find.byType(_PlayerProbe));
      for (final size in [
        const Size(360, 600),
        const Size(360, 260),
        const Size(600, 520),
        const Size(673, 620),
        const Size(840, 650),
      ]) {
        _size(tester, size);
        await tester.pumpAndSettle();
        final list = find.byKey(const ValueKey('tv-channel-list'));
        final scroll = tester.widget<ListView>(list).controller!;
        scroll.jumpTo(0);
        await tester.pumpAndSettle();
        expect(scroll.position.viewportDimension, greaterThan(85));
        await tester.drag(list, const Offset(0, -200));
        await tester.pumpAndSettle();
        expect(scroll.offset, greaterThan(60), reason: 'Touch scroll at $size');
        await tester.scrollUntilVisible(
          find.text('Chaîne 079'),
          240,
          scrollable: find.descendant(
            of: list,
            matching: find.byType(Scrollable),
          ),
        );
        expect(find.text('Chaîne 079').hitTestable(), findsOneWidget);
        expect(
          tester.state(find.byType(_PlayerProbe, skipOffstage: false)),
          same(playing),
        );
        expect(created, 1);
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'Inner display shows five posters per row and a smaller full-width details sheet',
    (tester) async {
      final app = await _app(
        tester,
        items: List.generate(
          30,
          (i) =>
              _fixtureItem(i, MediaKind.movie).copyWith(category: 'Films $i'),
        ),
      );
      _size(tester, const Size(673, 800));
      await tester.pumpWidget(
        NovaApp(
          controller: app,
          nativeReady: false,
          manageWindow: false,
          mobileUI: true,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Films'));
      await tester.pumpAndSettle();
      final posters = find.byType(MediaPoster);
      final firstRow = posters
          .evaluate()
          .take(5)
          .map((e) => tester.getRect(find.byWidget(e.widget)))
          .toList();
      expect(firstRow, hasLength(5));
      expect(
        firstRow.first.top,
        lessThan(400),
        reason: 'Filters must leave the first row visible even with many categories',
      );
      for (final rect in firstRow) {
        expect(rect.top, closeTo(firstRow.first.top, 1));
        expect(rect.width, lessThan(130));
      }
      await tester.tap(posters.first);
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(Dialog)).width, greaterThan(630));
      final detailArtwork = find.descendant(
        of: find.byType(Dialog),
        matching: find.byType(MediaArtwork),
      );
      expect(tester.getSize(detailArtwork).width, closeTo(112, 1));
      expect(tester.getSize(detailArtwork).height, closeTo(168, 1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Xtream source form fits a phone with its keyboard visible', (
    tester,
  ) async {
    final app = await _app(tester, items: _channels);
    _size(tester, const Size(360, 800));
    await tester.pumpWidget(
      NovaApp(
        controller: app,
        nativeReady: false,
        manageWindow: false,
        mobileUI: true,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Ouvrir un média'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ajouter une source IPTV'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Ajouter une source'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<SourceKind>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xtream Codes').last);
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('source-password')), findsOneWidget);
    expect(tester.takeException(), isNull);
    tester.view.resetViewInsets();
    await tester.pumpAndSettle();
  });
  testWidgets(
    'The shell preserves the selected TV page through bottom navigation and rail resize',
    (tester) async {
      final app = await _app(tester, items: _channels);
      _size(tester, const Size(390, 844));
      await tester.pumpWidget(
        NovaApp(
          controller: app,
          nativeReady: false,
          manageWindow: false,
          mobileUI: true,
        ),
      );
      await tester.pumpAndSettle();
      await _bottom(tester, 'TV');
      final state = tester.state(find.byType(LivePage));
      for (final size in [const Size(840, 1000), const Size(390, 844)]) {
        _size(tester, size);
        await tester.pumpAndSettle();
        expect(identical(tester.state(find.byType(LivePage)), state), isTrue);
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets('A visible vertical hinge stays between channel list and video', (
    tester,
  ) async {
    final app = await _app(tester, items: _channels);
    _size(tester, const Size(840, 1000));
    await tester.pumpWidget(
      MaterialApp(
        theme: novaTheme(app.settings.accent),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            displayFeatures: [
              const ui.DisplayFeature(
                bounds: Rect.fromLTWH(416, 0, 8, 1000),
                type: ui.DisplayFeatureType.hinge,
                state: ui.DisplayFeatureState.postureFlat,
              ),
            ],
          ),
          child: child!,
        ),
        home: NovaAdaptiveScope(
          android: true,
          child: Scaffold(
            body: LivePage(
              controller: app,
              onOpenUrl: () {},
              playerBuilder: (item, released) => _PlayerProbe(
                onCreate: () {},
                onDispose: released,
                title: item.title,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(InkWell, 'Chaîne alpha').first);
    await tester.pumpAndSettle();
    expect(
      tester.getRect(find.byType(_PlayerProbe)).left,
      greaterThanOrEqualTo(424),
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'Android compact navigation and home adapt from cover to tablet without replacing controller',
    (tester) async {
      final app = await _app(tester);
      _size(tester, const Size(360, 800));
      await tester.pumpWidget(
        NovaApp(
          controller: app,
          nativeReady: false,
          manageWindow: false,
          mobileUI: true,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _bottom(tester, 'Films');
      expect(find.byType(MediaCatalogPage), findsOneWidget);
      await tester.ensureVisible(find.byType(MediaPoster).first);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(MediaPoster).first);
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Fermer'));
      await tester.pumpAndSettle();
      _size(tester, const Size(840, 1000));
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.byType(MediaCatalogPage), findsOneWidget);
      expect(app.items, isNotEmpty);
      _size(tester, const Size(430, 840));
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(MediaCatalogPage), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Android touch settings and history are available on a cover display',
    (tester) async {
      final app = await _app(tester);
      app.recordProgress(
        'horizons-s1-e2',
        WatchProgress(
          positionSeconds: 100,
          durationSeconds: 600,
          lastWatched: DateTime.utc(2026),
        ),
      );
      _size(tester, const Size(360, 800));
      await tester.pumpWidget(
        NovaApp(
          controller: app,
          nativeReady: false,
          manageWindow: false,
          mobileUI: true,
        ),
      );
      await tester.pumpAndSettle();
      await _more(tester, 'Paramètres');
      expect(find.byType(SettingsPage), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('settings-category-playback')),
      );
      await tester.pumpAndSettle();
      final gestures = find.widgetWithText(SwitchListTile, 'Gestes tactiles');
      await tester.scrollUntilVisible(
        gestures,
        200,
        scrollable: find
            .descendant(
              of: find.byType(SettingsPage).last,
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      await tester.tap(gestures);
      await tester.pumpAndSettle();
      expect(app.settings.touchGestures, isFalse);
      expect(tester.takeException(), isNull);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('settings-category-hub')),
        findsOneWidget,
      );
      await _more(tester, 'Historique');
      expect(find.byType(HistoryPage), findsOneWidget);
      expect(
        tester
            .widgetList<MediaPoster>(find.byType(MediaPoster))
            .map((w) => w.item.id),
        contains('serie-horizons'),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Live TV preserves its playback State while folding, unfolding, rotating and filtering',
    (tester) async {
      final app = await _app(tester, items: _channels);
      var creations = 0;
      var disposals = 0;
      _size(tester, const Size(390, 844));
      await tester.pumpWidget(
        MaterialApp(
          theme: novaTheme(app.settings.accent),
          home: NovaAdaptiveScope(
            android: true,
            child: Scaffold(
              body: LivePage(
                controller: app,
                onOpenUrl: () {},
                playerBuilder: (item, released) => _PlayerProbe(
                  onCreate: () => creations++,
                  onDispose: () {
                    disposals++;
                    released();
                  },
                  title: item.title,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(InkWell, 'Chaîne alpha').first);
      await tester.pumpAndSettle();
      expect(creations, 1);
      expect(app.recentIds.first, 'alpha');
      final state = tester.state(find.byType(_PlayerProbe));
      for (final size in [
        const Size(840, 1000),
        const Size(1000, 600),
        const Size(840, 390),
        const Size(390, 844),
        const Size(320, 720),
      ]) {
        _size(tester, size);
        await tester.pumpAndSettle();
        expect(
          identical(tester.state(find.byType(_PlayerProbe)), state),
          isTrue,
        );
        expect(creations, 1);
        expect(disposals, 0);
        expect(tester.takeException(), isNull);
      }
      final search = find.byWidgetPredicate(
        (w) =>
            w is TextField && w.decoration?.hintText == 'Rechercher une chaîne',
      );
      await tester.enterText(search, 'beta');
      await tester.pumpAndSettle();
      expect(identical(tester.state(find.byType(_PlayerProbe)), state), isTrue);
      expect(find.text('Lecture Chaîne alpha'), findsOneWidget);
      expect(disposals, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Phone catalog organization and platform navigation remain scrollable',
    (tester) async {
      final app = await _app(tester);
      _size(tester, const Size(360, 800));
      await tester.pumpWidget(
        NovaApp(
          controller: app,
          nativeReady: false,
          manageWindow: false,
          mobileUI: true,
        ),
      );
      await tester.pumpAndSettle();
      await _more(tester, 'Tri et affichage');
      await tester.scrollUntilVisible(
        find.byType(Checkbox),
        200,
        scrollable: find
            .descendant(
              of: find.byKey(const Key('catalog-organization-scroll')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(tester.takeException(), isNull);
      await _more(tester, 'Par plateforme');
      final netflix = find.byKey(const ValueKey('platform-tile-netflix'));
      await tester.scrollUntilVisible(
        netflix,
        180,
        scrollable: find
            .descendant(
              of: find.byKey(const PageStorageKey('platform-overview')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      await tester.tap(netflix);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> _bottom(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label)),
  );
  await tester.pumpAndSettle();
}

Future<void> _more(WidgetTester tester, String label) async {
  await _bottom(tester, 'Plus');
  final target = find.widgetWithText(ListTile, label).first;
  final scrollable = find
      .descendant(
        of: find.byKey(const PageStorageKey('mobile-more')),
        matching: find.byType(Scrollable),
      )
      .first;
  tester.state<ScrollableState>(scrollable).position.jumpTo(0);
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(target, 200, scrollable: scrollable);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void _size(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
}

Future<AppController> _app(
  WidgetTester tester, {
  List<MediaItem>? items,
}) async {
  final sources = items == null
      ? null
      : SourceController(
          repository: MemorySourceRepository([
            SourceRecord(
              config: const SourceConfig(
                id: 'fold-test',
                name: 'Fixture pliable',
                kind: SourceKind.m3uUrl,
                address: 'https://example.test/catalog.m3u',
              ),
              catalog: SourceCatalog(items: items),
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
  );
  await app.init();
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    app.dispose();
    sources?.dispose();
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  return app;
}

class _PlayerProbe extends StatefulWidget {
  const _PlayerProbe({
    required this.onCreate,
    required this.onDispose,
    required this.title,
  });
  final VoidCallback onCreate;
  final VoidCallback onDispose;
  final String title;
  @override
  State<_PlayerProbe> createState() => _PlayerProbeState();
}

class _PlayerProbeState extends State<_PlayerProbe> {
  @override
  void initState() {
    super.initState();
    widget.onCreate();
  }

  @override
  void dispose() {
    widget.onDispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Colors.black,
    child: Center(child: Text('Lecture ${widget.title}')),
  );
}

MediaItem _fixtureItem(int i, MediaKind kind) => MediaItem(
  id: 'item-$i',
  title:
      '${kind == MediaKind.live ? 'Chaîne' : 'Film'} ${i.toString().padLeft(3, '0')}',
  kind: kind,
  category: 'FR | Catalogue',
  description: 'Création originale de test.',
  year: 2026,
  durationMinutes: 10,
  palette: 0xff6752eb,
  subtitle: '',
  art: i,
  sourceId: 'fold-test',
  mediaUrl: 'http://127.0.0.1/$i.mkv',
  detailsLoaded: true,
);

const _channels = [
  MediaItem(
    id: 'alpha',
    title: 'Chaîne alpha',
    kind: MediaKind.live,
    category: 'FR | TV',
    description: '',
    year: 0,
    durationMinutes: 0,
    palette: 0xff6752eb,
    subtitle: '',
    art: 0,
    sourceId: 'fold-test',
    mediaUrl: 'http://127.0.0.1/alpha.ts',
  ),
  MediaItem(
    id: 'beta',
    title: 'Chaîne beta',
    kind: MediaKind.live,
    category: 'FR | TV',
    description: '',
    year: 0,
    durationMinutes: 0,
    palette: 0xff6752eb,
    subtitle: '',
    art: 0,
    sourceId: 'fold-test',
    mediaUrl: 'http://127.0.0.1/beta.ts',
  ),
];
