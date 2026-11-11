import 'dart:convert';

import 'catalog_defaults_data.dart';
import 'catalog_preferences.dart';
import 'models.dart';

final _template = jsonDecode(catalogDefaultsJson) as Map<String, dynamic>;

CatalogPreferences initialCatalogPreferences() => CatalogPreferences(
  rules: {
    for (final kind in MediaKind.values)
      kind: CatalogRule(
        hiddenLanguages: Set.unmodifiable(
          ((_template[kind.name] as Map)['hiddenLanguages'] as List)
              .cast<String>(),
        ),
      ),
  },
);

String _categoryName(String name) =>
    name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

final _hiddenNames = {
  for (final kind in MediaKind.values)
    kind: ((_template[kind.name] as Map)['hiddenCategoryNames'] as List)
        .cast<String>()
        .map(_categoryName)
        .toSet(),
};

bool initiallyHiddenCategory(MediaItem item) =>
    _hiddenNames[item.kind]!.contains(_categoryName(item.category));
