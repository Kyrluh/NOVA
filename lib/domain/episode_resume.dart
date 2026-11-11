import 'models.dart';

class EpisodeResumeTarget {
  const EpisodeResumeTarget(this.seasonIndex, this.episodeIndex, this.episode);
  final int seasonIndex;
  final int episodeIndex;
  final DemoEpisode episode;
}

/// Only the latest watched episode can be the current resume target. Completing
/// it must not revive an older unfinished record from an earlier episode.
EpisodeResumeTarget? episodeResumeTarget(
  MediaItem series,
  Map<String, WatchProgress> progress,
) {
  EpisodeResumeTarget? target;
  WatchProgress? latest;
  for (var index = 0; index < series.seasons.length; index++) {
    for (final entry in series.seasons[index].episodes.indexed) {
      final episode = entry.$2;
      final value = progress[episode.id];
      if (value != null &&
          (latest == null || !value.lastWatched.isBefore(latest.lastWatched))) {
        latest = value;
        target = EpisodeResumeTarget(index, entry.$1, episode);
      }
    }
  }
  if (latest == null ||
      latest.completed ||
      latest.positionSeconds <= 0 ||
      (latest.durationSeconds > 0 &&
          latest.positionSeconds >= latest.durationSeconds)) {
    return null;
  }
  return target;
}
