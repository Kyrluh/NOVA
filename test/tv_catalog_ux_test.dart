import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_iptv/data/local_store.dart';
import 'package:nova_iptv/domain/models.dart';
import 'package:nova_iptv/state/app_controller.dart';
import 'package:nova_iptv/ui/tv/tv_catalog.dart';
import 'package:nova_iptv/ui/tv/tv_widgets.dart';
import 'package:nova_iptv/ui/widgets/search_field.dart';

void main() {
  Future<AppController> start(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(960, 540);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final app = AppController(store: MemoryLocalStore());
    await app.init();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      app.dispose();
    });
    return app;
  }

  testWidgets(
    'TV search empty state clears the query without opening the keyboard again',
    (tester) async {
      final app = await start(tester);
      final calls = <MethodCall>[];
      const channel = MethodChannel('nova/android');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        calls.add(call);
        return 'Titre introuvable';
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: novaTvTheme(app.settings.accent),
          home: Scaffold(
            body: TvCatalog(
              key: const ValueKey('movies'),
              controller: app,
              items: app.items.where((i) => i.kind == MediaKind.movie).toList(),
              onDetails: (_) {},
              search: true,
              recentCategory: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(calls, isEmpty);
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();
      expect(
        find.text('Aucun résultat pour « Titre introuvable »'),
        findsOneWidget,
      );
      expect(find.text('Effacer la recherche'), findsOneWidget);
      expect(find.byType(GridView), findsNothing);
      await tester.tap(find.text('Effacer la recherche'));
      await tester.pumpAndSettle();
      expect(find.byType(GridView), findsOneWidget);
      expect(calls, hasLength(1));
      expect(find.byType(EditableText), findsNothing);
      expect(find.text('Récemment ajoutés'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('TV empty library does not pretend a search failed', (
    tester,
  ) async {
    final app = await start(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: novaTvTheme(app.settings.accent),
        home: Scaffold(
          body: TvCatalog(controller: app, items: const [], onDetails: (_) {}),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Aucun contenu dans cette rubrique'), findsOneWidget);
    expect(find.text('Effacer la recherche'), findsNothing);
    expect(find.text('Réinitialiser les filtres'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'TV movie and series grids restore independent scroll positions',
    (tester) async {
      final app = await start(tester);
      final seed = app.items.firstWhere((i) => i.kind == MediaKind.movie);
      final items = List<MediaItem>.generate(
        80,
        (i) => MediaItem.fromJson({
          ...seed.toJson(),
          'id': 'scroll-$i',
          'title': 'Film $i',
        }),
      );
      final section = ValueNotifier('movies');
      addTearDown(section.dispose);
      final bucket = PageStorageBucket();
      await tester.pumpWidget(
        MaterialApp(
          theme: novaTvTheme(app.settings.accent),
          home: Scaffold(
            body: PageStorage(
              bucket: bucket,
              child: ValueListenableBuilder<String>(
                valueListenable: section,
                builder: (context, value, _) => TvCatalog(
                  key: ValueKey(value),
                  controller: app,
                  items: items,
                  onDetails: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      ScrollPosition position() => tester
          .state<ScrollableState>(
            find.descendant(
              of: find.byType(GridView),
              matching: find.byType(Scrollable),
            ),
          )
          .position;
      await tester.drag(find.byType(GridView), const Offset(0, -700));
      await tester.pumpAndSettle();
      final moviesOffset = position().pixels;
      expect(moviesOffset, greaterThan(0));
      section.value = 'series';
      await tester.pumpAndSettle();
      expect(position().pixels, 0);
      await tester.drag(find.byType(GridView), const Offset(0, -300));
      await tester.pumpAndSettle();
      section.value = 'movies';
      await tester.pumpAndSettle();
      expect(position().pixels, closeTo(moviesOffset, 1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'TV catalog clears its previous query and preserves category after leaving for settings',
    (tester) async {
      final app = await start(tester);
      final items = app.items.where((i) => i.kind == MediaKind.movie).toList();
      final selected = items.first;
      var editorCalls = 0;
      const channel = MethodChannel('nova/android');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        _,
      ) async {
        editorCalls++;
        return selected.title;
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      final catalogVisible = ValueNotifier(true);
      addTearDown(catalogVisible.dispose);
      final bucket = PageStorageBucket();
      await tester.pumpWidget(
        MaterialApp(
          theme: novaTvTheme(app.settings.accent),
          home: Scaffold(
            body: PageStorage(
              bucket: bucket,
              child: ValueListenableBuilder<bool>(
                valueListenable: catalogVisible,
                builder: (context, visible, _) => visible
                    ? TvCatalog(
                        key: const ValueKey('movies'),
                        controller: app,
                        items: items,
                        onDetails: (_) {},
                        search: true,
                        recentCategory: true,
                      )
                    : const Center(child: Text('Paramètres')),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      tester
          .widget<DropdownButtonFormField<String>>(
            find.byType(DropdownButtonFormField<String>),
          )
          .onChanged!(selected.category);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();
      expect(editorCalls, 1);
      catalogVisible.value = false;
      await tester.pumpAndSettle();
      expect(find.byType(TvCatalog), findsNothing);
      catalogVisible.value = true;
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<NovaSearchField>(find.byType(NovaSearchField))
            .controller
            .text,
        isEmpty,
      );
      expect(
        tester
            .widget<DropdownButtonFormField<String>>(
              find.byType(DropdownButtonFormField<String>),
            )
            .initialValue,
        selected.category,
      );
      expect(editorCalls, 1);
      expect(find.byKey(ValueKey('tv-card-${selected.id}')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
