import 'package:flutter_test/flutter_test.dart';
import 'package:nova_iptv/data/demo_catalog.dart';
import 'package:nova_iptv/data/local_store.dart';
import 'package:nova_iptv/domain/models.dart';
import 'package:nova_iptv/domain/platform_catalog.dart';
import 'package:nova_iptv/state/app_controller.dart';

WatchProgress _progress(int day, {bool complete = false}) => WatchProgress(
  positionSeconds: complete ? 600 : 120,
  durationSeconds: 600,
  lastWatched: DateTime.utc(2026, 11, day),
  completed: complete,
);

void main() {
  test(
    'Platform categories recognize names, plus signs and multiple labels',
    () {
      expect(detectPlatforms('FR | NETFLIX 4K'), {CatalogPlatform.netflix});
      expect(detectPlatforms('VOD - Disney+'), {CatalogPlatform.disneyPlus});
      expect(detectPlatforms('FR Paramount+'), {CatalogPlatform.paramountPlus});
      expect(detectPlatforms('Amazon Prime Video'), {
        CatalogPlatform.primeVideo,
      });
      expect(detectPlatforms('Apple TV+'), {CatalogPlatform.appleTv});
      expect(detectPlatforms('HBO Max'), {CatalogPlatform.hbo});
      expect(detectPlatforms('Netflix / Disney Plus'), {
        CatalogPlatform.netflix,
        CatalogPlatform.disneyPlus,
      });
      expect(detectPlatforms('Cinéma IMAX'), isEmpty);
      expect(detectPlatforms('Dramazon / Netflixable'), isEmpty);
    },
  );

  test(
    'Platform overrides can exclude automatic matches, round trip and reset',
    () {
      final movie = demoCatalog.first.copyWith(category: 'FR | Netflix');
      final preferences = const PlatformPreferences().withGroup(
        MediaKind.movie,
        movie.category,
        {},
      );
      final restored = PlatformPreferences.fromJson(preferences.toJson());
      expect(restored.platformsFor(movie), isEmpty);
      expect(
        restored.resetGroup(movie.kind, movie.category).platformsFor(movie),
        {CatalogPlatform.netflix},
      );
      expect(
        PlatformPreferences.fromJson({
          'movie:FR | Netflix': ['unknown'],
        }).platformsFor(movie),
        {CatalogPlatform.netflix},
      );
      expect(
        const PlatformPreferences().platformsFor(
          demoCatalog
              .firstWhere((i) => i.kind == MediaKind.live)
              .copyWith(category: 'Netflix'),
        ),
        isEmpty,
      );
    },
  );

  test('Resume sorts unfinished content and uses unfinished episode over later completed one', () async {
    final app = AppController(store: MemoryLocalStore());
    await app.init();
    addTearDown(app.dispose);
    app.recordProgress('film-orbite', _progress(1));
    app.recordProgress('film-azur', _progress(2, complete: true));
    app.recordProgress('horizons-s1-e2', _progress(3));
    app.recordProgress('horizons-s1-e1', _progress(4, complete: true));
    final series = app.allItems.firstWhere(
      (i) =>
          i.seasons.any((s) => s.episodes.any((e) => e.id == 'horizons-s1-e2')),
    );
    expect(app.resumeItems.map((i) => i.id), [series.id, 'film-orbite']);
    expect(
      app.latestProgressFor(series, unfinishedOnly: true)!.lastWatched,
      DateTime.utc(2026, 11, 3),
    );
  });

  test('Dismissal persists, preserves progress and favorites, and watching restores a series', () async {
    final store = MemoryLocalStore();
    final app = AppController(store: store);
    await app.init();
    app.recordProgress('film-orbite', _progress(1));
    app.recordProgress('horizons-s1-e2', _progress(2));
    final series = app.resumeItems.first;
    app.toggleFavorite(series.id);
    app.dismissResume(series.id);
    expect(app.resumeItems.map((i) => i.id), ['film-orbite']);
    expect(app.progress['horizons-s1-e2']!.positionSeconds, 120);
    app.updatePlatformPreferences(
      app.platformPreferences.withGroup(MediaKind.movie, 'Science-fiction', {
        CatalogPlatform.netflix,
      }),
    );
    await app.flush();
    app.dispose();
    final restored = AppController(store: store);
    await restored.init();
    addTearDown(restored.dispose);
    expect(restored.canResume(series), isFalse);
    expect(restored.favorites, contains(series.id));
    expect(
      restored.platformPreferences.platformsFor(
        restored.itemById('film-orbite')!,
      ),
      {CatalogPlatform.netflix},
    );
    restored.recordProgress('horizons-s1-e2', _progress(3));
    expect(restored.canResume(series), isTrue);
    restored.dismissResume('film-orbite');
    restored.restoreResume('film-orbite');
    expect(restored.canResume(restored.itemById('film-orbite')!), isTrue);
  });
}
