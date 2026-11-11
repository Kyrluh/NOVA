import 'package:flutter/material.dart';

import '../../domain/models.dart';
import '../../domain/recent_catalog.dart';
import '../../domain/catalog_layout.dart';
import '../../state/app_controller.dart';
import '../widgets/media_artwork.dart';
import '../theme.dart';
import 'tv_widgets.dart';
import '../widgets/search_field.dart';

class TvCatalog extends StatefulWidget {
  const TvCatalog({
    super.key,
    required this.controller,
    required this.items,
    required this.onDetails,
    this.search = false,
    this.subtitle,
    this.recentCategory = false,
  });
  final AppController controller;
  final List<MediaItem> items;
  final ValueChanged<MediaItem> onDetails;
  final bool search;
  final String? subtitle;
  final bool recentCategory;
  @override
  State<TvCatalog> createState() => _TvCatalogState();
}

class _TvCatalogState extends State<TvCatalog> {
  static const _recent = '\u0000recent';
  final _search = TextEditingController();
  final _gridFocus = FocusNode(debugLabel: 'TV catalog results');
  String? _category;
  List<MediaItem>? _indexInput;
  List<MediaItem>? _indexCatalog;
  bool? _indexRecentCategory;
  final _groups = <String>{};
  List<({MediaItem item, String query, Set<String> categories})> _indexed =
      const [];
  List<MediaItem> _results = const [];
  String? _resultsQuery;
  String? _resultsCategory;
  bool _resultsDirty = true;
  Object? _storageScope;
  Object _scopeFor(TvCatalog catalog) => (
    catalog.controller.activeProfileId,
    catalog.key ??
        (
          catalog.search,
          catalog.recentCategory,
          catalog.items.firstOrNull?.kind,
        ),
  );

  void _saveFilters() {
    final scope = _storageScope;
    if (scope == null) return;
    PageStorage.maybeOf(context)?.writeState(
      context,
      {'query': _search.text, 'category': _category},
      identifier: ('tv-catalog-filters', scope),
    );
  }

  void _restoreFilters() {
    _storageScope = _scopeFor(widget);
    final saved = PageStorage.maybeOf(context)
        ?.readState(context, identifier: ('tv-catalog-filters', _storageScope));
    _search.text = saved is Map && saved['query'] is String
        ? saved['query'] as String
        : '';
    _category =
        saved is Map &&
            saved.containsKey('category') &&
            (saved['category'] == null || saved['category'] is String)
        ? saved['category'] as String?
        : widget.recentCategory
        ? _recent
        : null;
    _resultsDirty = true;
  }

  void _ensureIndex() {
    final visible = widget.controller.items;
    if (identical(_indexInput, widget.items) &&
        identical(_indexCatalog, visible) &&
        _indexRecentCategory == widget.recentCategory) {
      return;
    }
    _indexInput = widget.items;
    _indexCatalog = visible;
    _indexRecentCategory = widget.recentCategory;
    _resultsDirty = true;
    _groups.clear();
    for (final item in widget.items) {
      _groups.addAll(
        widget.controller.variantsFor(item).map((v) => v.category),
      );
    }
    final ordered = widget.recentCategory
        ? recentlyAdded(widget.items)
        : widget.items;
    _indexed = [
      for (final item in ordered)
        (
          item: item,
          query: '${item.title} ${item.category}'.toLowerCase(),
          categories: widget.controller
              .variantsFor(item)
              .map((v) => v.category)
              .toSet(),
        ),
    ];
  }

  @override
  void initState() {
    super.initState();
    if (widget.recentCategory) _category = _recent;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_storageScope == null) _restoreFilters();
  }

  @override
  void didUpdateWidget(covariant TvCatalog oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_storageScope != _scopeFor(widget)) {
      _saveFilters();
      _restoreFilters();
    }
  }

  @override
  void dispose() {
    _search.dispose();
    _gridFocus.dispose();
    super.dispose();
  }

  void _clearFilters({bool category = false}) {
    setState(() {
      _search.clear();
      if (category) _category = widget.recentCategory ? _recent : null;
    });
    _saveFilters();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _gridFocus.context != null) _gridFocus.requestFocus();
    });
  }

  Widget _emptyResults() {
    final text = _search.text.trim();
    final searching = text.isNotEmpty;
    final filtering = _category != null && _category != _recent;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              searching
                  ? Icons.search_off_rounded
                  : Icons.video_library_outlined,
              size: 38,
              color: novaMuted,
            ),
            const SizedBox(height: 12),
            Text(
              searching
                  ? 'Aucun résultat pour « $text »'
                  : filtering
                  ? 'Aucun contenu dans cette catégorie'
                  : 'Aucun contenu dans cette rubrique',
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              searching
                  ? filtering
                        ? 'Essayez un autre titre ou élargissez la catégorie.'
                        : 'Vérifiez le titre ou essayez un autre mot.'
                  : 'Vos sources ou vos filtres de bibliothèque ne proposent pas de contenu ici.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: novaMuted),
            ),
            if (searching || filtering) ...[
              const SizedBox(height: 18),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 10,
                children: [
                  if (searching)
                    FilledButton.icon(
                      onPressed: _clearFilters,
                      icon: const Icon(Icons.close_rounded),
                      label: const Text('Effacer la recherche'),
                    ),
                  if (filtering)
                    OutlinedButton.icon(
                      onPressed: () => _clearFilters(category: true),
                      icon: const Icon(Icons.filter_alt_off_outlined),
                      label: const Text('Réinitialiser les filtres'),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _ensureIndex();
    final groups = _groups;
    if (_category != null &&
        _category != _recent &&
        !groups.contains(_category)) {
      _category = null;
    }
    final query = _search.text.trim().toLowerCase();
    if (_resultsDirty ||
        _resultsQuery != query ||
        _resultsCategory != _category) {
      _resultsDirty = false;
      _resultsQuery = query;
      _resultsCategory = _category;
      _results = _indexed
          .where(
            (i) =>
                (_category == null ||
                    _category == _recent ||
                    i.categories.contains(_category)) &&
                (query.isEmpty || i.query.contains(query)),
          )
          .map((entry) => entry.item)
          .toList(growable: false);
    }
    final items = _results;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.subtitle != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              widget.subtitle!,
              style: const TextStyle(color: novaMuted),
            ),
          ),
        Row(
          children: [
            Expanded(
              child: NovaSearchField(
                television: true,
                key: const ValueKey('tv-catalog-search'),
                controller: _search,
                autofocus: widget.search,
                onChanged: (_) {
                  _saveFilters();
                  setState(() {});
                },
                onSubmitted: (_) {
                  if (items.isNotEmpty) _gridFocus.requestFocus();
                },
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Rechercher un titre',
                ),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 200,
              child: DropdownButtonFormField<String>(
                key: ValueKey(
                  'tv-category-${_category ?? 'all'}-${groups.length}',
                ),
                initialValue: _category,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Catégorie'),
                items: [
                  if (widget.recentCategory)
                    const DropdownMenuItem<String>(
                      value: _recent,
                      child: Text('Récemment ajoutés'),
                    ),
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('Toutes les catégories'),
                  ),
                  for (final group in groups)
                    DropdownMenuItem(
                      value: group,
                      child: Text(group, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (value) {
                  setState(() => _category = value);
                  _saveFilters();
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          '${items.length} titres',
          style: const TextStyle(color: novaMuted, fontSize: 13),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: items.isEmpty
              ? _emptyResults()
              : LayoutBuilder(
                  builder: (context, bounds) {
                    final columns = effectiveCatalogColumns(
                      widget.controller.settings,
                      bounds.maxWidth,
                      14,
                      (bounds.maxWidth / 155).floor().clamp(2, 7),
                    );
                    final tileWidth =
                        (bounds.maxWidth - (columns - 1) * 14) / columns;
                    return GridView.builder(
                      key: PageStorageKey<Object>((
                        'tv-poster-grid',
                        _storageScope,
                        _category,
                        query,
                      )),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        // Large manual cards must leave the next row built and
                        // reachable with a remote instead of filling many screens.
                        mainAxisExtent:
                            widget.controller.settings.catalogColumns > 0
                            ? (tileWidth / .62)
                                  .clamp(
                                    120,
                                    bounds.maxHeight.clamp(
                                      120,
                                      double.infinity,
                                    ),
                                  )
                                  .toDouble()
                            : null,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 14,
                        childAspectRatio: .62,
                      ),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return TvTile(
                          key: ValueKey('tv-card-${item.id}'),
                          focusNode: index == 0 ? _gridFocus : null,
                          label: 'Ouvrir ${item.title}',
                          onPressed: () => widget.onDetails(item),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: SizedBox(
                                  width: double.infinity,
                                  child: MediaArtwork(
                                    item: item,
                                    controller: widget.controller,
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8),
                                child: Text(
                                  item.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}
