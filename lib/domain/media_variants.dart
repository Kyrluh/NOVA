import 'models.dart';

final _variantTag = RegExp(
  r'^(?:VF|VFF|VFQ|VOSTFR|VOST|VO|MULTI|FR|FRENCH|EN|ENG|ENGLISH|ES|ESP|SPANISH|DE|GER|GERMAN|AR|ARA|ITALIAN|4K|UHD|FHD|HD|SD|2160P|1080P|720P|480P|HDR(?:10)?|DOLBY VISION|HEVC|H[ .]?26[45]|X26[45]|BLU[ -]?RAY|WEB[ -]?DL|WEBRIP|REMUX)$',
  caseSensitive: false,
);

String variantTitle(String title) {
  var result = title.replaceAllMapped(RegExp(r'\[([^\]]+)\]|\(([^)]+)\)'), (
    match,
  ) {
    final value = (match[1] ?? match[2]!).trim();
    final words = value.split(RegExp(r'\s*[/|,;+]\s*|\s+'));
    return _variantTag.hasMatch(value) || words.every(_variantTag.hasMatch)
        ? ' '
        : match[0]!;
  });
  final tokens = result.split(RegExp(r'\s*[|:]\s*|\s+-\s+|\s+'));
  while (tokens.isNotEmpty && _variantTag.hasMatch(tokens.first)) {
    tokens.removeAt(0);
  }
  while (tokens.isNotEmpty && _variantTag.hasMatch(tokens.last)) {
    tokens.removeLast();
  }
  result = tokens.join(' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  return result.isEmpty ? title : result;
}

int variantYear(MediaItem item) => item.year > 0
    ? item.year
    : int.tryParse(
            RegExp(r'(?:\s|[\(\[])((?:19|20)\d{2})[\)\]]?\s*$')
                    .firstMatch(variantTitle(item.title))?[1] ??
                '',
          ) ??
          0;

String variantIdentity(MediaItem item) {
  if (item.kind == MediaKind.live ||
      item.sourceId == null ||
      variantYear(item) == 0) {
    return 'id:${item.id}';
  }
  final title = variantTitle(item.title)
      .toLowerCase()
      .replaceAll(RegExp('[\\(\\[]${variantYear(item)}[\\)\\]]'), '')
      .replaceAll(RegExp('\\s${variantYear(item)}\$'), '')
      .replaceAll(RegExp(r'[^a-z0-9à-ÿ]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return '${item.sourceId}|${item.kind.name}|${variantYear(item)}|$title';
}

/// Only presentation is grouped: source IDs and individual progress stay intact.
class VariantCatalog {
  VariantCatalog(Iterable<MediaItem> items) {
    for (final item in items) {
      (groups[variantIdentity(item)] ??= []).add(item);
    }
    for (final group in groups.values) {
      final representative = group.first;
      final dates = group.map((i) => i.addedAt).whereType<DateTime>().toList()
        ..sort();
      cards.add(
        group.length == 1
            ? representative
            : representative.copyWith(
                title: variantTitle(representative.title),
                addedAt: dates.lastOrNull,
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
