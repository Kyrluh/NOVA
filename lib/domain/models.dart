import 'package:flutter/foundation.dart';

enum MediaKind { live, movie, series }

@immutable
class MediaItem {
  const MediaItem({
    required this.id,
    required this.title,
    required this.kind,
    required this.category,
    required this.description,
    required this.year,
    required this.durationMinutes,
    required this.palette,
    required this.subtitle,
    required this.art,
    this.mediaUrl,
    this.seasons = const [],
    this.sourceId,
    this.providerId,
    this.posterUrl,
    this.tvgId,
    this.detailsLoaded = false,
    this.addedAt,
  });

  final String id;
  final String title;
  final MediaKind kind;
  final String category;
  final String description;
  final int year;
  final int durationMinutes;
  final int palette;
  final String subtitle;
  final int art;
  final String? mediaUrl;
  final List<DemoSeason> seasons;
  final String? sourceId;
  final String? providerId;
  final String? posterUrl;
  final String? tvgId;
  final bool detailsLoaded;
  final DateTime? addedAt;
  bool get isDemo => sourceId == null;

  MediaItem copyWith({
    String? title,
    String? category,
    String? description,
    int? year,
    int? durationMinutes,
    String? subtitle,
    String? mediaUrl,
    List<DemoSeason>? seasons,
    String? sourceId,
    String? providerId,
    String? posterUrl,
    String? tvgId,
    bool? detailsLoaded,
    DateTime? addedAt,
  }) => MediaItem(
    id: id,
    title: title ?? this.title,
    kind: kind,
    category: category ?? this.category,
    description: description ?? this.description,
    year: year ?? this.year,
    durationMinutes: durationMinutes ?? this.durationMinutes,
    palette: palette,
    subtitle: subtitle ?? this.subtitle,
    art: art,
    mediaUrl: mediaUrl ?? this.mediaUrl,
    seasons: seasons ?? this.seasons,
    sourceId: sourceId ?? this.sourceId,
    providerId: providerId ?? this.providerId,
    posterUrl: posterUrl ?? this.posterUrl,
    tvgId: tvgId ?? this.tvgId,
    detailsLoaded: detailsLoaded ?? this.detailsLoaded,
    addedAt: addedAt ?? this.addedAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'kind': kind.name,
    'category': category,
    'description': description,
    'year': year,
    'durationMinutes': durationMinutes,
    'palette': palette,
    'subtitle': subtitle,
    'art': art,
    'mediaUrl': mediaUrl,
    'seasons': seasons.map((s) => s.toJson()).toList(),
    'sourceId': sourceId,
    'providerId': providerId,
    'posterUrl': posterUrl,
    'tvgId': tvgId,
    'detailsLoaded': detailsLoaded,
    'addedAt': addedAt?.toUtc().toIso8601String(),
  };

  factory MediaItem.fromJson(Map<String, dynamic> data) {
    final kind = MediaKind.values
        .where((k) => k.name == data['kind'])
        .firstOrNull;
    if (data['id'] is! String ||
        (data['id'] as String).isEmpty ||
        kind == null) {
      throw const FormatException('Contenu du catalogue invalide.');
    }
    return MediaItem(
      id: data['id'] as String,
      title: _text(data['title']),
      kind: kind,
      category: _text(data['category'], 'Sans catégorie'),
      description: _text(data['description']),
      year: _integer(data['year']),
      durationMinutes: _integer(data['durationMinutes']),
      palette: _integer(data['palette'], 0xff8b5cf6),
      subtitle: _text(data['subtitle']),
      art: _integer(data['art']),
      mediaUrl: data['mediaUrl'] as String?,
      sourceId: data['sourceId'] as String?,
      providerId: data['providerId'] as String?,
      posterUrl: data['posterUrl'] as String?,
      tvgId: data['tvgId'] as String?,
      detailsLoaded: data['detailsLoaded'] == true,
      addedAt: DateTime.tryParse(data['addedAt']?.toString() ?? ''),
      seasons: (data['seasons'] as List? ?? const [])
          .map((s) => DemoSeason.fromJson(Map<String, dynamic>.from(s as Map)))
          .toList(growable: false),
    );
  }
}

@immutable
class DemoSeason {
  const DemoSeason({required this.number, required this.episodes});
  final int number;
  final List<DemoEpisode> episodes;
  Map<String, dynamic> toJson() => {
    'number': number,
    'episodes': episodes.map((e) => e.toJson()).toList(),
  };
  factory DemoSeason.fromJson(Map<String, dynamic> data) => DemoSeason(
    number: _integer(data['number'], 1),
    episodes: (data['episodes'] as List? ?? const [])
        .map((e) => DemoEpisode.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(growable: false),
  );
}

@immutable
class DemoEpisode {
  const DemoEpisode({
    required this.id,
    required this.title,
    required this.number,
    required this.durationMinutes,
    this.mediaUrl,
    this.posterUrl,
    this.description = '',
  });
  final String id;
  final String title;
  final int number;
  final int durationMinutes;
  final String? mediaUrl;
  final String? posterUrl;
  final String description;
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'number': number,
    'durationMinutes': durationMinutes,
    'mediaUrl': mediaUrl,
    'posterUrl': posterUrl,
    'description': description,
  };
  factory DemoEpisode.fromJson(Map<String, dynamic> data) => DemoEpisode(
    id: _text(data['id']),
    title: _text(data['title']),
    number: _integer(data['number'], 1),
    durationMinutes: _integer(data['durationMinutes']),
    mediaUrl: data['mediaUrl'] as String?,
    posterUrl: data['posterUrl'] as String?,
    description: _text(data['description']),
  );
}

String _text(Object? value, [String fallback = '']) =>
    value is String ? value : fallback;
int _integer(Object? value, [int fallback = 0]) =>
    value is num && value.isFinite ? value.toInt() : fallback;

const playbackRates = <double>[.25, .5, .75, 1, 1.25, 1.5, 1.75, 2, 2.5, 3];

@immutable
class AppSettings {
  const AppSettings({
    this.accent = 0xff8b5cf6,
    this.posterScale = 1,
    this.catalogColumns = 0,
    this.animations = true,
    this.autoPreview = false,
    this.playbackRate = 1,
    this.volume = 70,
    this.autoNext = true,
    this.touchGestures = true,
    this.brightnessGestures = true,
    this.volumeGestures = true,
    this.seekGestures = true,
    this.reconnectEnabled = true,
    this.reconnectAttempts = 3,
    this.reconnectDelaySeconds = 3,
    this.pictureInPicture = true,
    this.landscapeFullscreen = true,
  });

  final int accent;
  final double posterScale;

  /// Zero keeps the adaptive layout; positive values request this many columns.
  final int catalogColumns;
  final bool animations;
  final bool autoPreview;
  final double playbackRate;
  final double volume;
  final bool autoNext;
  final bool touchGestures;
  final bool brightnessGestures;
  final bool volumeGestures;
  final bool seekGestures;
  final bool reconnectEnabled;
  final int reconnectAttempts;
  final int reconnectDelaySeconds;
  final bool pictureInPicture;
  final bool landscapeFullscreen;

  AppSettings copyWith({
    int? accent,
    double? posterScale,
    int? catalogColumns,
    bool? animations,
    bool? autoPreview,
    double? playbackRate,
    double? volume,
    bool? autoNext,
    bool? touchGestures,
    bool? brightnessGestures,
    bool? volumeGestures,
    bool? seekGestures,
    bool? reconnectEnabled,
    int? reconnectAttempts,
    int? reconnectDelaySeconds,
    bool? pictureInPicture,
    bool? landscapeFullscreen,
  }) => AppSettings.fromJson({
    'accent': accent ?? this.accent,
    'posterScale': posterScale ?? this.posterScale,
    'catalogColumns': catalogColumns ?? this.catalogColumns,
    'animations': animations ?? this.animations,
    'autoPreview': autoPreview ?? this.autoPreview,
    'playbackRate': playbackRate ?? this.playbackRate,
    'volume': volume ?? this.volume,
    'autoNext': autoNext ?? this.autoNext,
    'touchGestures': touchGestures ?? this.touchGestures,
    'brightnessGestures': brightnessGestures ?? this.brightnessGestures,
    'volumeGestures': volumeGestures ?? this.volumeGestures,
    'seekGestures': seekGestures ?? this.seekGestures,
    'reconnectEnabled': reconnectEnabled ?? this.reconnectEnabled,
    'reconnectAttempts': reconnectAttempts ?? this.reconnectAttempts,
    'reconnectDelaySeconds':
        reconnectDelaySeconds ?? this.reconnectDelaySeconds,
    'pictureInPicture': pictureInPicture ?? this.pictureInPicture,
    'landscapeFullscreen': landscapeFullscreen ?? this.landscapeFullscreen,
  });

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    final accent = json['accent'];
    return AppSettings(
      accent: accent is int && accent >= 0xff000000 && accent <= 0xffffffff
          ? accent
          : const AppSettings().accent,
      posterScale: _bounded(json['posterScale'], .75, 1.5, 1),
      catalogColumns: _boundedInt(json['catalogColumns'], 0, 12, 0),
      animations: _boolean(json['animations'], true),
      autoPreview: _boolean(json['autoPreview'], false),
      playbackRate: playbackRates.contains(json['playbackRate'])
          ? (json['playbackRate'] as num).toDouble()
          : 1,
      volume: _bounded(json['volume'], 0, 100, 70),
      autoNext: _boolean(json['autoNext'], true),
      touchGestures: _boolean(json['touchGestures'], true),
      brightnessGestures: _boolean(json['brightnessGestures'], true),
      volumeGestures: _boolean(json['volumeGestures'], true),
      seekGestures: _boolean(json['seekGestures'], true),
      reconnectEnabled: _boolean(json['reconnectEnabled'], true),
      reconnectAttempts: _boundedInt(json['reconnectAttempts'], 0, 10, 3),
      reconnectDelaySeconds: _boundedInt(
        json['reconnectDelaySeconds'],
        1,
        30,
        3,
      ),
      pictureInPicture: _boolean(json['pictureInPicture'], true),
      landscapeFullscreen: _boolean(json['landscapeFullscreen'], true),
    );
  }

  Map<String, dynamic> toJson() => {
    'accent': accent,
    'posterScale': posterScale,
    'catalogColumns': catalogColumns,
    'animations': animations,
    'autoPreview': autoPreview,
    'playbackRate': playbackRate,
    'volume': volume,
    'autoNext': autoNext,
    'touchGestures': touchGestures,
    'brightnessGestures': brightnessGestures,
    'volumeGestures': volumeGestures,
    'seekGestures': seekGestures,
    'reconnectEnabled': reconnectEnabled,
    'reconnectAttempts': reconnectAttempts,
    'reconnectDelaySeconds': reconnectDelaySeconds,
    'pictureInPicture': pictureInPicture,
    'landscapeFullscreen': landscapeFullscreen,
  };

  static bool _boolean(Object? value, bool fallback) =>
      value is bool ? value : fallback;

  static int _boundedInt(Object? value, int min, int max, int fallback) =>
      value is int ? value.clamp(min, max) : fallback;

  static double _bounded(
    Object? value,
    double min,
    double max,
    double fallback,
  ) {
    if (value is! num || !value.isFinite) return fallback;
    return value.toDouble().clamp(min, max);
  }
}

@immutable
class WatchProgress {
  const WatchProgress({
    required this.positionSeconds,
    required this.durationSeconds,
    required this.lastWatched,
    this.completed = false,
  });

  final int positionSeconds;
  final int durationSeconds;
  final DateTime lastWatched;
  final bool completed;

  double get fraction => completed
      ? 1
      : durationSeconds <= 0
      ? 0
      : (positionSeconds / durationSeconds).clamp(0, 1);

  Map<String, dynamic> toJson() => {
    'positionSeconds': positionSeconds,
    'durationSeconds': durationSeconds,
    'lastWatched': lastWatched.toUtc().toIso8601String(),
    'completed': completed,
  };

  static WatchProgress? fromJson(Object? value) {
    if (value is! Map) return null;
    final position = value['positionSeconds'];
    final duration = value['durationSeconds'];
    final date = value['lastWatched'];
    if (position is! int || duration is! int || date is! String) return null;
    final parsedDate = DateTime.tryParse(date);
    if (parsedDate == null || position < 0 || duration < 0) return null;
    return WatchProgress(
      positionSeconds: duration == 0 ? position : position.clamp(0, duration),
      durationSeconds: duration,
      lastWatched: parsedDate,
      completed: value['completed'] == true,
    );
  }
}
