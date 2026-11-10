import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../domain/models.dart';
import '../domain/source_models.dart';
import 'm3u_series.dart';

/// Extended M3U parser. Quoted commas belong to attributes, not the title.
SourceCatalog parseM3u(String document, SourceConfig config, Uri base) {
  final text = document.replaceFirst('\ufeff', '');
  if (RegExp(
    r'^\s*#EXT-X-(?:TARGETDURATION|STREAM-INF|MEDIA-SEQUENCE):',
    multiLine: true,
  ).hasMatch(text)) {
    throw const SourceException(
      'Cette adresse est un flux HLS individuel. Utilisez « Ouvrir une URL vidéo » plutôt que l’import de playlist.',
    );
  }
  if (RegExp(
    r'^\s*<(?:!doctype\s+html|html)',
    caseSensitive: false,
  ).hasMatch(text)) {
    throw const SourceException(
      'Le serveur a renvoyé une page web, pas une playlist M3U.',
    );
  }
  final items = <String, MediaItem>{};
  final hints = <String, M3uEpisodeHint>{};
  Map<String, String> attributes = {};
  String? title;
  String group = '';
  String? epg;
  for (final raw in LineSplitter.split(text)) {
    final line = raw.trim();
    if (line.isEmpty) continue;
    if (line.startsWith('#EXTM3U')) {
      final values = _attributes(line.substring(7));
      final guide =
          values['x-tvg-url'] ?? values['url-tvg'] ?? values['tvg-url'];
      if (guide != null && guide.isNotEmpty) {
        // Several URLs may be listed. This version imports the first guide.
        epg = _mediaUri(guide.split(RegExp(r'[\s,]+')).first, base)?.toString();
      }
      continue;
    }
    if (line.startsWith('#EXTINF:')) {
      final body = line.substring(8);
      final comma = _outsideQuoteComma(body);
      attributes = _attributes(comma < 0 ? body : body.substring(0, comma));
      title = comma < 0 ? null : body.substring(comma + 1).trim();
      group = attributes['group-title'] ?? '';
      continue;
    }
    if (line.startsWith('#EXTGRP:')) {
      group = line.substring(8).trim();
      continue;
    }
    if (line.startsWith('#')) continue;
    final uri = _mediaUri(line, base);
    if (uri == null) {
      attributes = {};
      title = null;
      group = '';
      continue;
    }
    final url = uri.toString();
    final digest = sha256.convert(utf8.encode(url)).toString();
    final name = title?.isNotEmpty == true
        ? title!
        : attributes['tvg-name']?.trim();
    final kind = _kind(attributes, uri, group);
    final poster = attributes['tvg-logo'];
    final id = '${config.id}:m3u:$digest';
    int? number(List<String> keys) {
      for (final key in keys) {
        final value = int.tryParse(attributes[key] ?? '');
        if (value != null && value >= 0) return value;
      }
      return null;
    }

    hints[id] = M3uEpisodeHint(
      seriesTitle:
          attributes['series-name'] ??
          attributes['series-title'] ??
          attributes['tvg-series'] ??
          attributes['show-name'],
      providerTitle: attributes['tvg-name'],
      season: number(['season', 'season-number', 'tvg-season']),
      episode: number([
        'episode',
        'episode-num',
        'episode-number',
        'tvg-episode',
      ]),
      live: ['live', 'tv'].contains(
        (attributes['tvg-type'] ?? attributes['type'] ?? '').toLowerCase(),
      ),
      movie: ['movie', 'vod', 'film', 'video'].contains(
        (attributes['tvg-type'] ?? attributes['type'] ?? '').toLowerCase(),
      ),
    );
    items[id] = MediaItem(
      id: id,
      title: name?.isNotEmpty == true ? name! : 'Média ${items.length + 1}',
      kind: kind,
      category: group.isEmpty ? 'Sans catégorie' : group,
      description: '',
      year: 0,
      durationMinutes: 0,
      palette: 0xff6671a8,
      subtitle: config.name,
      art: int.parse(digest.substring(0, 4), radix: 16),
      mediaUrl: url,
      sourceId: config.id,
      tvgId: attributes['tvg-id'],
      posterUrl: poster == null ? null : _mediaUri(poster, base)?.toString(),
      detailsLoaded: true,
    );
    attributes = {};
    title = null;
    group = '';
  }
  if (items.isEmpty) {
    throw const SourceException(
      'Aucun média compatible trouvé dans cette playlist. Vérifiez le fichier ou l’adresse M3U.',
    );
  }
  return SourceCatalog(
    items: groupM3uSeries(items.values.toList(growable: false), hints: hints),
    suggestedEpgUrl: epg,
  );
}

int _outsideQuoteComma(String value) {
  String? quote;
  for (var i = 0; i < value.length; i++) {
    final char = value[i];
    if (quote != null) {
      if (char == quote && (i == 0 || value[i - 1] != '\\')) quote = null;
    } else if (char == '"' || char == "'") {
      quote = char;
    } else if (char == ',') {
      return i;
    }
  }
  return -1;
}

Map<String, String> _attributes(String value) {
  final pattern = RegExp(
    r'''([\w-]+)\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s]+))''',
  );
  return {
    for (final match in pattern.allMatches(value))
      match[1]!.toLowerCase(): match[2] ?? match[3] ?? match[4] ?? '',
  };
}

Uri? _mediaUri(String value, Uri base) {
  if (value.trim().isEmpty) return null;
  try {
    if (base.scheme == 'file' &&
        RegExp(r'^(?:[A-Za-z]:[\\/]|\\\\)').hasMatch(value.trim())) {
      return Uri.file(value.trim(), windows: true);
    }
    final uri = base.resolve(value.trim());
    if (![
      'http',
      'https',
      'file',
      'udp',
      'rtp',
    ].contains(uri.scheme.toLowerCase())) {
      return null;
    }
    // Remote playlists must not grant local filesystem access implicitly.
    if (uri.scheme == 'file' && base.scheme != 'file') return null;
    return uri;
  } on FormatException {
    return null;
  }
}

MediaKind _kind(Map<String, String> attributes, Uri uri, String group) {
  final type = (attributes['tvg-type'] ?? attributes['type'] ?? '')
      .toLowerCase();
  if (['series', 'serie', 'série'].contains(type)) return MediaKind.series;
  if (['movie', 'vod', 'film', 'video'].contains(type)) return MediaKind.movie;
  if (type == 'live' || type == 'tv') return MediaKind.live;
  final path = uri.path.toLowerCase();
  if (path.contains('/series/')) return MediaKind.series;
  if (path.contains('/movie/')) return MediaKind.movie;
  if (isM3uSeriesCategory(group)) return MediaKind.series;
  if (RegExp(r'\.(?:mp4|mkv|avi|mov|webm|m4v)$').hasMatch(path)) {
    return MediaKind.movie;
  }
  final category = group.toLowerCase();
  if (RegExp(r'\b(?:films?|movies?|vod)\b').hasMatch(category)) {
    return MediaKind.movie;
  }
  return MediaKind.live;
}
