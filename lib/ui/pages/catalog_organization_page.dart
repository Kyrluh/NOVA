import 'package:flutter/foundation.dart' show mapEquals;
import 'package:flutter/material.dart';

import '../../domain/catalog_preferences.dart';
import '../../domain/models.dart';
import '../../state/app_controller.dart';
import '../theme.dart';
import '../widgets/page_widgets.dart';
import '../adaptive.dart';

/// Personal visibility and ordering rules, independent for each media catalogue.
class CatalogOrganizationPage extends StatefulWidget {
  const CatalogOrganizationPage({super.key, required this.controller});

  final AppController controller;

  @override
  State<CatalogOrganizationPage> createState() =>
      _CatalogOrganizationPageState();
}

class _CatalogOrganizationPageState extends State<CatalogOrganizationPage> {
  MediaKind _kind = MediaKind.live;
  final _search = TextEditingController();
  final _scroll = ScrollController();
  String _query = '';
  List<MediaItem>? _indexedItems;
  MediaKind? _indexedKind;
  Map<String, String>? _indexedOverrides;
  _CatalogueSummary? _summary;

  AppController get app => widget.controller;
  CatalogRule get rule => app.catalogPreferences.ruleFor(_kind);

  @override
  void dispose() {
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _save(CatalogRule value) => app.updateCatalogPreferences(
    app.catalogPreferences.copyWithRule(_kind, value),
  );

  void _selectKind(MediaKind kind) {
    setState(() {
      _kind = kind;
      _query = '';
      _search.clear();
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  _CatalogueSummary _catalogue(CatalogRule currentRule) {
    final allItems = app.allItems;
    if (identical(_indexedItems, allItems) &&
        _indexedKind == _kind &&
        mapEquals(_indexedOverrides, currentRule.languageOverrides)) {
      return _summary!;
    }
    final categories = <String, _CategorySummary>{};
    final languages = <String, int>{};
    var total = 0;
    for (final item in allItems) {
      if (item.kind != _kind) continue;
      total++;
      final key = catalogCategoryKey(item);
      final category = categories.putIfAbsent(
        key,
        () => _CategorySummary(
          key: key,
          title: item.category.isEmpty ? 'Sans catégorie' : item.category,
          sourceId: item.sourceId,
        ),
      );
      category.count++;
      final language = inferCatalogLanguage(
        item,
        overrides: currentRule.languageOverrides,
      );
      languages.update(language, (count) => count + 1, ifAbsent: () => 1);
    }
    _indexedItems = allItems;
    _indexedKind = _kind;
    _indexedOverrides = Map.of(currentRule.languageOverrides);
    return _summary = _CatalogueSummary(
      categories: categories.values.toList(),
      languages: languages,
      total: total,
    );
  }

  List<_CategorySummary> _orderedCategories(
    _CatalogueSummary summary,
    CatalogRule currentRule,
  ) {
    final remaining = {
      for (final category in summary.categories) category.key: category,
    };
    final result = <_CategorySummary>[];
    for (final key in currentRule.categoryOrder) {
      final category = remaining.remove(key);
      if (category != null) result.add(category);
    }
    return result..addAll(remaining.values);
  }

  void _reorder(List<_CategorySummary> categories, int oldIndex, int newIndex) {
    if (_query.isNotEmpty) return;
    if (newIndex == oldIndex) return;
    final ordered = categories.map((category) => category.key).toList();
    ordered.insert(newIndex, ordered.removeAt(oldIndex));
    _save(rule.copyWith(categoryOrder: ordered, order: CatalogOrder.category));
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: app,
    builder: (context, _) {
      final currentRule = rule;
      final summary = _catalogue(currentRule);
      final visible = app.items.where((item) => item.kind == _kind).length;
      final ordered = _orderedCategories(summary, currentRule);
      final sourceNames = {
        for (final source in app.sources?.sources ?? []) source.id: source.name,
      };
      final filtered = _query.isEmpty
          ? ordered
          : ordered.where((category) {
              final text =
                  '${category.title} ${sourceNames[category.sourceId] ?? ''}';
              return text.toLowerCase().contains(_query);
            }).toList();
      return Scrollbar(
        controller: _scroll,
        child: CustomScrollView(
          key: const Key('catalog-organization-scroll'),
          controller: _scroll,
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                novaPageInset(context),
                20,
                novaPageInset(context),
                0,
              ),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const PageHeading(
                      title: 'Tri et affichage',
                      subtitle: 'Choisissez les contenus visibles et leur ordre. Les changements sont enregistrés automatiquement.',
                    ),
                    const SizedBox(height: 24),
                    Wrap(
                      spacing: 10,
                      runSpacing: 12,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        SegmentedButton<MediaKind>(
                          key: const Key('catalog-kind'),
                          segments: const [
                            ButtonSegment(
                              value: MediaKind.live,
                              label: Text('TV'),
                              icon: Icon(Icons.live_tv_rounded, size: 18),
                            ),
                            ButtonSegment(
                              value: MediaKind.movie,
                              label: Text('Films'),
                              icon: Icon(Icons.movie_outlined, size: 18),
                            ),
                            ButtonSegment(
                              value: MediaKind.series,
                              label: Text('Séries'),
                              icon: Icon(
                                Icons.video_library_outlined,
                                size: 18,
                              ),
                            ),
                          ],
                          selected: {_kind},
                          onSelectionChanged: (selection) =>
                              _selectKind(selection.single),
                        ),
                        Text(
                          '$visible / ${summary.total} ${_kind == MediaKind.live ? 'chaînes visibles' : 'titres visibles'}',
                          key: const Key('catalog-visible-count'),
                          style: const TextStyle(
                            color: novaMuted,
                            fontSize: 12,
                          ),
                        ),
                        TextButton.icon(
                          key: const Key('catalog-reset'),
                          onPressed: () => _save(const CatalogRule()),
                          icon: const Icon(Icons.restart_alt_rounded, size: 18),
                          label: const Text('Réinitialiser cet onglet'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    _panel(
                      child: LayoutBuilder(
                        builder: (context, constraints) => Wrap(
                          spacing: 28,
                          runSpacing: 14,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            const SizedBox(
                              width: 225,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Ordre des contenus',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  SizedBox(height: 5),
                                  Text(
                                    'Appliqué aux listes, à l’accueil et à la recherche.',
                                    style: TextStyle(
                                      color: novaMuted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(
                              width: constraints.maxWidth < 320
                                  ? constraints.maxWidth
                                  : 300,
                              child: DropdownButtonFormField<CatalogOrder>(
                                key: ValueKey(
                                  'catalog-order-${_kind.name}-${currentRule.order.name}',
                                ),
                                initialValue: currentRule.order,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Trier par',
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: CatalogOrder.source,
                                    child: Text('Ordre de la source'),
                                  ),
                                  DropdownMenuItem(
                                    value: CatalogOrder.titleAsc,
                                    child: Text('Titre · A → Z'),
                                  ),
                                  DropdownMenuItem(
                                    value: CatalogOrder.titleDesc,
                                    child: Text('Titre · Z → A'),
                                  ),
                                  DropdownMenuItem(
                                    value: CatalogOrder.yearDesc,
                                    child: Text('Année · plus récent d’abord'),
                                  ),
                                  DropdownMenuItem(
                                    value: CatalogOrder.category,
                                    child: Text('Mes catégories'),
                                  ),
                                ],
                                onChanged: (order) {
                                  if (order != null) {
                                    _save(rule.copyWith(order: order));
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    _languages(summary, currentRule),
                    if (visible == 0 && summary.total > 0) ...[
                      const SizedBox(height: 18),
                      const NovaNotice(
                        icon: Icons.visibility_off_outlined,
                        text: 'Tous les contenus de cet onglet sont masqués. Cochez une langue ou une catégorie pour les retrouver, ou réinitialisez cet onglet.',
                      ),
                    ],
                    const SizedBox(height: 26),
                    Text(
                      'Catégories (${summary.categories.length})',
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 7),
                    const Text(
                      'Décochez une catégorie pour la masquer. Faites glisser sa poignée pour créer votre ordre de catégories.',
                      style: TextStyle(color: novaMuted, fontSize: 12),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      key: const Key('catalog-category-search'),
                      controller: _search,
                      onChanged: (value) =>
                          setState(() => _query = value.trim().toLowerCase()),
                      decoration: InputDecoration(
                        hintText: 'Rechercher une catégorie ou une source…',
                        prefixIcon: const Icon(Icons.search_rounded, size: 19),
                        suffixIcon: _query.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Effacer la recherche de catégories',
                                onPressed: () => setState(() {
                                  _search.clear();
                                  _query = '';
                                }),
                                icon: const Icon(Icons.close_rounded, size: 18),
                              ),
                        isDense: true,
                      ),
                    ),
                    if (_query.isNotEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 10),
                        child: Text(
                          'Effacez la recherche pour déplacer les catégories.',
                          style: TextStyle(color: novaMuted, fontSize: 12),
                        ),
                      ),
                    const SizedBox(height: 14),
                  ],
                ),
              ),
            ),
            if (filtered.isEmpty)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(32, 0, 32, 40),
                sliver: SliverToBoxAdapter(
                  child: NovaNotice(
                    icon: Icons.folder_off_outlined,
                    text: summary.total == 0
                        ? 'Aucun contenu dans cet onglet. Ajoutez ou actualisez une source IPTV pour configurer son affichage.'
                        : 'Aucune catégorie ne correspond à votre recherche.',
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(32, 0, 32, 40),
                sliver: SliverReorderableList(
                  itemCount: filtered.length,
                  onReorderItem: (oldIndex, newIndex) =>
                      _reorder(ordered, oldIndex, newIndex),
                  itemBuilder: (context, index) {
                    final category = filtered[index];
                    return _category(
                      category,
                      index,
                      currentRule,
                      sourceNames[category.sourceId] ??
                          (category.sourceId == null
                              ? 'Catalogue de démonstration'
                              : 'Source IPTV'),
                    );
                  },
                ),
              ),
          ],
        ),
      );
    },
  );

  Widget _languages(_CatalogueSummary summary, CatalogRule currentRule) {
    final languages = summary.languages.keys.toList()
      ..sort((a, b) {
        if (a == 'unknown') return b == 'unknown' ? 0 : 1;
        if (b == 'unknown') return -1;
        return catalogLanguageLabel(a).compareTo(catalogLanguageLabel(b));
      });
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 16,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(
                'Langues visibles',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              TextButton(
                key: const Key('catalog-show-languages'),
                onPressed: languages.isEmpty
                    ? null
                    : () => _save(rule.copyWith(hiddenLanguages: {})),
                child: const Text('Tout afficher'),
              ),
              TextButton(
                key: const Key('catalog-hide-languages'),
                onPressed: languages.isEmpty
                    ? null
                    : () => _save(
                        rule.copyWith(hiddenLanguages: languages.toSet()),
                      ),
                child: const Text('Tout masquer'),
              ),
            ],
          ),
          const Text(
            'Langue repérée dans le nom ou le groupe. Vous pouvez affecter une langue aux catégories ci-dessous.',
            style: TextStyle(color: novaMuted, fontSize: 12),
          ),
          const SizedBox(height: 14),
          if (languages.isEmpty)
            const Text(
              'Aucune langue disponible dans cet onglet.',
              style: TextStyle(color: novaMuted, fontSize: 12),
            )
          else
            Wrap(
              spacing: 9,
              runSpacing: 9,
              children: [
                for (final language in languages)
                  FilterChip(
                    key: ValueKey('catalog-language-$language'),
                    label: Text(
                      '${catalogLanguageLabel(language)} (${summary.languages[language]})',
                    ),
                    selected: !currentRule.hiddenLanguages.contains(language),
                    onSelected: (selected) {
                      final hidden = {...rule.hiddenLanguages};
                      selected ? hidden.remove(language) : hidden.add(language);
                      _save(rule.copyWith(hiddenLanguages: hidden));
                    },
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _category(
    _CategorySummary category,
    int index,
    CatalogRule currentRule,
    String sourceName,
  ) {
    final narrow = MediaQuery.sizeOf(context).width < 600;
    return Padding(
      key: ValueKey(category.key),
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: novaSurface,
        borderRadius: BorderRadius.circular(11),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 12, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Checkbox(
                    key: ValueKey('catalog-category-${category.key}'),
                    semanticLabel: 'Afficher ${category.title}',
                    value: !currentRule.hiddenCategories.contains(category.key),
                    onChanged: (visible) {
                      final hidden = {...rule.hiddenCategories};
                      visible == true
                          ? hidden.remove(category.key)
                          : hidden.add(category.key);
                      _save(rule.copyWith(hiddenCategories: hidden));
                    },
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          category.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$sourceName · ${category.count} contenus',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: novaMuted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!narrow) ...[
                    const SizedBox(width: 14),
                    SizedBox(
                      width: MediaQuery.sizeOf(context).width < 760 ? 145 : 190,
                      child: _categoryLanguage(category, currentRule),
                    ),
                  ],
                  const SizedBox(width: 8),
                  if (_query.isEmpty)
                    ReorderableDragStartListener(
                      key: ValueKey('catalog-drag-${category.key}'),
                      index: index,
                      child: const MouseRegion(
                        cursor: SystemMouseCursors.grab,
                        child: Tooltip(
                          message: 'Déplacer la catégorie',
                          child: Padding(
                            padding: EdgeInsets.all(12),
                            child: Icon(
                              Icons.drag_handle_rounded,
                              size: 21,
                              color: novaMuted,
                            ),
                          ),
                        ),
                      ),
                    )
                  else
                    const SizedBox(width: 45),
                ],
              ),
              if (narrow)
                Padding(
                  padding: const EdgeInsets.only(left: 54, top: 12),
                  child: _categoryLanguage(category, currentRule),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _categoryLanguage(_CategorySummary category, CatalogRule currentRule) {
    final override = currentRule.languageOverrides[category.key] ?? '';
    return DropdownButtonFormField<String>(
      key: ValueKey('catalog-category-language-${category.key}-$override'),
      initialValue: override,
      isExpanded: true,
      menuMaxHeight: 340,
      decoration: const InputDecoration(
        labelText: 'Langue du groupe',
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      ),
      items: [
        const DropdownMenuItem(value: '', child: Text('Automatique')),
        for (final code in catalogLanguageCodes)
          DropdownMenuItem(
            value: code,
            child: Text(catalogLanguageLabel(code)),
          ),
      ],
      onChanged: (language) {
        if (language == null) return;
        final overrides = {...rule.languageOverrides};
        language.isEmpty
            ? overrides.remove(category.key)
            : overrides[category.key] = language;
        _save(rule.copyWith(languageOverrides: overrides));
      },
    );
  }

  Widget _panel({required Widget child}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: novaSurface,
      border: Border.all(color: const Color(0xFF242936)),
      borderRadius: BorderRadius.circular(14),
    ),
    child: child,
  );
}

class _CategorySummary {
  _CategorySummary({
    required this.key,
    required this.title,
    required this.sourceId,
  });
  final String key;
  final String title;
  final String? sourceId;
  int count = 0;
}

class _CatalogueSummary {
  const _CatalogueSummary({
    required this.categories,
    required this.languages,
    required this.total,
  });
  final List<_CategorySummary> categories;
  final Map<String, int> languages;
  final int total;
}
