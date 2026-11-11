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
  void dispose() {
    _search.dispose();
    _gridFocus.dispose();
    super.dispose();
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
                onChanged: (_) => setState(() {}),
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
                onChanged: (value) => setState(() => _category = value),
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
              ? const Center(
                  child: Text(
                    'Aucun contenu disponible. Ajoutez une source ou changez vos filtres.',
                  ),
                )
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
                      key: const PageStorageKey('tv-poster-grid'),
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
