import 'package:flutter_test/flutter_test.dart';
import 'package:nova_iptv/data/demo_catalog.dart';
import 'package:nova_iptv/domain/models.dart';
import 'package:nova_iptv/domain/recent_catalog.dart';

void main() {
  test('Provider addition dates parse seconds, milliseconds and reject invalid dates', () {
    final date = DateTime.utc(2025, 2, 3);
    expect(providerAddedAt('${date.millisecondsSinceEpoch ~/ 1000}'), date);
    expect(providerAddedAt(date.millisecondsSinceEpoch), date);
    expect(providerAddedAt('0'), isNull);
    expect(providerAddedAt('bad'), isNull);
    expect(providerAddedAt('999999999999999999999'), isNull);
  });

  test('M3U first sight survives refresh, persistence and new episodes', () {
    final series = demoCatalog.firstWhere((i) => i.kind == MediaKind.series);
    final first = rememberCatalogAdditions([
      series,
    ], observedAt: DateTime.utc(2025));
    final saved = first.map((i) => MediaItem.fromJson(i.toJson())).toList();
    final refreshed = rememberCatalogAdditions(
      [
        series.copyWith(seasons: const [DemoSeason(number: 4, episodes: [])]),
      ],
      previous: saved,
      observedAt: DateTime.utc(2026),
    );
    expect(refreshed.single.addedAt, DateTime.utc(2025));
    expect(refreshed.single.seasons.single.number, 4);
  });

  test('New titles lead, provider dates win, live is excluded and ties retain source order', () {
    final movies = demoCatalog
        .where((i) => i.kind == MediaKind.movie)
        .take(3)
        .toList();
    final live = demoCatalog.firstWhere((i) => i.kind == MediaKind.live);
    final old = movies[0].copyWith(addedAt: DateTime.utc(2024));
    final provider = movies[1].copyWith(addedAt: DateTime.utc(2025));
    final incoming = rememberCatalogAdditions(
      [old, provider, movies[2], live],
      previous: [old],
      observedAt: DateTime.utc(2026),
    );
    expect(recentlyAdded(incoming).map((i) => i.id), [
      movies[2].id,
      provider.id,
      old.id,
    ]);
    expect(recentlyAdded(movies).map((i) => i.id), movies.map((i) => i.id));
  });
}
