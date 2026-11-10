import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_iptv/app.dart';
import 'package:nova_iptv/data/local_store.dart';
import 'package:nova_iptv/data/source_repository.dart';
import 'package:nova_iptv/domain/media_variants.dart';
import 'package:nova_iptv/domain/catalog_preferences.dart';
import 'package:nova_iptv/domain/models.dart';
import 'package:nova_iptv/domain/platform_catalog.dart';
import 'package:nova_iptv/domain/source_models.dart';
import 'package:nova_iptv/sources/iptv_client.dart';
import 'package:nova_iptv/state/app_controller.dart';
import 'package:nova_iptv/state/source_controller.dart';
import 'package:nova_iptv/ui/pages/details_dialog.dart';
import 'package:nova_iptv/ui/pages/home_page.dart';
import 'package:nova_iptv/ui/tv/tv_details.dart';
import 'package:nova_iptv/ui/widgets/variant_picker.dart';

MediaItem film(
  String id,
  String title, {
  int year = 2025,
  String category = 'Horreur',
  String source = 'fixture',
}) => MediaItem(
  id: id,
  title: title,
  kind: MediaKind.movie,
  category: category,
  description: '',
  year: year,
  durationMinutes: 90,
  palette: 0xff445588,
  subtitle: '',
  art: 0,
  sourceId: source,
  detailsLoaded: true,
  mediaUrl: 'https://example.test/$id.mp4',
);

Future<AppController> fixture({
  MemoryLocalStore? store,
  List<MediaItem>? items,
}) async {
  final sources = SourceController(
    repository: MemorySourceRepository([
      SourceRecord(
        config: const SourceConfig(
          id: 'fixture',
          name: 'Fixture',
          kind: SourceKind.xtream,
          address: 'https://example.test',
        ),
        catalog: SourceCatalog(
          items:
              items ??
              [
                film('old', 'Film [VF] [HD]'),
                film('new', 'Film [VOSTFR] [4K]'),
                film('other', 'Autre film'),
              ],
        ),
        programmes: const [],
        updatedAt: DateTime.utc(2025),
      ),
    ]),
    client: IptvClient(),
  );
  final app = AppController(
    store: store ?? MemoryLocalStore(),
    sources: sources,
  );
  await app.init();
  addTearDown(() {
    app.dispose();
    sources.dispose();
  });
  return app;
}

void main() {
  test('Legacy profile migrates and favorites/progress/settings/genres stay isolated after restart', () async {
    final store = MemoryLocalStore({
      'favorites': ['old'],
    });
    final app = await fixture(store: store);
    expect(app.favorites, contains('old'));
    app.selectProfile('main');
    app.updateProfile('Alice', {'Horreur'});
    app.updateSettings(app.settings.copyWith(playbackRate: 1.5));
    app.updateCatalogPreferences(
      app.catalogPreferences.copyWithRule(
        MediaKind.movie,
        app.catalogPreferences
            .ruleFor(MediaKind.movie)
            .copyWith(order: CatalogOrder.titleAsc),
      ),
    );
    app.recordProgress(
      'new',
      WatchProgress(
        positionSeconds: 100,
        durationSeconds: 5400,
        lastWatched: DateTime.utc(2026),
      ),
    );
    final bob = app.createProfile('Bob');
    app.selectProfile(bob);
    expect(app.favorites, isEmpty);
    expect(app.resumeItems, isEmpty);
    expect(app.settings.playbackRate, 1);
    expect(
      app.catalogPreferences.ruleFor(MediaKind.movie).order,
      CatalogOrder.source,
    );
    app.updateProfile('Bob', {'Comédie'});
    app.toggleFavorite('other');
    await app.flush();
    final restored = await fixture(store: store);
    expect(restored.profileChosen, isFalse);
    expect(restored.activeProfile.name, 'Bob');
    expect(restored.favorites, {'other'});
    restored.selectProfile('main');
    expect(restored.activeProfile.name, 'Alice');
    expect(restored.activeProfile.genres, {'Horreur'});
    expect(restored.settings.playbackRate, 1.5);
    expect(
      restored.catalogPreferences.ruleFor(MediaKind.movie).order,
      CatalogOrder.titleAsc,
    );
    expect(restored.progress['new']!.positionSeconds, 100);
    expect(restored.resumeItems.single.id, 'old');
    expect(restored.preferredVariant(restored.resumeItems.single).id, 'new');
    // Prevent the first controller's teardown from replacing the restarted store.
    app.selectProfile(bob);
  });

  test(
    'Variant matching keeps remakes, unknown years and distinct sources apart',
    () {
      final catalog = VariantCatalog([
        film('a', 'Film (2025) [VF] [1080p]'),
        film('b', 'Film (2025) [VOSTFR] [4K]'),
        film('remake', 'Film [VF]', year: 1980),
        film('unknown1', 'Sans année [VF]', year: 0),
        film('unknown2', 'Sans année [VO]', year: 0),
        film('source2', 'Film (2025) [VF]', source: 'other'),
      ]);
      expect(catalog.cards.length, 5);
      expect(
        VariantCatalog([
          film('1917', '1917', year: 2019),
          film('1944', '1944', year: 2019),
        ]).cards.length,
        2,
      );
      expect(catalog.byId['a']!.map((i) => i.id), ['a', 'b']);
      expect(variantTitle('Film (2025) [VF] [1080p]'), 'Film (2025)');
    },
  );

  test('Resume/favorite grouping preserves actual stream and removal across variants', () async {
    final app = await fixture();
    expect(app.items.length, 2);
    app.toggleFavorite('new');
    expect(app.favorites, contains('old'));
    app.recordProgress(
      'new',
      WatchProgress(
        positionSeconds: 100,
        durationSeconds: 5400,
        lastWatched: DateTime.utc(2026),
      ),
    );
    final card = app.resumeItems.single;
    expect(app.preferredVariant(card).mediaUrl, 'https://example.test/new.mp4');
    app.dismissResume(card.id);
    expect(app.resumeItems, isEmpty);
    app.recordProgress(
      'new',
      WatchProgress(
        positionSeconds: 120,
        durationSeconds: 5400,
        lastWatched: DateTime.utc(2026),
      ),
    );
    expect(app.resumeItems.length, 1);
  });

  test(
    'Genre recommendations rotate without leaving preferred matching movies',
    () async {
      final app = await fixture(
        items: [
          film('a', 'Film A'),
          film('b', 'Film B'),
          film('c', 'Comédie', category: 'Comédie'),
        ],
      );
      app.updateProfile('Alice', {'Horreur'});
      final first = app.recommendations.first.id;
      expect(app.recommendations.every((i) => i.category == 'Horreur'), isTrue);
      app.shuffleRecommendations();
      expect(app.recommendations.first.id, isNot(first));
      expect(app.recommendations.every((i) => i.category == 'Horreur'), isTrue);
    },
  );

  test(
    'Requested platforms and accented animation categories are recognized',
    () {
      for (final pair in [
        ('FR CANAL+', CatalogPlatform.canalPlus),
        ('STARZ', CatalogPlatform.starz),
        ('OCS', CatalogPlatform.ocs),
        ('VARIETY', CatalogPlatform.variety),
        ('TF1+ | M6+ | FTV', CatalogPlatform.frenchTv),
        ('DOCUMENTAIRES', CatalogPlatform.documentaries),
        ('ÉMISSION / REALITY TV', CatalogPlatform.reality),
        ('Films Animées', CatalogPlatform.kids),
        ('Séries Animés', CatalogPlatform.kids),
      ]) {
        expect(detectPlatforms(pair.$1), contains(pair.$2));
      }
    },
  );

  testWidgets(
    'Startup offers profiles then first-time genres, and settings reopen the picker',
    (tester) async {
      final app = await fixture();
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        NovaApp(
          controller: app,
          nativeReady: false,
          manageWindow: false,
          requireProfiles: true,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Qui regarde NOVA ?'), findsOneWidget);
      expect(find.text('Créer un profil'), findsOneWidget);
      await tester.tap(find.text('Mon profil'));
      await tester.pumpAndSettle();
      expect(find.text('Quels genres aimez-vous ?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilterChip, 'Horreur'));
      await tester.tap(find.text('Entrer dans NOVA'));
      await tester.pumpAndSettle();
      expect(find.text('Bonjour Mon profil'), findsOneWidget);
      expect(find.text('PAR PLATEFORME'), findsOneWidget);
      await tester.tap(find.byTooltip('Changer de profil'));
      await tester.pumpAndSettle();
      expect(find.text('Qui regarde NOVA ?'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'Shared and TV details expose language/quality variants; chosen movie launches the matching URI',
    (tester) async {
      final app = await fixture();
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      String? played;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showMediaDetails(
                  context,
                  controller: app,
                  item: app.items.first,
                  onPlay: (uri, _, _) => played = uri,
                ),
                child: const Text('Fiche'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Fiche'));
      await tester.pumpAndSettle();
      tester
          .widget<VariantPicker>(find.byType(VariantPicker))
          .onChanged(app.itemById('new')!);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Lecture'));
      await tester.tap(find.text('Lecture'));
      await tester.pumpAndSettle();
      expect(played, 'https://example.test/new.mp4');
      await tester.pumpWidget(
        MaterialApp(
          home: TvDetails(controller: app, item: app.items.first),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(VariantPicker), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'Trends preserve the former home while omitting resume/favorites/TV/speed shortcuts',
    (tester) async {
      final app = await fixture();
      app.toggleFavorite('old');
      app.recordProgress(
        'old',
        WatchProgress(
          positionSeconds: 50,
          durationSeconds: 5400,
          lastWatched: DateTime.utc(2026),
        ),
      );
      await app.flush();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HomePage(
              controller: app,
              trends: true,
              onDetails: (_) {},
              onOpenFile: () {},
              onNavigate: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('home-resume')), findsNothing);
      expect(find.text('Votre sélection'), findsNothing);
      expect(find.text('La télévision, en un endroit'), findsNothing);
      expect(find.text('À votre rythme'), findsNothing);
      await tester.scrollUntilVisible(
        find.text('À l’affiche'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('À l’affiche'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
