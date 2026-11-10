import 'models.dart';

class InternetTitle {
  const InternetTitle({
    required this.id,
    required this.title,
    required this.kind,
    this.year = 0,
    this.description = '',
    this.posterUrl,
    this.aliases = const [],
  });
  final String id;
  final String title;
  final MediaKind kind;
  final int year;
  final String description;
  final String? posterUrl;
  final List<String> aliases;

  static InternetTitle? parse(Object? raw, MediaKind kind) {
    if (raw is! Map) return null;
    final id = raw['imdb_id'] ?? raw['id'];
    final name = raw['name'];
    if (id is! String ||
        !RegExp(r'^tt\d{5,12}$').hasMatch(id) ||
        name is! String ||
        name.trim().isEmpty ||
        name.length > 500) {
      return null;
    }
    if (raw['type'] != null && raw['type'] != kind.name) return null;
    final release = '${raw['releaseInfo'] ?? raw['year'] ?? ''}';
    final year =
        int.tryParse(RegExp(r'^\d{4}').firstMatch(release)?.group(0) ?? '') ??
        0;
    final poster = Uri.tryParse(raw['poster'] is String ? raw['poster'] : '');
    const posterHosts = {
      'images.justwatch.com',
      'images.metahub.space',
      'live.metahub.space',
      'image.tmdb.org',
    };
    final embeddedId =
        poster != null &&
            {'images.metahub.space', 'live.metahub.space'}.contains(poster.host)
        ? RegExp(r'tt\d{5,12}').firstMatch(poster.path)?.group(0)
        : null;
    return InternetTitle(
      id: id,
      title: name.trim(),
      kind: kind,
      year: year,
      description: raw['description'] is String
          ? (raw['description'] as String).substring(
              0,
              (raw['description'] as String).length.clamp(0, 12000),
            )
          : '',
      posterUrl:
          poster != null &&
              poster.scheme == 'https' &&
              poster.userInfo.isEmpty &&
              (embeddedId == null || embeddedId == id) &&
              posterHosts.contains(poster.host)
          ? poster.toString()
          : null,
      aliases: [
        if (raw['aliases'] is List)
          ...(raw['aliases'] as List)
              .whereType<String>()
              .where((s) => s.length <= 500)
              .take(20),
      ],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': title,
    'type': kind.name,
    'year': year,
    'description': description,
    'poster': posterUrl,
    'aliases': aliases,
  };

  MediaItem get artworkItem => MediaItem(
    id: 'internet-${kind.name}-$id',
    title: title,
    kind: kind,
    category: 'Découverte internet',
    description: description,
    year: year,
    durationMinutes: 0,
    palette: 0xff6752eb,
    subtitle: '',
    art: 0,
    posterUrl: posterUrl,
    sourceId: 'internet-discovery',
    detailsLoaded: true,
  );
}

String internetTitleKey(String title) {
  var value = title
      .toLowerCase()
      .trim()
      .replaceAll(
        RegExp(
          r'^\s*(?:\[(?:fr|en|vf|vff|vostfr|4k|hd|fhd|uhd)\]\s*)+',
          caseSensitive: false,
        ),
        '',
      )
      .replaceAll(RegExp(r'\s*[\[(](?:19|20)\d{2}[\])]\s*$'), '')
      .replaceAll(
        RegExp(r'\s+(?:4k|uhd|fhd|hd|1080p|2160p|vff|vf|vostfr|multi)\s*$'),
        '',
      );
  // Provider tags may follow the year, or appear more than once.
  var previous = '';
  while (previous != value) {
    previous = value;
    value = value
        .replaceAll(
          RegExp(
            r'\s*[\[(](?:4k|uhd|fhd|hd|1080p|2160p|vff|vf|vostfr|multi)[\])]\s*$',
          ),
          '',
        )
        .replaceAll(RegExp(r'\s*[\[(](?:19|20)\d{2}[\])]\s*$'), '')
        .replaceAll(
          RegExp(r'\s+(?:4k|uhd|fhd|hd|1080p|2160p|vff|vf|vostfr|multi)\s*$'),
          '',
        )
        .trim();
  }
  const accents = {
    'à': 'a',
    'â': 'a',
    'ä': 'a',
    'é': 'e',
    'è': 'e',
    'ê': 'e',
    'ë': 'e',
    'î': 'i',
    'ï': 'i',
    'ô': 'o',
    'ö': 'o',
    'ù': 'u',
    'û': 'u',
    'ü': 'u',
    'ç': 'c',
    'œ': 'oe',
  };
  for (final entry in accents.entries) {
    value = value.replaceAll(entry.key, entry.value);
  }
  return value.replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ').trim();
}

/// Conservative identity: no fuzzy/substring matches between unrelated titles.
int mediaIdentityYear(MediaItem item) => item.year > 0
    ? item.year
    : int.tryParse(
            RegExp(r'[\[(]((?:19|20)\d{2})[\])]')
                    .firstMatch(item.title)
                    ?.group(1) ??
                '',
          ) ??
          0;

bool sameInternetTitle(MediaItem item, InternetTitle title) =>
    item.kind == title.kind &&
    internetTitleKey(item.title).isNotEmpty &&
    (mediaIdentityYear(item) <= 0 ||
        title.year <= 0 ||
        mediaIdentityYear(item) == title.year) &&
    [
      title.title,
      ...title.aliases,
    ].any((name) => internetTitleKey(item.title) == internetTitleKey(name));
