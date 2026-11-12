import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nova_iptv/app.dart';
import 'package:nova_iptv/data/local_store.dart';
import 'package:nova_iptv/data/source_repository.dart';
import 'package:nova_iptv/domain/catalog_preferences.dart';
import 'package:nova_iptv/domain/models.dart';
import 'package:nova_iptv/domain/source_models.dart';
import 'package:nova_iptv/sources/iptv_client.dart';
import 'package:nova_iptv/state/app_controller.dart';
import 'package:nova_iptv/state/source_controller.dart';
import 'package:nova_iptv/ui/tv/tv_widgets.dart';
import 'package:nova_iptv/ui/widgets/search_field.dart';
import 'package:nova_iptv/ui/theme.dart';
import 'package:nova_iptv/updates/app_updates.dart';

void main() {
  test('Initial catalogue is complete; refresh skips hidden categories and keeps their cache', () async {
    final requests = <Uri>[];
    final client = IptvClient(
      clientFactory: () => MockClient((request) async {
        requests.add(request.url);
        final action = request.url.queryParameters['action'];
        Object data;
        if (action == null) {
          data = {
            'user_info': {'auth': 1, 'status': 'Active'},
          };
        } else if (action.endsWith('categories')) {
          data = [
            {'category_id': '1', 'category_name': 'FR | France'},
            {'category_id': '2', 'category_name': 'EN | UK'},
          ];
        } else {
          final selected = request.url.queryParameters['category_id'];
          data = [
            for (final id in ['1', '2'])
              if (selected == null || id == selected)
                {
                  'stream_id': id,
                  'series_id': id,
                  'name': 'Media $id',
                  'category_id': id,
                },
          ];
        }
        return http.Response(jsonEncode(data), 200);
      }),
    );
    final repository = MemorySourceRepository();
    final source = SourceController(repository: repository, client: client);
    var preferences = CatalogPreferences(
      rules: {
        for (final kind in MediaKind.values)
          kind: const CatalogRule(hiddenLanguages: {'en'}),
      },
    );
    source.preferencesForRefresh = () => preferences;
    addTearDown(() async {
      await source.close();
      source.dispose();
    });
    await source.init();
    await source.add(
      const SourceDraft(
        name: 'Fixture',
        kind: SourceKind.xtream,
        address: 'https://example.test',
        username: 'fixture',
        password: 'fixture',
      ),
    );
    expect(source.items.length, 6);
    final sourceId = source.sources.single.id;
    requests.clear();
    await source.refresh(sourceId);
    final lists = requests.where(
      (uri) => const {
        'get_live_streams',
        'get_vod_streams',
        'get_series',
      }.contains(uri.queryParameters['action']),
    );
    expect(lists.length, 3);
    expect(
      lists.every((uri) => uri.queryParameters['category_id'] == '1'),
      isTrue,
    );
    expect(
      source.items.length,
      6,
    ); // Hidden entries remain configurable offline.
    expect(applyCatalogPreferences(source.items, preferences).length, 3);
    requests.clear();
    await source.refreshAtStartup();
    final startupLists = requests.where(
      (uri) => const {
        'get_live_streams',
        'get_vod_streams',
        'get_series',
      }.contains(uri.queryParameters['action']),
    );
    expect(startupLists.length, 3);
    expect(
      startupLists.every(
        (uri) => !uri.queryParameters.containsKey('category_id'),
      ),
      isTrue,
    );
    expect(source.items.length, 6);
    expect(applyCatalogPreferences(source.items, preferences).length, 3);
    preferences = const CatalogPreferences();
    requests.clear();
    await source.reloadSources();
    expect(source.items.length, 6);
    expect(
      requests.where((uri) => uri.queryParameters['category_id'] == '2'),
      isEmpty,
    );
    expect(applyCatalogPreferences(source.items, preferences).length, 6);
  });

  test(
    'Startup removes only installers already installed for this edition',
    () async {
      final folder = await Directory.systemTemp.createTemp('nova-cleanup-');
      addTearDown(() => folder.delete(recursive: true));
      final updates = Directory('${folder.path}/updates')..createSync();
      for (final name in [
        'NOVA-IPTV-TV-0.10.2-universal.apk',
        'NOVA-IPTV-TV-0.10.3-universal.apk',
        'NOVA-IPTV-TV-0.10.4-universal.apk',
        'NOVA-IPTV-0.10.2-universal.apk',
        'personal.apk',
      ]) {
        File('${updates.path}/$name').writeAsStringSync('fixture');
      }
      final service = _CleanupService(folder);
      addTearDown(service.close);
      await service.cleanInstalledApks();
      final remaining = updates
          .listSync()
          .map((file) => file.uri.pathSegments.last)
          .toSet();
      expect(remaining, {
        'NOVA-IPTV-TV-0.10.4-universal.apk',
        'NOVA-IPTV-0.10.2-universal.apk',
        'personal.apk',
      });
    },
  );

  testWidgets(
    'TV tab changes reset search and scroll, focus the first channel and offer exit choices',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(960, 540);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final app = AppController(store: MemoryLocalStore(), television: true);
      await app.init();
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        app.dispose();
      });
      await tester.pumpWidget(
        NovaApp(
          controller: app,
          television: true,
          nativeReady: false,
          manageWindow: false,
        ),
      );
      await tester.pumpAndSettle();
      Future<void> tab(String name) async {
        final navigation = tester.state<ScrollableState>(
          find
              .descendant(
                of: find.byType(ListView).first,
                matching: find.byType(Scrollable),
              )
              .first,
        );
        navigation.position.jumpTo(0);
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byKey(ValueKey('tv-nav-$name')));
        await tester.tap(find.byKey(ValueKey('tv-nav-$name')));
        await tester.pumpAndSettle();
      }

      await tab('movies');
      final search = tester.widget<NovaSearchField>(
        find.byType(NovaSearchField),
      );
      search.controller.text = 'introuvable';
      search.onChanged('introuvable');
      await tester.pumpAndSettle();
      await tab('series');
      await tab('movies');
      expect(
        tester
            .widget<NovaSearchField>(find.byType(NovaSearchField))
            .controller
            .text,
        isEmpty,
      );
      final grid = find.byType(GridView);
      await tester.drag(grid, const Offset(0, -450));
      await tester.pumpAndSettle();
      await tab('series');
      await tab('movies');
      final scroll = tester.state<ScrollableState>(
        find
            .descendant(
              of: find.byType(GridView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(scroll.position.pixels, 0);
      await tab('live');
      final firstChannel = tester.widget<TvTile>(
        find
            .byWidgetPredicate(
              (widget) =>
                  widget is TvTile &&
                  widget.key.toString().contains('tv-channel-'),
            )
            .first,
      );
      expect(firstChannel.focusNode?.hasFocus, isTrue);
      final shape =
          tester
                  .widget<Material>(
                    find
                        .descendant(
                          of: find.byKey(firstChannel.key!),
                          matching: find.byType(Material),
                        )
                        .first,
                  )
                  .shape!
              as RoundedRectangleBorder;
      expect(shape.side.color, novaHighlight);
      await tab('home');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Réduire'), findsOneWidget);
      expect(find.text('Fermer'), findsOneWidget);
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();
      expect(find.text('Fermer'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}

class _CleanupService extends AppUpdateService {
  _CleanupService(Directory folder) : super(cacheDirectory: () async => folder);
  @override
  Future<InstalledApp> installed() async =>
      const InstalledApp(version: '0.10.3', windows: false, television: true);
}
