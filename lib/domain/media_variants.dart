import 'models.dart';

final _variantTag = RegExp(
  r'^(?:VF|VFF|VFQ|VOSTFR|VOST|VO|MULTI|FR|FRENCH|EN|ENG|ENGLISH|ES|ESP|SPANISH|DE|GER|GERMAN|AR|ARA|ITALIAN|4K|UHD|FHD|HD|SD|2160P|1080P|720P|480P|HDR(?:10)?|DOLBY VISION|HEVC|H[ .]?26[45]|X26[45]|BLU[ -]?RAY|WEB[ -]?DL|WEBRIP|REMUX)$',
  caseSensitive: false,
);
final _bracketedTags = RegExp(r'\[([^\]]+)\]|\(([^)]+)\)');
final _tagWords = RegExp(r'\s*[/|,;+]\s*|\s+');
final _titleTokens = RegExp(r'\s*[|:]\s*|\s+-\s+|\s+');
final _spaces = RegExp(r'\s+');
final _endingYear = RegExp(r'(?:\s|[\(\[])((?:19|20)\d{2})[\)\]]?\s*$');
final _bracketedYear = RegExp(r'[\(\[]((?:19|20)\d{2})[\)\]]');
final _identityCharacters = RegExp(r'[^a-z0-9à-ÿ]');

String variantTitle(String title) {
  var result = title.replaceAllMapped(_bracketedTags, (match) {
    final value = (match[1] ?? match[2]!).trim();
    final words = value.split(_tagWords);
    return _variantTag.hasMatch(value) || words.every(_variantTag.hasMatch)
        ? ' '
        : match[0]!;
  });
  final tokens = result.split(_titleTokens);
  while (tokens.isNotEmpty && _variantTag.hasMatch(tokens.first)) {
    tokens.removeAt(0);
  }
  while (tokens.isNotEmpty && _variantTag.hasMatch(tokens.last)) {
    tokens.removeLast();
  }
  result = tokens.join(' ').replaceAll(_spaces, ' ').trim();
  return result.isEmpty ? title : result;
}

int variantYear(MediaItem item) => item.year > 0
    ? item.year
    : int.tryParse(
            _endingYear.firstMatch(variantTitle(item.title))?[1] ?? '',
          ) ??
          0;

String variantIdentity(MediaItem item) {
  if (item.kind == MediaKind.live || item.sourceId == null) {
    return 'id:${item.id}';
  }
  final normalized = variantTitle(item.title);
  final year = item.year > 0
      ? item.year
      : int.tryParse(_endingYear.firstMatch(normalized)?[1] ?? '') ?? 0;
  if (year == 0) return 'id:${item.id}';
  var title = normalized.toLowerCase().replaceAllMapped(
    _bracketedYear,
    (match) => match[1] == '$year' ? '' : match[0]!,
  );
  if (title.endsWith(' $year')) title = title.substring(0, title.length - 5);
  title = title
      .replaceAll(_identityCharacters, ' ')
      .replaceAll(_spaces, ' ')
      .trim();
  return '${item.sourceId}|${item.kind.name}|$year|$title';
}

/// Only presentation is grouped: source IDs and individual progress stay intact.
class VariantCatalog {
  VariantCatalog(Iterable<MediaItem> items) {
    // Corrupt/legacy playlists may repeat IDs; a selector must never repeat one.
    for (final item in {for (final item in items) item.id: item}.values) {
      (groups[variantIdentity(item)] ??= []).add(item);
    }
    for (final group in groups.values) {
      final representative = group.first;
      DateTime? latest;
      if (group.length > 1) {
        for (final item in group) {
          final date = item.addedAt;
          if (date != null && (latest == null || date.isAfter(latest))) {
            latest = date;
          }
        }
      }
      cards.add(
        group.length == 1
            ? representative
            : representative.copyWith(
                title: variantTitle(representative.title),
                addedAt: latest,
              ),
      );
      for (final item in group) {
        byId[item.id] = group;
      }
    }
  }
  final Map<String, List<MediaItem>> groups = {};
  final Map<String, List<MediaItem>> byId = {};
  final List<MediaItem> cards = [];
}

String variantLabel(MediaItem item) => '${item.title} · ${item.category}';
