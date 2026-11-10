import 'dart:collection';

import 'models.dart';

enum CatalogPlatform {
  netflix('Netflix', 'netflix', 0xffe50914),
  primeVideo('Prime Video', 'amazon-prime', 0xff00a8e1),
  disneyPlus('Disney+', 'disney-plus', 0xff087e8b),
  appleTv('Apple TV+', 'apple-tv-plus-light', 0xffb8bdca),
  hbo('HBO / Max', 'hbo-light', 0xff6752eb),
  paramountPlus('Paramount+', 'paramount-plus-light', 0xff3478ff),
  crunchyroll('Crunchyroll', 'crunchyroll', 0xfff47521),
  hulu('Hulu', 'hulu', 0xff1ce783),
  peacock('Peacock', 'peacock-light', 0xffd0b75a),
  canalPlus('CANAL+', '', 0xffeeeeee),
  starz('STARZ', '', 0xffc7b092),
  ocs('OCS', '', 0xfff29a38),
  variety('VARIETY', '', 0xffd04260),
  frenchTv('TF1+ | M6+ | FTV', '', 0xff5189e8),
  documentaries('DOCUMENTAIRES', '', 0xff4db89a),
  reality('ÉMISSION / REALITY TV', '', 0xffd27bdc),
  kids('KIDS', '', 0xfff2cc54);

  const CatalogPlatform(this.label, this.asset, this.color);
  final String label;
  final String asset;
  final int color;
  String get assetPath => 'assets/platforms/$asset.png';
}

/// Categories are supplied by the user's source, not an online service catalog.
class PlatformPreferences {
  const PlatformPreferences() : _overrides = const {};
  PlatformPreferences._(this._overrides);
  Map<String, Set<CatalogPlatform>> get overrides => UnmodifiableMapView({
    for (final entry in _overrides.entries)
      entry.key: UnmodifiableSetView(entry.value),
  });
  final Map<String, Set<CatalogPlatform>> _overrides;

  static String groupKey(MediaKind kind, String category) =>
      '${kind.name}:$category';

  bool hasOverride(MediaItem item) =>
      _overrides.containsKey(groupKey(item.kind, item.category));

  Set<CatalogPlatform> platformsFor(MediaItem item) {
    if (item.kind == MediaKind.live) return const {};
    final manual = _overrides[groupKey(item.kind, item.category)];
    if (manual != null) return UnmodifiableSetView(manual);
    return detectPlatforms(item.category);
  }

  PlatformPreferences withGroup(
    MediaKind kind,
    String category,
    Set<CatalogPlatform> platforms,
  ) {
    return PlatformPreferences._({
      ..._overrides,
      groupKey(kind, category): Set.of(platforms),
    });
  }

  PlatformPreferences resetGroup(MediaKind kind, String category) {
    final next = Map<String, Set<CatalogPlatform>>.of(_overrides)
      ..remove(groupKey(kind, category));
    return PlatformPreferences._(next);
  }

  PlatformPreferences updateGroups(Map<String, Set<CatalogPlatform>?> changes) {
    final next = Map<String, Set<CatalogPlatform>>.of(_overrides);
    for (final entry in changes.entries) {
      if (entry.value == null) {
        next.remove(entry.key);
      } else {
        next[entry.key] = Set.of(entry.value!);
      }
    }
    return PlatformPreferences._(next);
  }

  Map<String, dynamic> toJson() => {
    for (final entry in _overrides.entries)
      entry.key: entry.value.map((p) => p.name).toList(),
  };

  factory PlatformPreferences.fromJson(Object? value) {
    if (value is! Map) return const PlatformPreferences();
    final parsed = <String, Set<CatalogPlatform>>{};
    for (final entry in value.entries.take(20000)) {
      if (entry.key is! String ||
          (entry.key as String).length > 4096 ||
          entry.value is! List) {
        continue;
      }
      final key = entry.key as String;
      if (!key.startsWith('movie:') && !key.startsWith('series:')) continue;
      final platforms = <CatalogPlatform>{};
      var valid = true;
      for (final name in (entry.value as List).take(20)) {
        final match = CatalogPlatform.values
            .where((p) => p.name == name)
            .firstOrNull;
        if (match == null) {
          valid = false;
          break;
        }
        platforms.add(match);
      }
      if (valid) parsed[key] = platforms;
    }
    return PlatformPreferences._(parsed);
  }
}

Set<CatalogPlatform> detectPlatforms(String category) {
  final normalized = category
      .toLowerCase()
      .replaceAll(RegExp('[éèêë]'), 'e')
      .replaceAll(RegExp('[àâä]'), 'a')
      .replaceAll(RegExp('[îï]'), 'i')
      .replaceAll(RegExp('[ôö]'), 'o')
      .replaceAll(RegExp('[ùûü]'), 'u')
      .replaceAll('ç', 'c')
      .replaceAll(RegExp(r'[^a-z0-9+]'), ' ');
  final compact = normalized.replaceAll(' ', '');
  final tokens = normalized.split(RegExp(r'\s+')).toSet();
  return {
    if (tokens.contains('canal') ||
        tokens.contains('canal+') ||
        compact.contains('canalplus'))
      CatalogPlatform.canalPlus,
    if (tokens.contains('starz') || tokens.contains('starzplay'))
      CatalogPlatform.starz,
    if (tokens.contains('ocs')) CatalogPlatform.ocs,
    if (tokens.contains('variety')) CatalogPlatform.variety,
    if (compact.contains('tf1') ||
        compact.contains('m6') ||
        tokens.contains('ftv') ||
        compact.contains('francetv'))
      CatalogPlatform.frenchTv,
    if (tokens.any(
      (word) => word.startsWith('documentair') || word.startsWith('documentar'),
    ))
      CatalogPlatform.documentaries,
    if (tokens.any((word) => word.startsWith('emission')) ||
        tokens.contains('reality') ||
        compact.contains('telerealite'))
      CatalogPlatform.reality,
    if (tokens.any(
          (word) => word.startsWith('anime') || word.startsWith('animat'),
        ) ||
        tokens.contains('kids') ||
        compact.contains('dessinanime'))
      CatalogPlatform.kids,
    if (tokens.contains('netflix')) CatalogPlatform.netflix,
    if (compact.contains('primevideo') ||
        compact.contains('amazonprime') ||
        tokens.contains('amazon'))
      CatalogPlatform.primeVideo,
    if (tokens.contains('disney') ||
        tokens.contains('disney+') ||
        compact.contains('disneyplus'))
      CatalogPlatform.disneyPlus,
    if (compact.contains('appletv')) CatalogPlatform.appleTv,
    if (tokens.contains('hbo') ||
        tokens.contains('max') ||
        compact.contains('hbomax'))
      CatalogPlatform.hbo,
    if (tokens.contains('paramount') ||
        tokens.contains('paramount+') ||
        compact.contains('paramountplus'))
      CatalogPlatform.paramountPlus,
    if (tokens.contains('crunchyroll')) CatalogPlatform.crunchyroll,
    if (tokens.contains('hulu')) CatalogPlatform.hulu,
    if (tokens.contains('peacock')) CatalogPlatform.peacock,
  };
}
