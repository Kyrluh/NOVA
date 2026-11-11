import 'package:flutter/material.dart';

import '../../domain/catalog_preferences.dart';
import '../../domain/models.dart';
import '../../domain/recent_catalog.dart';
import '../../domain/catalog_layout.dart';
import '../../state/app_controller.dart';
import '../theme.dart';
import '../adaptive.dart';
import '../widgets/media_artwork.dart';

class MediaCatalogPage extends StatefulWidget {
  const MediaCatalogPage({
    super.key,
    required this.controller,
    required this.kind,
    required this.onDetails,
  });

  final AppController controller;
  final MediaKind kind;
  final void Function(MediaItem) onDetails;

  @override
  State<MediaCatalogPage> createState() => _MediaCatalogPageState();
}

class _MediaCatalogPageState extends State<MediaCatalogPage> {
  final _search = TextEditingController();
  static const _recent = '\u0000recent';
  String? _category = _recent;
  String _sort = 'recent';
  Object? _storageScope;

  Object _scopeFor(MediaCatalogPage page) =>
      ('media-catalog-filters', page.controller.activeProfileId, page.kind);

  void _saveFilters() {
    if (_storageScope == null) return;
    PageStorage.maybeOf(context)?.writeState(context, {
      'query': _search.text,
      'category': _category,
      'sort': _sort,
    }, identifier: _storageScope);
  }

  void _restoreFilters() {
    _storageScope = _scopeFor(widget);
    final saved = PageStorage.maybeOf(context)
        ?.readState(context, identifier: _storageScope);
    _search.text = saved is Map && saved['query'] is String
        ? saved['query'] as String
        : '';
    _category =
        saved is Map &&
            saved.containsKey('category') &&
            (saved['category'] == null || saved['category'] is String)
        ? saved['category'] as String?
        : _recent;
    _sort =
        saved is Map &&
            const {
              'recent',
              'catalogue',
              'title',
              'year',
            }.contains(saved['sort'])
        ? saved['sort'] as String
        : 'recent';
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_storageScope == null) _restoreFilters();
  }

  Future<void> _chooseCategory(List<String> categories) async {
    final android = NovaAdaptiveScope.isAndroid(context);
    final picker = _CatalogCategoryPicker(
      categories: categories,
      selected: _category,
      autofocusSearch: !android,
    );
    final result = android
        ? await showModalBottomSheet<({String? value})>(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            showDragHandle: true,
            builder: (context) => Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: FractionallySizedBox(heightFactor: .85, child: picker),
            ),
          )
        : await showDialog<({String? value})>(
            context: context,
            builder: (context) => Dialog(
              clipBehavior: Clip.antiAlias,
              child: SizedBox(
                width: 520,
                height: (MediaQuery.sizeOf(context).height * .8).clamp(
                  200,
                  620,
                ),
                child: picker,
              ),
            ),
          );
    if (!mounted || result == null) return;
    setState(() => _category = result.value);
    _saveFilters();
  }

  void _resetFilters() {
    setState(() {
      _search.clear();
      _category = _recent;
      _sort = 'recent';
    });
    _saveFilters();
    FocusScope.of(context).unfocus();
  }

  @override
  void didUpdateWidget(covariant MediaCatalogPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_storageScope != _scopeFor(widget)) {
      _saveFilters();
      _restoreFilters();
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, child) {
        final catalog = widget.controller.items
            .where((item) => item.kind == widget.kind)
            .toList();
        final categories = catalog
            .expand(
              (item) =>
                  widget.controller.variantsFor(item).map((v) => v.category),
            )
            .toSet()
            .toList();
        if (widget.controller.catalogPreferences.ruleFor(widget.kind).order !=
            CatalogOrder.category) {
          categories.sort();
        }
        categories.insert(0, _recent);
        if (_category != null && !categories.contains(_category)) {
          _category = _recent;
        }
        final query = _normalize(_search.text.trim());
        var items = catalog.where((item) {
          return (_category == null ||
                  _category == _recent ||
                  widget.controller
                      .variantsFor(item)
                      .any((v) => v.category == _category)) &&
              (query.isEmpty || _searchText(item).contains(query));
        }).toList();
        if (_category == _recent || _sort == 'recent') {
          items = recentlyAdded(items);
        } else {
          switch (_sort) {
            case 'title':
              items.sort(
                (a, b) => _normalize(a.title).compareTo(_normalize(b.title)),
              );
            case 'year':
              items.sort((a, b) => b.year.compareTo(a.year));
          }
        }
        final title = switch (widget.kind) {
          MediaKind.movie => 'Films',
          MediaKind.series => 'Séries',
          MediaKind.live => 'Chaînes',
        };
        return CatalogGrid(
          controller: widget.controller,
          items: items,
          onDetails: widget.onDetails,
          title: title,
          subtitle: widget.controller.isDemo
              ? 'Explorez votre prochain univers. Catalogue fictif de démonstration.'
              : 'Votre catalogue personnel, disponible hors ligne après import.',
          controls: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final search = TextField(
                    controller: _search,
                    onChanged: (_) {
                      setState(() {});
                      _saveFilters();
                    },
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      hintText: 'Rechercher dans les ${title.toLowerCase()}',
                      suffixIcon: _search.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Effacer la recherche',
                              onPressed: () {
                                setState(_search.clear);
                                _saveFilters();
                              },
                              icon: const Icon(Icons.close_rounded, size: 18),
                            ),
                    ),
                  );
                  final sort = DropdownButtonFormField<String>(
                    key: ValueKey(_category == _recent),
                    isExpanded: true,
                    initialValue: _category == _recent ? 'recent' : _sort,
                    decoration: const InputDecoration(
                      labelText: 'Trier par',
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'recent',
                        child: Text(
                          'Récemment ajoutés',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'catalogue',
                        child: Text(
                          'Ordre du catalogue',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'title',
                        child: Text(
                          'Titre A–Z',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'year',
                        child: Text(
                          'Année décroissante',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                    onChanged: _category == _recent
                        ? null
                        : (value) {
                            if (value != null) {
                              setState(() => _sort = value);
                              _saveFilters();
                            }
                          },
                  );
                  if (constraints.maxWidth <
                      (NovaAdaptiveScope.isAndroid(context) ? 450 : 560)) {
                    return Column(
                      children: [search, const SizedBox(height: 14), sort],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: search),
                      const SizedBox(width: 16),
                      SizedBox(
                        width: NovaAdaptiveScope.isAndroid(context) ? 160 : 230,
                        child: sort,
                      ),
                    ],
                  );
                },
              ),
              SizedBox(height: NovaAdaptiveScope.isAndroid(context) ? 10 : 22),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  key: const ValueKey('catalog-category-picker'),
                  onPressed: () => _chooseCategory(categories),
                  icon: const Icon(Icons.filter_list_rounded, size: 19),
                  label: Text(
                    'Catégories · ${_catalogCategoryLabel(_category)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              SizedBox(
                key: const ValueKey('catalog-category-strip'),
                height: NovaAdaptiveScope.isAndroid(context) ? 44 : 48,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: categories.length + 1,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final category = index == 0
                        ? _recent
                        : index == 1
                        ? null
                        : categories[index - 1];
                    return ChoiceChip(
                      label: Text(
                        category == _recent
                            ? 'Récemment ajoutés'
                            : category ?? 'Tout explorer',
                      ),
                      selected: _category == category,
                      onSelected: (_) {
                        setState(() => _category = category);
                        _saveFilters();
                      },
                    );
                  },
                ),
              ),
            ],
          ),
          emptyTitle: query.isNotEmpty
              ? 'Aucun résultat pour « ${_search.text.trim()} »'
              : _category != null && _category != _recent
              ? 'Aucun contenu dans cette catégorie'
              : 'Votre catalogue est vide',
          emptyMessage: query.isNotEmpty
              ? 'Essayez un autre titre ou effacez la recherche.'
              : _category != null && _category != _recent
              ? 'Choisissez une autre catégorie ou réinitialisez les filtres.'
              : 'Les contenus disponibles dans vos sources et vos langues sélectionnées apparaîtront ici.',
          emptyAction:
              query.isNotEmpty || (_category != null && _category != _recent)
              ? OutlinedButton.icon(
                  key: const ValueKey('catalog-reset-filters'),
                  onPressed: _resetFilters,
                  icon: const Icon(Icons.filter_alt_off_outlined),
                  label: Text(
                    _category != null && _category != _recent
                        ? 'Réinitialiser les filtres'
                        : 'Effacer la recherche',
                  ),
                )
              : null,
        );
      },
    );
  }
}

String _catalogCategoryLabel(String? category) =>
    category == _MediaCatalogPageState._recent
    ? 'Récemment ajoutés'
    : category ?? 'Tout explorer';

class _CatalogCategoryPicker extends StatefulWidget {
  const _CatalogCategoryPicker({
    required this.categories,
    required this.selected,
    required this.autofocusSearch,
  });
  final List<String> categories;
  final String? selected;
  final bool autofocusSearch;
  @override
  State<_CatalogCategoryPicker> createState() => _CatalogCategoryPickerState();
}

class _CatalogCategoryPickerState extends State<_CatalogCategoryPicker> {
  final _query = TextEditingController();
  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _normalize(_query.text.trim());
    final values =
        <String?>[
              _MediaCatalogPageState._recent,
              null,
              ...widget.categories.where(
                (category) => category != _MediaCatalogPageState._recent,
              ),
            ]
            .where(
              (category) =>
                  query.isEmpty ||
                  _normalize(_catalogCategoryLabel(category)).contains(query),
            )
            .toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Choisir une catégorie',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                tooltip: 'Fermer les catégories',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('catalog-category-search'),
            controller: _query,
            autofocus: widget.autofocusSearch,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Rechercher une catégorie',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _query.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Effacer le filtre des catégories',
                      onPressed: () => setState(_query.clear),
                      icon: const Icon(Icons.close),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: values.isEmpty
                ? const Center(child: Text('Aucune catégorie correspondante.'))
                : ListView.builder(
                    itemCount: values.length,
                    itemBuilder: (context, index) {
                      final value = values[index];
                      final selected = value == widget.selected;
                      return ListTile(
                        key: ValueKey(('catalog-category-option', value)),
                        title: Text(_catalogCategoryLabel(value)),
                        selected: selected,
                        trailing: selected
                            ? const Icon(Icons.check_rounded)
                            : null,
                        onTap: () => Navigator.pop(context, (value: value)),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class CollectionPage extends StatelessWidget {
  const CollectionPage({
    super.key,
    required this.controller,
    required this.resume,
    required this.onDetails,
  });

  final AppController controller;
  final bool resume;
  final void Function(MediaItem) onDetails;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final items = resume
            ? controller.resumeItems
            : controller.items
                  .where((item) => controller.favorites.contains(item.id))
                  .toList();
        return CatalogGrid(
          controller: controller,
          items: items,
          onDetails: onDetails,
          title: resume ? 'Continuer à regarder' : 'Vos favoris',
          subtitle: resume
              ? 'Retrouvez les films et épisodes en cours de votre catalogue.'
              : 'Une sélection qui vous ressemble, conservée sur cet ordinateur.',
          emptyIcon: resume
              ? Icons.history_rounded
              : Icons.favorite_border_rounded,
          emptyTitle: resume
              ? 'Votre prochaine histoire vous attend'
              : 'Votre sélection commence ici',
          emptyMessage: resume
              ? 'Aucune lecture du catalogue à reprendre pour le moment. '
                    'Les fichiers ouverts séparément ne sont pas ajoutés à cette collection.'
              : 'Ajoutez un film, une série ou une chaîne avec le cœur de sa fiche.',
        );
      },
    );
  }
}

class SearchPage extends StatelessWidget {
  const SearchPage({
    super.key,
    required this.controller,
    required this.query,
    required this.onDetails,
  });

  final AppController controller;
  final String query;
  final void Function(MediaItem) onDetails;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final normalized = _normalize(query.trim());
        final items = normalized.isEmpty
            ? <MediaItem>[]
            : controller.items
                  .where((item) => _searchText(item).contains(normalized))
                  .toList();
        return CatalogGrid(
          controller: controller,
          items: items,
          onDetails: onDetails,
          title: 'Recherche',
          subtitle: normalized.isEmpty
              ? 'Films, séries et chaînes : explorez tout le catalogue.'
              : 'Résultats pour « ${query.trim()} » dans ${controller.isDemo ? 'le catalogue de démonstration' : 'vos sources'}.',
          emptyIcon: Icons.search_rounded,
          emptyTitle: normalized.isEmpty
              ? 'Un titre, un univers, une envie ?'
              : 'Aucun résultat',
          emptyMessage: normalized.isEmpty
              ? 'Saisissez votre recherche dans la barre en haut de la fenêtre.'
              : 'Essayez un autre titre, un genre ou un mot plus court.',
        );
      },
    );
  }
}

class HistoryPage extends StatelessWidget {
  const HistoryPage({
    super.key,
    required this.controller,
    required this.onDetails,
  });
  final AppController controller;
  final void Function(MediaItem) onDetails;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final visible = {for (final item in controller.items) item.id: item};
      final episodeParents = <String, MediaItem>{};
      for (final item in visible.values) {
        for (final variant in controller.variantsFor(item)) {
          episodeParents[variant.id] = item;
          for (final season in variant.seasons) {
            for (final episode in season.episodes) {
              episodeParents[episode.id] = item;
            }
          }
        }
      }
      final seen = <String>{};
      final items = <MediaItem>[];
      for (final id in controller.recentIds) {
        final item = visible[id] ?? episodeParents[id];
        if (item != null && seen.add(item.id)) items.add(item);
      }
      return CatalogGrid(
        controller: controller,
        items: items,
        onDetails: onDetails,
        title: 'Historique',
        subtitle: 'Vos lectures récentes, films et épisodes réunis.',
        emptyIcon: Icons.manage_history_rounded,
        emptyTitle: 'Votre historique commence ici',
        emptyMessage: 'Les lectures de votre catalogue apparaîtront ici, y compris les titres terminés.',
      );
    },
  );
}

class CatalogGrid extends StatelessWidget {
  const CatalogGrid({
    super.key,
    required this.controller,
    required this.items,
    required this.onDetails,
    required this.title,
    required this.subtitle,
    required this.emptyTitle,
    required this.emptyMessage,
    this.controls,
    this.emptyIcon = Icons.movie_filter_outlined,
    this.headerAction,
    this.emptyAction,
  });

  final AppController controller;
  final List<MediaItem> items;
  final void Function(MediaItem) onDetails;
  final String title;
  final String subtitle;
  final String emptyTitle;
  final String emptyMessage;
  final Widget? controls;
  final IconData emptyIcon;
  final Widget? headerAction;
  final Widget? emptyAction;

  @override
  Widget build(BuildContext context) {
    final inset = novaPageInset(context);
    final android = NovaAdaptiveScope.isAndroid(context);
    final showTitle =
        !android ||
        !const {
          'Films',
          'Séries',
          'Recherche',
          'Historique',
          'Continuer à regarder',
          'Vos favoris',
        }.contains(title);
    return CustomScrollView(
      key: PageStorageKey(title),
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(inset, android ? 8 : 20, inset, 0),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (headerAction == null && showTitle)
                  Text(
                    title,
                    style: android
                        ? const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          )
                        : Theme.of(context).textTheme.headlineLarge,
                  )
                else if (headerAction != null)
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    spacing: 20,
                    runSpacing: 12,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.headlineLarge,
                      ),
                      headerAction!,
                    ],
                  ),
                if (!android) const SizedBox(height: 9),
                if (!android)
                  Text(
                    subtitle,
                    style: const TextStyle(color: novaMuted, height: 1.5),
                  ),
                if (controls != null) ...[
                  SizedBox(height: android ? 8 : 28),
                  controls!,
                ],
                SizedBox(height: android ? 10 : 28),
                if (items.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(bottom: android ? 8 : 18),
                    child: Text(
                      '${items.length} ${items.length == 1 ? 'contenu' : 'contenus'}',
                      style: const TextStyle(color: novaMuted, fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (items.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(inset, 20, inset, 64),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary
                              .withAlpha(20),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Icon(
                          emptyIcon,
                          size: 32,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 22),
                      Text(
                        emptyTitle,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        emptyMessage,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: novaMuted, height: 1.6),
                      ),
                      if (emptyAction != null) ...[
                        const SizedBox(height: 18),
                        emptyAction!,
                      ],
                    ],
                  ),
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: EdgeInsets.fromLTRB(inset, 0, inset, 40),
            sliver: SliverLayoutBuilder(
              builder: (context, bounds) {
                final android = NovaAdaptiveScope.isAndroid(context);
                final scale = controller.settings.posterScale;
                final automaticColumns =
                    ((bounds.crossAxisExtent + 12) / (132 * scale + 12))
                        .floor()
                        .clamp(
                          novaTablet(context) && bounds.crossAxisExtent >= 480
                              ? 5
                              : 2,
                          12,
                        );
                final manual = controller.settings.catalogColumns > 0;
                final gap = android ? 12.0 : 20.0;
                final columns = effectiveCatalogColumns(
                  controller.settings,
                  bounds.crossAxisExtent,
                  gap,
                  automaticColumns,
                );
                return SliverGrid.builder(
                  gridDelegate: android || manual
                      ? SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          mainAxisExtent:
                              ((bounds.crossAxisExtent - (columns - 1) * gap) /
                                      columns) *
                                  1.5 +
                              58 *
                                  (MediaQuery.textScalerOf(context).scale(14) /
                                      14),
                          crossAxisSpacing: gap,
                          mainAxisSpacing: 16,
                        )
                      : SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent:
                              235 * controller.settings.posterScale,
                          childAspectRatio: .61,
                          crossAxisSpacing: 20,
                          mainAxisSpacing: 24,
                        ),
                  itemCount: items.length,
                  itemBuilder: (context, index) => MediaPoster(
                    key: ValueKey(items[index].id),
                    controller: controller,
                    item: items[index],
                    onTap: () => onDetails(items[index]),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

class MediaPoster extends StatefulWidget {
  const MediaPoster({
    super.key,
    required this.controller,
    required this.item,
    required this.onTap,
  });

  final AppController controller;
  final MediaItem item;
  final VoidCallback onTap;

  @override
  State<MediaPoster> createState() => _MediaPosterState();
}

class _MediaPosterState extends State<MediaPoster> {
  bool _hover = false;

  void _removeFromResume() {
    final app = widget.controller;
    final id = widget.item.id;
    app.dismissResume(id);
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        persist: false,
        duration: const Duration(seconds: 4),
        showCloseIcon: true,
        content: const Text('Retiré de Continuer à regarder'),
        action: SnackBarAction(
          label: 'Annuler',
          onPressed: () => app.restoreResume(id),
        ),
      ),
    );
  }

  Future<void> _showContextMenu(Offset position) async {
    final overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    final local = overlay.globalToLocal(position);
    final remove = await showMenu<bool>(
      context: context,
      position: RelativeRect.fromRect(
        local & const Size(1, 1),
        Offset.zero & overlay.size,
      ),
      popUpAnimationStyle: AnimationStyle.noAnimation,
      items: const [
        PopupMenuItem(
          value: true,
          child: Text('Supprimer de Continuer à regarder'),
        ),
      ],
    );
    if (remove == true && mounted) _removeFromResume();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, child) {
        final item = widget.item;
        final favorite = widget.controller.favorites.contains(item.id);
        final progress =
            widget.controller.latestProgressFor(item, unfinishedOnly: true) ??
            widget.controller.latestProgressFor(item);
        final ongoing = widget.controller.canResume(item);
        final accent = Theme.of(context).colorScheme.primary;
        return MouseRegion(
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onSecondaryTapDown: ongoing
                ? (details) => _showContextMenu(details.globalPosition)
                : null,
            onLongPressStart: ongoing
                ? (details) => _showContextMenu(details.globalPosition)
                : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: AnimatedContainer(
                    duration: Duration(
                      milliseconds: widget.controller.settings.animations
                          ? 160
                          : 0,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _hover
                            ? accent.withAlpha(180)
                            : const Color(0xFF242936),
                      ),
                      boxShadow: _hover
                          ? [
                              BoxShadow(
                                color: Color(item.palette).withAlpha(35),
                                blurRadius: 22,
                                offset: const Offset(0, 5),
                              ),
                            ]
                          : const [],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        MediaArtwork(item: item, controller: widget.controller),
                        Material(
                          type: MaterialType.transparency,
                          child: InkWell(
                            onTap: widget.onTap,
                            focusColor: accent.withAlpha(65),
                            hoverColor: Colors.white.withAlpha(8),
                            child: Semantics(
                              button: true,
                              label: 'Consulter ${item.title}',
                              child: const SizedBox.expand(),
                            ),
                          ),
                        ),
                        if (item.isDemo)
                          Positioned(
                            top: 10,
                            left: 10,
                            child: IgnorePointer(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withAlpha(125),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: const Text(
                                  'DÉMO',
                                  style: TextStyle(
                                    fontSize: 9,
                                    letterSpacing: 1,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFFDEE1EB),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        Positioned(
                          top: 6,
                          right: 6,
                          child: IconButton.filledTonal(
                            tooltip: favorite
                                ? 'Retirer ${item.title} des favoris'
                                : 'Ajouter ${item.title} aux favoris',
                            onPressed: () =>
                                widget.controller.toggleFavorite(item.id),
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.black.withAlpha(135),
                              foregroundColor: favorite
                                  ? const Color(0xFFF88BAB)
                                  : Colors.white,
                              minimumSize: const Size(36, 36),
                              padding: const EdgeInsets.all(8),
                            ),
                            icon: Icon(
                              favorite
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              size: 18,
                            ),
                          ),
                        ),
                        if (progress != null && progress.fraction > 0)
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: LinearProgressIndicator(
                              value: progress.fraction,
                              minHeight: 3,
                              color: accent,
                              backgroundColor: Colors.white.withAlpha(35),
                              semanticsLabel: 'Progression de ${item.title}',
                              semanticsValue:
                                  '${(progress.fraction * 100).round()} %',
                            ),
                          ),
                        if (ongoing)
                          Positioned(
                            bottom: 8,
                            right: 6,
                            child: PopupMenuButton<bool>(
                              tooltip: 'Options de reprise pour ${item.title}',
                              popUpAnimationStyle: AnimationStyle.noAnimation,
                              icon: const Icon(Icons.more_horiz_rounded),
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.black87,
                              ),
                              onSelected: (_) => _removeFromResume(),
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                  value: true,
                                  child: Text(
                                    'Supprimer de Continuer à regarder',
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.kind == MediaKind.live
                      ? '${item.category}${item.isDemo ? ' · Chaîne fictive' : ''}'
                      : '${item.year > 0 ? '${item.year} · ' : ''}${item.category}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: novaMuted, fontSize: 12),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class MediaRail extends StatefulWidget {
  const MediaRail({
    super.key,
    required this.controller,
    required this.items,
    required this.onDetails,
  });

  final AppController controller;
  final List<MediaItem> items;
  final void Function(MediaItem) onDetails;

  @override
  State<MediaRail> createState() => _MediaRailState();
}

class _MediaRailState extends State<MediaRail> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, child) {
        final width =
            (NovaAdaptiveScope.isAndroid(context) ? 132 : 180) *
            widget.controller.settings.posterScale;
        return SizedBox(
          height: width * 1.5 + 64,
          child: Scrollbar(
            controller: _scrollController,
            notificationPredicate: (notification) => notification.depth == 0,
            child: ListView.builder(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(bottom: 12),
              itemCount: widget.items.length,
              itemBuilder: (context, index) => Padding(
                padding: EdgeInsets.only(
                  right: index == widget.items.length - 1 ? 0 : 18,
                ),
                child: SizedBox(
                  width: width,
                  child: MediaPoster(
                    key: ValueKey(widget.items[index].id),
                    controller: widget.controller,
                    item: widget.items[index],
                    onTap: () => widget.onDetails(widget.items[index]),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

String _searchText(MediaItem item) => _normalize(
  '${item.title} ${item.category} ${item.subtitle} ${item.description}',
);

String _normalize(String value) {
  var normalized = value.toLowerCase();
  const characters = {
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
    '’': "'",
  };
  for (final entry in characters.entries) {
    normalized = normalized.replaceAll(entry.key, entry.value);
  }
  return normalized;
}
