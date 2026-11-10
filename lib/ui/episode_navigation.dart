import '../domain/models.dart';

/// Uses only episode groups supplied by the source; no title-based invention.
class EpisodeNavigation {
  EpisodeNavigation(MediaItem? series, String? currentId) {
    if (series == null || series.kind != MediaKind.series) return;
    final seasons = series.seasons.indexed.toList()
      ..sort((a, b) {
        final order = a.$2.number.compareTo(b.$2.number);
        return order == 0 ? a.$1.compareTo(b.$1) : order;
      });
    for (final entry in seasons) {
      final episodes = entry.$2.episodes.indexed.toList()
        ..sort((a, b) {
          final order = a.$2.number.compareTo(b.$2.number);
          return order == 0 ? a.$1.compareTo(b.$1) : order;
        });
      _episodes.addAll(episodes.map((entry) => entry.$2));
    }
    _index = _episodes.indexWhere((episode) => episode.id == currentId);
  }
  final List<DemoEpisode> _episodes = [];
  int _index = -1;
  bool get isResolved => _index >= 0;
  DemoEpisode? get previous => _adjacent(-1);
  DemoEpisode? get next => _adjacent(1);
  DemoEpisode? _adjacent(int direction) {
    final index = _index + direction;
    if (_index < 0 || index < 0 || index >= _episodes.length) return null;
    final episode = _episodes[index];
    return episode.mediaUrl?.trim().isNotEmpty == true ? episode : null;
  }
}
