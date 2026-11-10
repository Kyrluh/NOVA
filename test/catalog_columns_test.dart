import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_iptv/data/local_store.dart';
import 'package:nova_iptv/domain/models.dart';
import 'package:nova_iptv/state/app_controller.dart';
import 'package:nova_iptv/ui/adaptive.dart';
import 'package:nova_iptv/ui/pages/catalog_page.dart';
import 'package:nova_iptv/ui/tv/tv_catalog.dart';
import 'package:nova_iptv/ui/tv/tv_widgets.dart';
import 'package:nova_iptv/ui/theme.dart';
import 'package:nova_iptv/ui/widgets/catalog_columns_setting.dart';

void main() {
  test(
    'Column preference survives restart and stays isolated by profile',
    () async {
      final store = MemoryLocalStore();
      final app = AppController(store: store);
      await app.init();
      expect(app.settings.catalogColumns, 0);
      app.updateSettings(app.settings.copyWith(catalogColumns: 5));
      final other = app.createProfile('Autre');
      app.selectProfile(other);
      expect(app.settings.catalogColumns, 0);
      app.selectProfile('main');
      expect(app.settings.catalogColumns, 5);
      await app.flush();
      app.dispose();
      final restored = AppController(store: store);
      await restored.init();
      expect(restored.settings.catalogColumns, 5);
      expect(AppSettings.fromJson({'catalogColumns': -1}).catalogColumns, 0);
      expect(AppSettings.fromJson({'catalogColumns': 50}).catalogColumns, 12);
      restored.dispose();
    },
  );

  for (final mode in ['Windows', 'Android', 'TV']) {
    testWidgets(
      'Catalog columns change from settings and remain usable on narrow screens ($mode)',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = mode == 'Android'
            ? const Size(390, 800)
            : const Size(1280, 900);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        final app = AppController(store: MemoryLocalStore());
        await app.init();
        await tester.pumpWidget(
          ListenableBuilder(
            listenable: app,
            builder: (context, _) => MaterialApp(
              theme: mode == 'TV'
                  ? novaTvTheme(app.settings.accent)
                  : novaTheme(app.settings.accent),
              home: NovaAdaptiveScope(
                android: mode == 'Android',
                child: Scaffold(
                  body: Column(
                    children: [
                      CatalogColumnsSetting(controller: app),
                      Expanded(
                        child: mode == 'TV'
                            ? TvCatalog(
                                controller: app,
                                items: app.items
                                    .where((i) => i.kind == MediaKind.movie)
                                    .toList(),
                                onDetails: (_) {},
                              )
                            : MediaCatalogPage(
                                controller: app,
                                kind: MediaKind.movie,
                                onDetails: (_) {},
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        int columns() {
          final delegate = mode == 'TV'
              ? tester.widget<GridView>(find.byType(GridView)).gridDelegate
              : tester.widget<SliverGrid>(find.byType(SliverGrid)).gridDelegate;
          return (delegate as SliverGridDelegateWithFixedCrossAxisCount)
              .crossAxisCount;
        }

        for (final count in [1, 5, 8]) {
          tester
              .widget<DropdownButtonFormField<int>>(
                find.byType(DropdownButtonFormField<int>),
              )
              .onChanged!(count);
          await tester.pumpAndSettle();
          expect(columns(), mode == 'Android' && count > 3 ? 3 : count);
          expect(tester.takeException(), isNull);
          if (mode == 'TV' && count == 1) {
            final first = tester.widget<TvTile>(
              find.byWidgetPredicate((w) => w is TvTile && w.focusNode != null),
            );
            first.focusNode!.requestFocus();
            await tester.pumpAndSettle();
            await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
            await tester.pumpAndSettle();
            expect(
              first.focusNode!.hasFocus,
              isFalse,
              reason: 'One column must still allow remote navigation to the next movie',
            );
          }
        }
        tester.view.physicalSize = const Size(360, 800);
        await tester.pumpAndSettle();
        if (mode != 'TV') {
          final scroll = tester.state<ScrollableState>(
            find
                .descendant(
                  of: find.byType(CatalogGrid),
                  matching: find.byType(Scrollable),
                )
                .first,
          );
          scroll.position.jumpTo(scroll.position.maxScrollExtent);
          await tester.pumpAndSettle();
        }
        expect(columns(), lessThanOrEqualTo(3));
        expect(tester.takeException(), isNull);
        await app.flush();
        await tester.pumpWidget(const SizedBox());
        app.dispose();
      },
    );
  }
}
