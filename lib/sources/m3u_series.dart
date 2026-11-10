import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../domain/internet_catalog.dart';
import '../domain/models.dart';

class M3uEpisodeHint {
  const M3uEpisodeHint({
    this.seriesTitle,
    this.providerTitle,
    this.season,
    this.episode,
    this.live = false,
    this.movie = false,
  });
  final String? seriesTitle;
  final String? providerTitle;
  final int? season;
  final int? episode;
  final bool live;
  final bool movie;
}

bool isM3uSeriesCategory(String category) =>
    RegExp(
      r'\b(?:s[eé]ries?|animes?|anim[eé]s?|shows?)\b',
      caseSensitive: false,
    ).hasMatch(category) &&
    !RegExp(
      r'\b(?:films?|movies?|cin[eé]ma)\b',
      caseSensitive: false,
    ).hasMatch(category);

final _seasonEpisode = RegExp(
  r'^(.*?)\bs(?:aison|eason)?\s*(\d{1,3})[\s._:–\-]*[eé](?:p(?:isode)?)?\s*(\d{1,4})(?=$|\D)(.*)$',
  caseSensitive: false,
);
final _crossEpisode = RegExp(
  r'^(.*?)\b(\d{1,3})\s*x\s*(\d{1,4})(?=$|\D)(.*)$',
  caseSensitive: false,
);
final _episodeOnly = RegExp(
  r'^(.*?)\b(?:[eé]pisode|episode|ep|e)[\s._:–\-]*(\d{1,4})(?=$|[\s._:–\-])(.*)$',
  caseSensitive: false,
);
final _numberedSeries = RegExp(r'^(.*?)\s+[-–|]\s*(\d{1,4})(?:\s*[-–|].*)?$');
final _categorySeason = RegExp(
  r'\b(?:saison|season)\s*\d+\b|\bS\d{1,3}\b',
  caseSensitive: false,
);

bool hasUngroupedM3uSeries(List<MediaItem> items) => items.any(
  (item) => item.seasons.isEmpty && _episodeIdentity(item, null) != null,
);

/// Groups only explicit episode patterns or entries declared as series. Film
/// collections and live channel duplicates never become an invented series.
List<MediaItem> groupM3uSeries(
  List<MediaItem> items, {
  Map<String, M3uEpisodeHint> hints = const {},
}) {
  final groups = <String, _SeriesGroup>{};
  final output = <Object>[];
  for (final item in items) {
    if (item.seasons.isNotEmpty) {
      output.add(item);
      continue;
    }
    final identity = _episodeIdentity(item, hints[item.id]);
    if (identity == null) {
      output.add(item);
      continue;
    }
    final category = internetTitleKey(
      item.category.replaceAll(_categorySeason, ' '),
    );
    final key =
        '${item.sourceId}|$category|${internetTitleKey(identity.title)}';
    var group = groups[key];
    if (group == null) {
      group = _SeriesGroup(item, identity.title, key);
      groups[key] = group;
      output.add(group);
    }
    group.entries.add((
      item: item,
      season: identity.season,
      episode: identity.episode,
    ));
  }
  return output
      .map(
        (entry) => entry is MediaItem ? entry : (entry as _SeriesGroup).build(),
      )
      .toList(growable: false);
}

({String title, int season, int? episode})? _episodeIdentity(
  MediaItem item,
  M3uEpisodeHint? hint,
) {
  if (hint?.live == true ||
      item.sourceId == null ||
      item.mediaUrl?.trim().isNotEmpty != true) {
    return null;
  }
  final path = Uri.tryParse(item.mediaUrl ?? '')?.path.toLowerCase() ?? '';
  final seriesCategory = isM3uSeriesCategory(item.category);
  final declared =
      item.kind == MediaKind.series ||
      path.contains('/series/') ||
      (seriesCategory &&
          item.kind == MediaKind.movie &&
          !path.contains('/movie/') &&
          hint?.movie != true);
  if (item.kind == MediaKind.live &&
      !declared &&
      !seriesCategory &&
      hint?.seriesTitle == null) {
    return null;
  }
  String? base;
  int? season = hint?.season;
  int? episode = hint?.episode;
  for (final name in [
    item.title,
    if (hint?.providerTitle != null) hint!.providerTitle!,
  ]) {
    final match =
        _seasonEpisode.firstMatch(name) ?? _crossEpisode.firstMatch(name);
    if (match != null && _cleanTitle(match[1]!).isNotEmpty) {
      base = _cleanTitle(match[1]!);
      season ??= int.parse(match[2]!);
      episode ??= int.parse(match[3]!);
      break;
    }
    final only = _episodeOnly.firstMatch(name);
    if (only != null && _cleanTitle(only[1]!).isNotEmpty) {
      base = _cleanTitle(only[1]!);
      episode ??= int.parse(only[2]!);
      break;
    }
    if (declared) {
      final numbered = _numberedSeries.firstMatch(name);
      if (numbered != null && _cleanTitle(numbered[1]!).isNotEmpty) {
        base = _cleanTitle(numbered[1]!);
        episode ??= int.parse(numbered[2]!);
        break;
      }
    }
  }
  base = hint?.seriesTitle?.trim().isNotEmpty == true
      ? hint!.seriesTitle!.trim()
      : base;
  if (base == null) {
    if (!declared && episode == null) return null;
    base = _cleanTitle(item.title);
  }
  if (internetTitleKey(base).isEmpty) return null;
  season ??=
      int.tryParse(
        RegExp(
              r'\b(?:saison|season|s)\s*(\d{1,3})\b',
              caseSensitive: false,
            ).firstMatch(item.category)?.group(1) ??
            '',
      ) ??
      1;
  return (title: base, season: season, episode: episode);
}

String _cleanTitle(String title) =>
    title.replaceAll(RegExp(r'[\s._:–\-|\[(]+$'), '').trim();

class _SeriesGroup {
  _SeriesGroup(this.first, this.title, this.key);
  final MediaItem first;
  final String title;
  final String key;
  final entries = <({MediaItem item, int season, int? episode})>[];

  MediaItem build() {
    final bySeason =
        <int, List<({MediaItem item, int season, int? episode})>>{};
    for (final entry in entries) {
      (bySeason[entry.season] ??= []).add(entry);
    }
    final seasons = <DemoSeason>[];
    for (final number in bySeason.keys.toList()..sort()) {
      final source = bySeason[number]!;
      final used = source.map((e) => e.episode).whereType<int>().toSet();
      var next = 1;
      final episodes = <DemoEpisode>[];
      for (final entry in source) {
        while (used.contains(next)) {
          next++;
        }
        final episodeNumber = entry.episode ?? next;
        used.add(episodeNumber);
        episodes.add(
          DemoEpisode(
            // Preserve old URL-based IDs, progress and history across migration.
            id: entry.item.id,
            title: entry.item.title,
            number: episodeNumber,
            durationMinutes: entry.item.durationMinutes,
            mediaUrl: entry.item.mediaUrl,
            posterUrl: entry.item.posterUrl,
            description: entry.item.description,
          ),
        );
      }
      final sorted = episodes.indexed.toList()
        ..sort((a, b) {
          final result = a.$2.number.compareTo(b.$2.number);
          return result == 0 ? a.$1.compareTo(b.$1) : result;
        });
      seasons.add(
        DemoSeason(
          number: number,
          episodes: sorted.map((e) => e.$2).toList(growable: false),
        ),
      );
    }
    return MediaItem(
      id: '${first.sourceId}:m3u-series:${sha256.convert(utf8.encode(key))}',
      title: title,
      kind: MediaKind.series,
      category: first.category,
      description: first.description,
      year: first.year,
      durationMinutes: 0,
      palette: first.palette,
      subtitle: first.subtitle,
      art: first.art,
      sourceId: first.sourceId,
      detailsLoaded: true,
      seasons: seasons,
      posterUrl: entries
          .map((e) => e.item.posterUrl)
          .whereType<String>()
          .where((u) => u.isNotEmpty)
          .firstOrNull,
    );
  }
}
