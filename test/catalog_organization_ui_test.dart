import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_iptv/app.dart';
import 'package:nova_iptv/data/local_store.dart';
import 'package:nova_iptv/data/source_repository.dart';
import 'package:nova_iptv/domain/catalog_preferences.dart';
import 'package:nova_iptv/domain/models.dart';
import 'package:nova_iptv/domain/source_models.dart';
import 'package:nova_iptv/sources/iptv_client.dart';
import 'package:nova_iptv/state/app_controller.dart';
import 'package:nova_iptv/state/source_controller.dart';
import 'package:nova_iptv/ui/pages/catalog_organization_page.dart';
import 'package:nova_iptv/ui/pages/catalog_page.dart';
import 'package:nova_iptv/ui/pages/live_page.dart';
import 'package:nova_iptv/ui/pages/settings_page.dart';

void main() {
  testWidgets('Navigation exposes independent language rules and saves them', (
    tester,
  ) async {
    final session = await _start(tester);
    await _navigate(tester, 'Paramètres');
    await tester.scrollUntilVisible(
      find.byKey(const Key('configure-catalog')),
      300,
      scrollable: find
          .descendant(
            of: find.byType(SettingsPage),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('configure-catalog')));
    await tester.pumpAndSettle();
    expect(find.byType(CatalogOrganizationPage), findsOneWidget);
    expect(find.text('3 / 3 chaînes visibles'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('catalog-language-en')));
    await tester.pumpAndSettle();
    expect(find.text('2 / 3 chaînes visibles'), findsOneWidget);
    expect(
      session.app.items.map((item) => item.id),
      isNot(contains('live-en')),
    );

    await _selectKind(tester, 'Films');
    expect(find.text('2 / 2 titres visibles'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('catalog-language-fr')));
    await tester.pumpAndSettle();
    expect(session.app.items.map((item) => item.id), contains('live-fr'));
    expect(
      session.app.items.map((item) => item.id),
      isNot(contains('movie-fr')),
    );
    await _navigate(tester, 'Films');
    expect(find.byType(MediaCatalogPage), findsOneWidget);
    expect(
      tester
          .widgetList<MediaPoster>(find.byType(MediaPoster))
          .map((poster) => poster.item.id),
      ['movie-en'],
    );

    await session.app.flush();
    final restored = AppController(store: session.store);
    await restored.init();
    expect(
      restored.catalogPreferences.ruleFor(MediaKind.live).hiddenLanguages,
      {'en'},
    );
    expect(
      restored.catalogPreferences.ruleFor(MediaKind.movie).hiddenLanguages,
      {'fr'},
    );
    expect(
      restored.catalogPreferences.ruleFor(MediaKind.series).hiddenLanguages,
      isEmpty,
    );
    restored.dispose();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'A category can receive a language before filtering unknown content',
    (tester) async {
      final session = await _start(tester);
      await _navigate(tester, 'Tri et affichage');
      await _selectKind(tester, 'Séries');
      expect(
        find.byKey(const ValueKey('catalog-language-unknown')),
        findsOneWidget,
      );
      final categoryKey = catalogCategoryKey(_items.last);
      final dropdown = find.byKey(
        ValueKey('catalog-category-language-$categoryKey-'),
      );
      await tester.scrollUntilVisible(
        dropdown,
        220,
        scrollable: _pageScrollable,
      );
      await tester.tap(dropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Français').last);
      await tester.pumpAndSettle();
      expect(
        session.app.catalogPreferences
            .ruleFor(MediaKind.series)
            .languageOverrides[categoryKey],
        'fr',
      );
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('catalog-language-fr')),
        -220,
        scrollable: _pageScrollable,
      );
      expect(
        find.byKey(const ValueKey('catalog-language-unknown')),
        findsNothing,
      );
      await tester.tap(find.byKey(const ValueKey('catalog-language-fr')));
      await tester.pumpAndSettle();
      expect(find.text('0 / 1 titres visibles'), findsOneWidget);
      expect(
        session.app.items.where((item) => item.kind == MediaKind.series),
        isEmpty,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Category visibility and drag ordering affect the actual catalogue',
    (tester) async {
      final session = await _start(tester);
      await _navigate(tester, 'Tri et affichage');
      final firstKey = catalogCategoryKey(_items.first);
      final secondKey = catalogCategoryKey(_items[1]);
      final thirdKey = catalogCategoryKey(_items[2]);
      final firstCheckbox = find.byKey(ValueKey('catalog-category-$firstKey'));
      await tester.scrollUntilVisible(
        firstCheckbox,
        220,
        scrollable: _pageScrollable,
      );
      await tester.tap(firstCheckbox);
      await tester.pumpAndSettle();
      expect(
        session.app.items.map((item) => item.id),
        isNot(contains('live-fr')),
      );
      await tester.tap(firstCheckbox);
      await tester.pumpAndSettle();
      final firstHandle = find.byKey(ValueKey('catalog-drag-$firstKey'));
      final secondHandle = find.byKey(ValueKey('catalog-drag-$secondKey'));
      await tester.ensureVisible(secondHandle);
      await tester.pumpAndSettle();
      final gesture = await tester.startGesture(tester.getCenter(firstHandle));
      await tester.pump();
      await gesture.moveBy(const Offset(0, 20));
      await tester.pump();
      await gesture.moveTo(
        tester.getCenter(secondHandle) + const Offset(0, 65),
      );
      await tester.pump(const Duration(milliseconds: 400));
      await gesture.up();
      await tester.pumpAndSettle();
      final current = session.app.catalogPreferences.ruleFor(MediaKind.live);
      expect(current.order, CatalogOrder.category);
      expect(current.categoryOrder, [secondKey, thirdKey, firstKey]);
      expect(
        session.app.items
            .where((item) => item.kind == MediaKind.live)
            .map((item) => item.id)
            .toList(),
        ['live-en', 'live-de', 'live-fr'],
      );
      await _navigate(tester, 'TV en direct');
      final categoryButtons = ['EN | News', 'DE | Sport', 'FR | Info']
          .map(
            (label) => find
                .descendant(
                  of: find.byType(LivePage),
                  matching: find.text(label),
                )
                .first,
          )
          .toList();
      expect(
        tester.getTopLeft(categoryButtons[0]).dy,
        lessThan(tester.getTopLeft(categoryButtons[1]).dy),
      );
      expect(
        tester.getTopLeft(categoryButtons[1]).dy,
        lessThan(tester.getTopLeft(categoryButtons[2]).dy),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Movie category chips follow the chosen order after dragging', (
    tester,
  ) async {
    await _start(
      tester,
      items: [..._items, _media('movie-de', MediaKind.movie, 'DE | Kino')],
    );
    await _navigate(tester, 'Films');
    List<String?> labels() => tester
        .widgetList<ChoiceChip>(
          find.descendant(
            of: find.byType(MediaCatalogPage),
            matching: find.byType(ChoiceChip),
          ),
        )
        .map((chip) => (chip.label as Text).data)
        .toList();
    expect(labels(), [
      'Tout explorer',
      'DE | Kino',
      'EN | Movies',
      'FR | Cinéma',
    ]);
    await _navigate(tester, 'Tri et affichage');
    await _selectKind(tester, 'Films');
    final firstKey = catalogCategoryKey(_items[3]);
    final secondKey = catalogCategoryKey(_items[4]);
    final firstHandle = find.byKey(ValueKey('catalog-drag-$firstKey'));
    final secondHandle = find.byKey(ValueKey('catalog-drag-$secondKey'));
    await tester.scrollUntilVisible(
      secondHandle,
      220,
      scrollable: _pageScrollable,
    );
    await tester.pumpAndSettle();
    final gesture = await tester.startGesture(tester.getCenter(firstHandle));
    await tester.pump();
    await gesture.moveBy(const Offset(0, 20));
    await tester.pump();
    await gesture.moveTo(tester.getCenter(secondHandle) + const Offset(0, 65));
    await tester.pump(const Duration(milliseconds: 400));
    await gesture.up();
    await tester.pumpAndSettle();
    await _navigate(tester, 'Films');
    expect(labels(), [
      'Tout explorer',
      'EN | Movies',
      'DE | Kino',
      'FR | Cinéma',
    ]);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Empty filters can be recovered at minimum and short wide window sizes',
    (tester) async {
      await _start(tester, size: const Size(1000, 680));
      await _navigate(tester, 'Tri et affichage');
      await tester.tap(find.byKey(const Key('catalog-hide-languages')));
      await tester.pumpAndSettle();
      expect(find.text('0 / 3 chaînes visibles'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const Key('catalog-reset')));
      await tester.pumpAndSettle();
      expect(find.text('3 / 3 chaînes visibles'), findsOneWidget);
      tester.view.physicalSize = const Size(1200, 680);
      await tester.pumpAndSettle();
      await _navigate(tester, 'Paramètres');
      expect(find.byType(SettingsPage), findsOneWidget);
      await _navigate(tester, 'Tri et affichage');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Large category lists build only the visible rows', (
    tester,
  ) async {
    final items = [
      for (var i = 0; i < 2000; i++)
        _media('item-$i', MediaKind.live, 'FR | Groupe $i'),
    ];
    await _start(tester, items: items);
    await _navigate(tester, 'Tri et affichage');
    expect(find.text('2000 / 2000 chaînes visibles'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byType(Checkbox).first,
      220,
      scrollable: _pageScrollable,
    );
    expect(find.byType(Checkbox).evaluate().length, lessThan(30));
    await tester.enterText(
      find.byKey(const Key('catalog-category-search')),
      'Groupe 1999',
    );
    await tester.pumpAndSettle();
    expect(find.text('FR | Groupe 1999'), findsOneWidget);
    expect(find.byType(Checkbox), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Finder get _pageScrollable => find
    .descendant(
      of: find.byType(CatalogOrganizationPage),
      matching: find.byType(Scrollable),
    )
    .first;

Future<void> _selectKind(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(
      of: find.byKey(const Key('catalog-kind')),
      matching: find.text(label),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _navigate(WidgetTester tester, String label) async {
  final tooltip = find.byTooltip(label);
  final target = tooltip.evaluate().isNotEmpty
      ? tooltip.first
      : find.text(label).first;
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<({AppController app, MemoryLocalStore store})> _start(
  WidgetTester tester, {
  Size size = const Size(1440, 900),
  List<MediaItem> items = _items,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  final repository = MemorySourceRepository([
    SourceRecord(
      config: const SourceConfig(
        id: 'test-source',
        name: 'Mon catalogue',
        kind: SourceKind.m3uUrl,
        address: 'https://example.test/catalogue.m3u',
      ),
      catalog: SourceCatalog(items: items),
      programmes: const [],
      updatedAt: DateTime.utc(2026),
    ),
  ]);
  final sources = SourceController(
    repository: repository,
    client: IptvClient(),
  );
  final store = MemoryLocalStore({
    'settings': {'animations': false},
  });
  final app = AppController(store: store, sources: sources);
  await app.init();
  addTearDown(app.dispose);
  addTearDown(sources.dispose);
  await tester.pumpWidget(
    NovaApp(controller: app, nativeReady: false, manageWindow: false),
  );
  await tester.pumpAndSettle();
  return (app: app, store: store);
}

const _items = [
  MediaItem(
    id: 'live-fr',
    title: 'Chaîne un',
    kind: MediaKind.live,
    category: 'FR | Info',
    description: '',
    year: 0,
    durationMinutes: 0,
    palette: 0xff8b5cf6,
    subtitle: '',
    art: 0,
    sourceId: 'test-source',
  ),
  MediaItem(
    id: 'live-en',
    title: 'Channel two',
    kind: MediaKind.live,
    category: 'EN | News',
    description: '',
    year: 0,
    durationMinutes: 0,
    palette: 0xff8b5cf6,
    subtitle: '',
    art: 0,
    sourceId: 'test-source',
  ),
  MediaItem(
    id: 'live-de',
    title: 'Kanal drei',
    kind: MediaKind.live,
    category: 'DE | Sport',
    description: '',
    year: 0,
    durationMinutes: 0,
    palette: 0xff8b5cf6,
    subtitle: '',
    art: 0,
    sourceId: 'test-source',
  ),
  MediaItem(
    id: 'movie-fr',
    title: 'Film un',
    kind: MediaKind.movie,
    category: 'FR | Cinéma',
    description: '',
    year: 2026,
    durationMinutes: 90,
    palette: 0xff8b5cf6,
    subtitle: '',
    art: 0,
    sourceId: 'test-source',
  ),
  MediaItem(
    id: 'movie-en',
    title: 'Movie two',
    kind: MediaKind.movie,
    category: 'EN | Movies',
    description: '',
    year: 2025,
    durationMinutes: 90,
    palette: 0xff8b5cf6,
    subtitle: '',
    art: 0,
    sourceId: 'test-source',
  ),
  MediaItem(
    id: 'series-unknown',
    title: 'Une série',
    kind: MediaKind.series,
    category: 'À découvrir',
    description: '',
    year: 2026,
    durationMinutes: 45,
    palette: 0xff8b5cf6,
    subtitle: '',
    art: 0,
    sourceId: 'test-source',
  ),
];

MediaItem _media(String id, MediaKind kind, String category) => MediaItem(
  id: id,
  title: 'Chaîne $id',
  kind: kind,
  category: category,
  description: '',
  year: 0,
  durationMinutes: 0,
  palette: 0xff8b5cf6,
  subtitle: '',
  art: 0,
  sourceId: 'test-source',
);
