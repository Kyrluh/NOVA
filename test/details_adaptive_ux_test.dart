import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_iptv/data/demo_catalog.dart';
import 'package:nova_iptv/data/local_store.dart';
import 'package:nova_iptv/data/source_repository.dart';
import 'package:nova_iptv/domain/models.dart';
import 'package:nova_iptv/domain/source_models.dart';
import 'package:nova_iptv/sources/iptv_client.dart';
import 'package:nova_iptv/state/app_controller.dart';
import 'package:nova_iptv/state/source_controller.dart';
import 'package:nova_iptv/ui/adaptive.dart';
import 'package:nova_iptv/ui/pages/details_dialog.dart';
import 'package:nova_iptv/ui/theme.dart';

void main() {
  testWidgets('Phone detail actions remain accessible before a long synopsis', (
    tester,
  ) async {
    String? played;
    final app = await _mount(
      tester,
      _movie(),
      size: const Size(390, 780),
      android: true,
      onPlay: (uri, _, _) => played = uri,
    );
    final primary = find.byKey(const ValueKey('details-primary'));
    final synopsis = find.byKey(const ValueKey('details-synopsis'));
    expect(primary.hitTestable(), findsOneWidget);
    expect(tester.getSize(primary).height, greaterThanOrEqualTo(48));
    expect(
      tester.getBottomRight(primary).dy,
      lessThan(tester.getTopLeft(synopsis).dy),
    );
    expect(find.byTooltip('Fermer').hitTestable(), findsOneWidget);
    expect(tester.getRect(_dialogSurface).width, 374);

    await tester.tap(find.text('Ajouter aux favoris'));
    await tester.pumpAndSettle();
    expect(app.favorites, contains(app.items.first.id));
    expect(find.text('Dans mes favoris'), findsOneWidget);
    await tester.tap(find.text('Lire la suite'));
    await tester.pumpAndSettle();
    expect(find.text('Voir moins'), findsOneWidget);
    expect(
      tester.widget<Text>(find.text(_movie().description)).maxLines,
      isNull,
    );
    await tester.ensureVisible(find.text('Voir moins'));
    await tester.tap(find.text('Voir moins'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(primary);
    await tester.tap(primary);
    await tester.pumpAndSettle();
    expect(played, 'https://example.test/movie.mp4');
    expect(find.byType(Dialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Series resume remains unique across folded display sizes', (
    tester,
  ) async {
    final series = demoCatalog
        .firstWhere((item) => item.kind == MediaKind.series)
        .copyWith(
          description: _longSynopsis,
          seasons: [
            for (var season = 1; season <= 2; season++)
              DemoSeason(
                number: season,
                episodes: List.generate(
                  14,
                  (index) => DemoEpisode(
                    id: 'detail-s$season-e${index + 1}',
                    title: 'Épisode ${index + 1} saison $season',
                    number: index + 1,
                    durationMinutes: 24,
                    mediaUrl: 'https://example.test/s$season-e$index.mp4',
                  ),
                ),
              ),
          ],
        );
    await _mount(
      tester,
      series,
      size: const Size(673, 800),
      android: true,
      resumeId: 'detail-s2-e9',
    );
    final dialogElement = tester.element(find.byType(Dialog));
    final primary = find.byKey(const ValueKey('details-primary'));
    expect(find.text('Reprendre l’épisode'), findsOneWidget);
    expect(find.text('S02 · E09'), findsOneWidget);
    expect(find.textContaining('À reprendre'), findsOneWidget);
    expect(
      tester.getBottomRight(primary).dy,
      lessThan(
        tester.getTopLeft(find.byKey(const ValueKey('details-synopsis'))).dy,
      ),
    );
    expect(
      tester
          .widget<DropdownButton<int>>(find.byType(DropdownButton<int>))
          .value,
      1,
    );
    expect(
      tester
          .widget<ListTile>(
            find.ancestor(
              of: find.text('Épisode 9 saison 2'),
              matching: find.byType(ListTile),
            ),
          )
          .selected,
      isTrue,
    );
    expect(
      tester.getBottomRight(find.text('Épisode 9 saison 2')).dy,
      lessThan(800),
    );

    for (final size in [const Size(398, 850), const Size(840, 600)]) {
      tester.view.physicalSize = size;
      await tester.pumpAndSettle();
      expect(tester.element(find.byType(Dialog)), same(dialogElement));
      expect(find.textContaining('À reprendre'), findsOneWidget);
      expect(
        tester
            .widget<DropdownButton<int>>(find.byType(DropdownButton<int>))
            .value,
        1,
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('Windows details stay centered and close with Escape', (
    tester,
  ) async {
    await _mount(tester, _movie(), size: const Size(1440, 900), android: false);
    final rect = tester.getRect(_dialogSurface);
    expect(rect.width, 1100);
    expect(rect.center.dx, closeTo(720, .1));
    expect(
      find.byKey(const ValueKey('details-primary')).hitTestable(),
      findsOneWidget,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

final _longSynopsis = List.filled(
  45,
  'Un long synopsis accompagne ce film pour raconter son histoire.',
).join(' ');

Finder get _dialogSurface => find
    .descendant(of: find.byType(Dialog), matching: find.byType(Material))
    .first;

MediaItem _movie() => demoCatalog
    .firstWhere((item) => item.kind == MediaKind.movie)
    .copyWith(description: _longSynopsis);

Future<AppController> _mount(
  WidgetTester tester,
  MediaItem original, {
  required Size size,
  required bool android,
  String? resumeId,
  void Function(String uri, String title, String id)? onPlay,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  final item = original.copyWith(
    sourceId: 'details-adaptive-ux',
    detailsLoaded: true,
    mediaUrl: 'https://example.test/movie.mp4',
  );
  final sources = SourceController(
    repository: MemorySourceRepository([
      SourceRecord(
        config: const SourceConfig(
          id: 'details-adaptive-ux',
          name: 'Fixtures',
          kind: SourceKind.m3uUrl,
          address: 'https://example.test/list.m3u',
        ),
        catalog: SourceCatalog(items: [item]),
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
  if (resumeId != null) {
    app.recordProgress(
      resumeId,
      WatchProgress(
        positionSeconds: 60,
        durationSeconds: 200,
        lastWatched: DateTime.utc(2026),
      ),
    );
  }
  await tester.pumpWidget(
    MaterialApp(
      theme: novaTheme(app.settings.accent),
      home: NovaAdaptiveScope(
        android: android,
        child: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showMediaDetails(
                context,
                controller: app,
                item: app.items.first,
                onPlay: onPlay ?? (_, _, _) {},
              ),
              child: const Text('Ouvrir la fiche'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Ouvrir la fiche'));
  await tester.pumpAndSettle();
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    app.dispose();
    sources.dispose();
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  return app;
}
