import 'dart:collection';

import 'package:flutter/foundation.dart';

import 'models.dart';

enum CatalogOrder { source, titleAsc, titleDesc, yearDesc, category }

const catalogLanguageCodes = <String>[
  'fr',
  'en',
  'es',
  'ar',
  'de',
  'it',
  'pt',
  'tr',
  'ru',
  'nl',
  'pl',
  'ro',
  'hi',
  'zh',
  'ja',
  'ko',
  'el',
  'he',
  'uk',
  'sv',
  'no',
  'da',
  'fi',
  'hu',
  'cs',
  'bg',
  'id',
  'vi',
  'th',
  'unknown',
];

const _maxCategories = 20000;
const _maxCategoryKeyLength = 4096;

@immutable
class CatalogRule {
  const CatalogRule({
    Set<String> hiddenLanguages = const {},
    Set<String> hiddenCategories = const {},
    List<String> categoryOrder = const [],
    Map<String, String> languageOverrides = const {},
    this.order = CatalogOrder.source,
    // Preserve public argument names while keeping collections read-only.
    // ignore: prefer_initializing_formals
  }) : _hiddenLanguages = hiddenLanguages,
       // ignore: prefer_initializing_formals
       _hiddenCategories = hiddenCategories,
       // ignore: prefer_initializing_formals
       _categoryOrder = categoryOrder,
       // ignore: prefer_initializing_formals
       _languageOverrides = languageOverrides;

  final Set<String> _hiddenLanguages;
  final Set<String> _hiddenCategories;
  final List<String> _categoryOrder;
  final Map<String, String> _languageOverrides;
  final CatalogOrder order;

  Set<String> get hiddenLanguages => UnmodifiableSetView(_hiddenLanguages);
  Set<String> get hiddenCategories => UnmodifiableSetView(_hiddenCategories);
  List<String> get categoryOrder => UnmodifiableListView(_categoryOrder);
  Map<String, String> get languageOverrides =>
      UnmodifiableMapView(_languageOverrides);

  CatalogRule copyWith({
    Set<String>? hiddenLanguages,
    Set<String>? hiddenCategories,
    List<String>? categoryOrder,
    Map<String, String>? languageOverrides,
    CatalogOrder? order,
  }) => CatalogRule.fromJson({
    'hiddenLanguages': (hiddenLanguages ?? _hiddenLanguages).toList(),
    'hiddenCategories': (hiddenCategories ?? _hiddenCategories).toList(),
    'categoryOrder': categoryOrder ?? _categoryOrder,
    'languageOverrides': languageOverrides ?? _languageOverrides,
    'order': (order ?? this.order).name,
  });

  Map<String, dynamic> toJson() => {
    'hiddenLanguages': _hiddenLanguages.toList(),
    'hiddenCategories': _hiddenCategories.toList(),
    'categoryOrder': _categoryOrder.toList(),
    'languageOverrides': Map<String, String>.of(_languageOverrides),
    'order': order.name,
  };

  factory CatalogRule.fromJson(Object? value) {
    if (value is! Map) return const CatalogRule();
    final overrides = <String, String>{};
    final rawOverrides = value['languageOverrides'];
    if (rawOverrides is Map) {
      for (final entry in rawOverrides.entries.take(_maxCategories)) {
        if (_isCategoryKey(entry.key) && _isLanguage(entry.value)) {
          overrides[entry.key as String] = entry.value as String;
        }
      }
    }
    return CatalogRule(
      hiddenLanguages: Set.unmodifiable(
        _strings(
          value['hiddenLanguages'],
          catalogLanguageCodes.length,
        ).where(_isLanguage),
      ),
      hiddenCategories: Set.unmodifiable(
        _strings(
          value['hiddenCategories'],
          _maxCategories,
        ).where(_isCategoryKey),
      ),
      categoryOrder: List.unmodifiable(
        _strings(
          value['categoryOrder'],
          _maxCategories,
        ).where(_isCategoryKey).toSet(),
      ),
      languageOverrides: Map.unmodifiable(overrides),
      order: CatalogOrder.values.firstWhere(
        (order) => order.name == value['order'],
        orElse: () => CatalogOrder.source,
      ),
    );
  }
}

@immutable
class CatalogPreferences {
  const CatalogPreferences({Map<MediaKind, CatalogRule> rules = const {}})
    // ignore: prefer_initializing_formals
    : _rules = rules;

  final Map<MediaKind, CatalogRule> _rules;

  CatalogRule ruleFor(MediaKind kind) => _rules[kind] ?? const CatalogRule();

  CatalogPreferences copyWithRule(MediaKind kind, CatalogRule rule) =>
      CatalogPreferences(
        rules: Map.unmodifiable({
          ..._rules,
          kind: CatalogRule.fromJson(rule.toJson()),
        }),
      );

  Map<String, dynamic> toJson() => {
    'rules': {
      for (final kind in MediaKind.values) kind.name: ruleFor(kind).toJson(),
    },
  };

  factory CatalogPreferences.fromJson(Object? value) {
    if (value is! Map || value['rules'] is! Map) {
      return const CatalogPreferences();
    }
    final rules = value['rules'] as Map;
    return CatalogPreferences(
      rules: Map.unmodifiable({
        for (final kind in MediaKind.values)
          kind: CatalogRule.fromJson(rules[kind.name]),
      }),
    );
  }
}

Iterable<String> _strings(Object? value, int limit) =>
    value is List ? value.take(limit).whereType<String>() : const <String>[];

bool _isCategoryKey(Object? value) =>
    value is String &&
    value.isNotEmpty &&
    value.length <= _maxCategoryKeyLength;
bool _isLanguage(Object? value) => catalogLanguageCodes.contains(value);

/// Uses only the opaque source ID and catalogue metadata, never stream URLs.
/// Escaping separators avoids collisions between provider/category names.
String catalogCategoryKey(MediaItem item) =>
    '${Uri.encodeComponent(item.sourceId ?? 'demo')}|${item.kind.name}|'
    '${Uri.encodeComponent(item.category)}';

String catalogLanguageLabel(String code) => switch (code) {
  'fr' => 'Français',
  'en' => 'Anglais',
  'es' => 'Espagnol',
  'ar' => 'Arabe',
  'de' => 'Allemand',
  'it' => 'Italien',
  'pt' => 'Portugais',
  'tr' => 'Turc',
  'ru' => 'Russe',
  'nl' => 'Néerlandais',
  'pl' => 'Polonais',
  'ro' => 'Roumain',
  'hi' => 'Hindi',
  'zh' => 'Chinois',
  'ja' => 'Japonais',
  'ko' => 'Coréen',
  'el' => 'Grec',
  'he' => 'Hébreu',
  'uk' => 'Ukrainien',
  'sv' => 'Suédois',
  'no' => 'Norvégien',
  'da' => 'Danois',
  'fi' => 'Finnois',
  'hu' => 'Hongrois',
  'cs' => 'Tchèque',
  'bg' => 'Bulgare',
  'id' => 'Indonésien',
  'vi' => 'Vietnamien',
  'th' => 'Thaï',
  _ => 'Non renseignée',
};

/// Indicative detection from provider labels, not an analysis of audio tracks.
/// Unlabelled or ambiguous media stay 'unknown'; a category override takes
/// precedence and can correct inconsistent provider metadata.
String inferCatalogLanguage(
  MediaItem item, {
  Map<String, String> overrides = const {},
}) {
  final override = overrides[catalogCategoryKey(item)];
  if (_isLanguage(override)) return override!;
  final category = _categoryLanguage(item.category);
  if (category != 'unknown') return category;
  return _titleLanguage(item.title);
}

const _tagLanguages = <String, String>{
  'fr': 'fr', 'fra': 'fr', 'fre': 'fr', 'vf': 'fr',
  'en': 'en', 'eng': 'en', 'us': 'en', 'usa': 'en', 'uk': 'en',
  'es': 'es', 'esp': 'es', 'spa': 'es',
  'ar': 'ar', 'ara': 'ar', 'arab': 'ar',
  'de': 'de', 'deu': 'de', 'ger': 'de',
  'it': 'it', 'ita': 'it', 'pt': 'pt', 'por': 'pt', 'br': 'pt',
  'tr': 'tr', 'tur': 'tr', 'ru': 'ru', 'rus': 'ru',
  'nl': 'nl', 'nld': 'nl', 'dut': 'nl', 'pl': 'pl', 'pol': 'pl',
  'ro': 'ro', 'ron': 'ro', 'rum': 'ro', 'hi': 'hi', 'hin': 'hi',
  'zh': 'zh', 'zho': 'zh', 'chi': 'zh', 'cn': 'zh',
  'ja': 'ja', 'jpn': 'ja', 'jp': 'ja',
  'ko': 'ko', 'kor': 'ko', 'kr': 'ko',
  'el': 'el', 'ell': 'el', 'gre': 'el', 'gr': 'el',
  'he': 'he', 'heb': 'he', 'il': 'he',
  'ua': 'uk', 'ukr': 'uk', // UK country tag means English; UA Ukrainian.
  'sv': 'sv', 'swe': 'sv', 'se': 'sv',
  'no': 'no', 'nor': 'no', 'da': 'da', 'dan': 'da', 'dk': 'da',
  'fi': 'fi', 'fin': 'fi', 'hu': 'hu', 'hun': 'hu',
  'cs': 'cs', 'ces': 'cs', 'cze': 'cs', 'cz': 'cs',
  'bg': 'bg', 'bul': 'bg', 'id': 'id', 'ind': 'id',
  'vi': 'vi', 'vie': 'vi', 'vn': 'vi', 'th': 'th', 'tha': 'th',
};

const _languageWords = <String, String>{
  'francais': 'fr',
  'francaise': 'fr',
  'french': 'fr',
  'france': 'fr',
  'anglais': 'en',
  'english': 'en',
  'america': 'en',
  'american': 'en',
  'united kingdom': 'en',
  'united states': 'en',
  'espagnol': 'es',
  'spanish': 'es',
  'spain': 'es',
  'espana': 'es',
  'arabe': 'ar',
  'arabic': 'ar',
  'arab': 'ar',
  'allemand': 'de',
  'german': 'de',
  'germany': 'de',
  'deutsch': 'de',
  'italien': 'it',
  'italian': 'it',
  'italy': 'it',
  'italia': 'it',
  'portugais': 'pt',
  'portuguese': 'pt',
  'portugal': 'pt',
  'brazil': 'pt',
  'turc': 'tr',
  'turkish': 'tr',
  'turkey': 'tr',
  'russe': 'ru',
  'russian': 'ru',
  'russia': 'ru',
  'neerlandais': 'nl',
  'dutch': 'nl',
  'netherlands': 'nl',
  'polonais': 'pl',
  'polish': 'pl',
  'poland': 'pl',
  'roumain': 'ro',
  'romanian': 'ro',
  'romania': 'ro',
  'hindi': 'hi',
  'chinois': 'zh',
  'chinese': 'zh',
  'china': 'zh',
  'japonais': 'ja',
  'japanese': 'ja',
  'japan': 'ja',
  'coreen': 'ko',
  'korean': 'ko',
  'korea': 'ko',
  'grec': 'el',
  'greek': 'el',
  'greece': 'el',
  'hebreu': 'he',
  'hebrew': 'he',
  'israel': 'he',
  'ukrainien': 'uk',
  'ukrainian': 'uk',
  'ukraine': 'uk',
  'suedois': 'sv',
  'swedish': 'sv',
  'sweden': 'sv',
  'norvegien': 'no',
  'norwegian': 'no',
  'norway': 'no',
  'danois': 'da',
  'danish': 'da',
  'denmark': 'da',
  'finnois': 'fi',
  'finnish': 'fi',
  'finland': 'fi',
  'hongrois': 'hu',
  'hungarian': 'hu',
  'hungary': 'hu',
  'tcheque': 'cs',
  'czech': 'cs',
  'czechia': 'cs',
  'bulgare': 'bg',
  'bulgarian': 'bg',
  'bulgaria': 'bg',
  'indonesien': 'id',
  'indonesian': 'id',
  'indonesia': 'id',
  'vietnamien': 'vi',
  'vietnamese': 'vi',
  'vietnam': 'vi',
  'thai': 'th',
  'thailand': 'th',
};

String _categoryLanguage(String value) {
  final text = _normalize(value);
  final words = text.split(RegExp(r'[^a-z0-9]+'));
  final found = <String>{};
  for (final word in words) {
    final code = _languageWords[word];
    if (code != null) found.add(code);
  }
  for (final phrase in const ['united kingdom', 'united states']) {
    if (text.contains(phrase)) found.add('en');
  }
  final explicitTag = _titleLanguage(value);
  if (explicitTag != 'unknown') found.add(explicitTag);
  final wholeTag = _tagLanguages[text];
  if (wholeTag != null) found.add(wholeTag);
  final leadingTag = RegExp(r'^\s*([A-Z]{2,4})\s+').firstMatch(value);
  if (leadingTag != null) {
    final code = _tagLanguages[leadingTag.group(1)!.toLowerCase()];
    if (code != null) found.add(code);
  }
  final trailingTag = RegExp(r'[|:/-]\s*([A-Za-z]{2,4})\s*$').firstMatch(value);
  if (trailingTag != null) {
    final code = _tagLanguages[trailingTag.group(1)!.toLowerCase()];
    if (code != null) found.add(code);
  }
  return found.length == 1 ? found.single : 'unknown';
}

final _bracketTag = RegExp(r'[\[(]([A-Za-z]{2,4})[\])]');
final _prefixTag = RegExp(r'^\s*([A-Za-z]{2,4})\s*[:|/]');
final _hyphenTag = RegExp(r'^\s*([A-Z]{2,4})\s+-\s+');

String _titleLanguage(String title) {
  final tags = <String>[
    for (final match in _bracketTag.allMatches(title)) match.group(1)!,
    if (_prefixTag.firstMatch(title) case final match?) match.group(1)!,
    if (_hyphenTag.firstMatch(title) case final match?) match.group(1)!,
  ];
  final found = tags
      .map((tag) => _tagLanguages[tag.toLowerCase()])
      .whereType<String>()
      .toSet();
  return found.length == 1 ? found.single : 'unknown';
}

/// Sort each media kind independently while keeping its positions in a mixed
/// catalogue. Equal sort keys preserve the incoming provider order.
List<MediaItem> applyCatalogPreferences(
  List<MediaItem> items,
  CatalogPreferences preferences,
) {
  final visible = <MediaItem>[];
  final rules = {
    for (final kind in MediaKind.values) kind: preferences.ruleFor(kind),
  };
  final categoryLanguages = <String, String>{};
  for (final item in items) {
    final rule = rules[item.kind]!;
    if (rule.hiddenCategories.isNotEmpty &&
        rule.hiddenCategories.contains(catalogCategoryKey(item))) {
      continue;
    }
    if (rule.hiddenLanguages.isNotEmpty) {
      final override = rule.languageOverrides.isEmpty
          ? null
          : rule.languageOverrides[catalogCategoryKey(item)];
      final category = categoryLanguages.putIfAbsent(
        item.category,
        () => _categoryLanguage(item.category),
      );
      final language = _isLanguage(override)
          ? override!
          : category == 'unknown'
          ? _titleLanguage(item.title)
          : category;
      if (rule.hiddenLanguages.contains(language)) continue;
    }
    visible.add(item);
  }
  final sortedByKind = <MediaKind, Iterator<MediaItem>>{};
  for (final kind in MediaKind.values) {
    final rule = preferences.ruleFor(kind);
    if (rule.order == CatalogOrder.source) continue;
    final indexed = [
      for (var i = 0; i < visible.length; i++)
        if (visible[i].kind == kind) (item: visible[i], index: i),
    ];
    final categoryRanks = {
      for (var i = 0; i < rule.categoryOrder.length; i++)
        rule.categoryOrder[i]: i,
    };
    final titles = <String, String>{};
    final categoryKeys = <(String?, String), String>{};
    final categoryNames = <String, String>{};
    String title(MediaItem item) =>
        titles.putIfAbsent(item.id, () => _normalize(item.title));
    String categoryKey(MediaItem item) => categoryKeys.putIfAbsent((
      item.sourceId,
      item.category,
    ), () => catalogCategoryKey(item));
    String categoryName(MediaItem item) => categoryNames.putIfAbsent(
      item.category,
      () => _normalize(item.category),
    );
    int compare(MediaItem a, MediaItem b) {
      switch (rule.order) {
        case CatalogOrder.source:
          return 0;
        case CatalogOrder.titleAsc:
          return title(a).compareTo(title(b));
        case CatalogOrder.titleDesc:
          return title(b).compareTo(title(a));
        case CatalogOrder.yearDesc:
          final years = (b.year > 0 ? b.year : -1).compareTo(
            a.year > 0 ? a.year : -1,
          );
          return years != 0 ? years : title(a).compareTo(title(b));
        case CatalogOrder.category:
          final keyA = categoryKey(a);
          final keyB = categoryKey(b);
          final rankA = categoryRanks[keyA] ?? categoryRanks.length;
          final rankB = categoryRanks[keyB] ?? categoryRanks.length;
          final rank = rankA.compareTo(rankB);
          if (rank != 0) return rank;
          if (keyA != keyB) {
            final category = categoryName(a).compareTo(categoryName(b));
            if (category != 0) return category;
            return keyA.compareTo(keyB);
          }
          return title(a).compareTo(title(b));
      }
    }

    indexed.sort((a, b) {
      final comparison = compare(a.item, b.item);
      return comparison != 0 ? comparison : a.index.compareTo(b.index);
    });
    sortedByKind[kind] = indexed.map((entry) => entry.item).iterator;
  }
  return List.unmodifiable(
    visible.map((item) {
      final sorted = sortedByKind[item.kind];
      if (sorted == null) return item;
      sorted.moveNext();
      return sorted.current;
    }),
  );
}

String _normalize(String text) {
  const accents = <String, String>{
    'à': 'a',
    'á': 'a',
    'â': 'a',
    'ä': 'a',
    'ã': 'a',
    'å': 'a',
    'æ': 'ae',
    'ç': 'c',
    'è': 'e',
    'é': 'e',
    'ê': 'e',
    'ë': 'e',
    'ì': 'i',
    'í': 'i',
    'î': 'i',
    'ï': 'i',
    'ñ': 'n',
    'ò': 'o',
    'ó': 'o',
    'ô': 'o',
    'ö': 'o',
    'õ': 'o',
    'œ': 'oe',
    'ù': 'u',
    'ú': 'u',
    'û': 'u',
    'ü': 'u',
    'ý': 'y',
    'ÿ': 'y',
  };
  final lower = text.trim().toLowerCase();
  return lower.split('').map((letter) => accents[letter] ?? letter).join();
}
