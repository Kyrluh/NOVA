import 'models.dart';

/// Provider addition dates take precedence; undated playlists retain first sight.
List<MediaItem> rememberCatalogAdditions(
  List<MediaItem> incoming, {
  List<MediaItem> previous = const [],
  required DateTime observedAt,
}) {
  final known = {for (final item in previous) item.id: item};
  return incoming
      .map((item) {
        if (item.addedAt != null) return item;
        final old = known[item.id];
        return item.copyWith(
          addedAt:
              item.addedAt ??
              (old?.title == item.title ? old?.addedAt : null) ??
              observedAt,
        );
      })
      .toList(growable: false);
}

List<MediaItem> recentlyAdded(Iterable<MediaItem> catalog) {
  final indexed = catalog
      .where((item) => item.kind != MediaKind.live)
      .indexed
      .toList();
  indexed.sort((a, b) {
    final byDate = (b.$2.addedAt?.millisecondsSinceEpoch ?? 0).compareTo(
      a.$2.addedAt?.millisecondsSinceEpoch ?? 0,
    );
    return byDate == 0 ? a.$1.compareTo(b.$1) : byDate;
  });
  return indexed.map((entry) => entry.$2).toList(growable: false);
}

DateTime? providerAddedAt(Object? value) {
  final raw = value?.toString().trim() ?? '';
  final epoch = int.tryParse(raw);
  final date = epoch == null
      ? DateTime.tryParse(raw)?.toUtc()
      : (epoch > 0 && epoch < 100000000000000
            ? DateTime.fromMillisecondsSinceEpoch(
                epoch < 100000000000 ? epoch * 1000 : epoch,
                isUtc: true,
              )
            : null);
  if (date == null ||
      date.year < 2000 ||
      date.isAfter(DateTime.now().toUtc().add(const Duration(days: 1)))) {
    return null;
  }
  return date;
}
