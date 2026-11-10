import 'package:flutter/material.dart';

import '../widgets/platform_logo.dart';

import '../../domain/models.dart';
import '../../domain/platform_catalog.dart';
import '../../state/app_controller.dart';
import '../theme.dart';
import '../adaptive.dart';
import 'catalog_page.dart';
import '../widgets/internet_catalog_widgets.dart';

class PlatformsPage extends StatefulWidget {
  const PlatformsPage({
    super.key,
    required this.controller,
    required this.onDetails,
  });
  final AppController controller;
  final void Function(MediaItem) onDetails;
  @override
  State<PlatformsPage> createState() => _PlatformsPageState();
}

class _PlatformsPageState extends State<PlatformsPage> {
  CatalogPlatform? _selected;
  bool _browsing = false;
  MediaKind? _kind;
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _select(CatalogPlatform? platform) => setState(() {
    _selected = platform;
    _browsing = true;
    _kind = null;
    _search.clear();
  });

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) {
      final app = widget.controller;
      final catalog = app.items
          .where((item) => item.kind != MediaKind.live)
          .toList();
      final groups = <CatalogPlatform?, List<MediaItem>>{
        for (final platform in CatalogPlatform.values) platform: [],
        null: [],
      };
      for (final item in catalog) {
        final platforms = app.platformsFor(item);
        if (platforms.isEmpty) groups[null]!.add(item);
        for (final platform in platforms) {
          groups[platform]!.add(item);
        }
      }
      if (!_browsing) return _overview(groups);
      final label = _selected?.label ?? 'À identifier';
      final query = _search.text.trim().toLowerCase();
      final items = groups[_selected]!
          .where(
            (item) =>
                (_kind == null || item.kind == _kind) &&
                (query.isEmpty ||
                    '${item.title} ${item.category}'.toLowerCase().contains(
                      query,
                    )),
          )
          .toList();
      return CatalogGrid(
        key: ValueKey('platform-${_selected?.name ?? 'other'}'),
        controller: app,
        items: items,
        onDetails: widget.onDetails,
        title: label,
        headerAction: InternetCatalogControls(controller: app),
        subtitle: _selected == null
            ? 'Les contenus dont la plateforme reste à préciser.'
            : 'Les films et séries $label présents dans vos sources.',
        emptyTitle: 'Aucun contenu pour le moment',
        emptyMessage: query.isNotEmpty || _kind != null
            ? 'Essayez une autre recherche ou affichez tous les contenus.'
            : 'Associez les catégories de vos sources à cette plateforme pour retrouver leurs contenus ici.',
        controls: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InternetCatalogStatus(controller: app),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                TextButton.icon(
                  onPressed: () => setState(() => _browsing = false),
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: const Text('Toutes les plateformes'),
                ),
                if (_selected != null)
                  OutlinedButton.icon(
                    onPressed: () => _configure(_selected!),
                    icon: const Icon(Icons.tune_rounded, size: 18),
                    label: const Text('Associer des catégories'),
                  ),
                if (_selected != null &&
                    (app.internetCatalog
                            ?.availableSelection(_selected!, app.items)
                            .isNotEmpty ??
                        false))
                  TextButton.icon(
                    onPressed: () => showInternetSelection(
                      context,
                      app,
                      _selected!,
                      widget.onDetails,
                    ),
                    icon: const Icon(Icons.explore_outlined),
                    label: const Text('Voir les titres disponibles'),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            if (_selected != null) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Color(_selected!.color).withAlpha(18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    _logo(_selected, 66),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Text(
                        'Votre sélection $label',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    const Icon(
                      Icons.play_circle_outline_rounded,
                      color: novaMuted,
                      size: 32,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
            ],
            TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Rechercher dans $label',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Effacer la recherche',
                        onPressed: () => setState(_search.clear),
                        icon: const Icon(Icons.close_rounded),
                      ),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final kind in [null, MediaKind.movie, MediaKind.series])
                  ChoiceChip(
                    label: Text(switch (kind) {
                      null => 'Tout',
                      MediaKind.movie => 'Films',
                      _ => 'Séries',
                    }),
                    selected: _kind == kind,
                    onSelected: (_) => setState(() => _kind = kind),
                  ),
              ],
            ),
          ],
        ),
      );
    },
  );

  Widget _overview(Map<CatalogPlatform?, List<MediaItem>> groups) =>
      CustomScrollView(
        key: const PageStorageKey('platform-overview'),
        slivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              novaPageInset(context),
              20,
              novaPageInset(context),
              26,
            ),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LayoutBuilder(
                    builder: (context, bounds) {
                      final title = Text(
                        'Par PlateForme',
                        style: Theme.of(context).textTheme.headlineLarge,
                      );
                      final controls = InternetCatalogControls(
                        controller: widget.controller,
                      );
                      return bounds.maxWidth < 650
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                title,
                                const SizedBox(height: 12),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: controls,
                                ),
                              ],
                            )
                          : Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: title),
                                controls,
                              ],
                            );
                    },
                  ),
                  InternetCatalogStatus(controller: widget.controller),
                  const SizedBox(height: 10),
                  const Text(
                    'Vos univers préférés, au même endroit.',
                    style: TextStyle(color: novaMuted, fontSize: 16),
                  ),
                  const SizedBox(height: 25),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(26),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: const LinearGradient(
                        colors: [Color(0xff292044), Color(0xff141d30)],
                      ),
                      border: Border.all(color: const Color(0xff39314f)),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'UNE ENVIE. UNE PLATEFORME.',
                          style: TextStyle(
                            fontSize: 10,
                            letterSpacing: 2,
                            color: Color(0xffbda6f3),
                          ),
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Choisissez votre prochain univers.',
                          style: TextStyle(
                            fontSize: 27,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 10),
                        Text(
                          'Retrouvez les films et séries de vos sources réunis par plateforme.',
                          style: TextStyle(color: novaMuted, height: 1.5),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: novaPageInset(context)),
            sliver: SliverGrid.builder(
              gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: MediaQuery.sizeOf(context).width < 600
                    ? 500
                    : 310,
                mainAxisExtent: MediaQuery.sizeOf(context).width < 600
                    ? 112
                    : 136,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: CatalogPlatform.values.length + 1,
              itemBuilder: (context, index) {
                final platform = index < CatalogPlatform.values.length
                    ? CatalogPlatform.values[index]
                    : null;
                final items = groups[platform]!;
                final movies = items
                    .where((item) => item.kind == MediaKind.movie)
                    .length;
                final series = items.length - movies;
                final color = Color(platform?.color ?? 0xff8b5cf6);
                return Material(
                  color: Color.lerp(const Color(0xff151923), color, .08),
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    key: ValueKey('platform-tile-${platform?.name ?? 'other'}'),
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => _select(platform),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: color.withAlpha(65)),
                      ),
                      child: Row(
                        children: [
                          _logo(platform, 66),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  platform?.label ?? 'À identifier',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  items.isEmpty
                                      ? 'À découvrir'
                                      : '$movies films · $series séries',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: novaMuted,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Explorer  →',
                                  style: TextStyle(fontSize: 11, color: color),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              novaPageInset(context),
              26,
              novaPageInset(context),
              36,
            ),
            sliver: const SliverToBoxAdapter(
              child: Text(
                'Le classement suit les catégories de vos sources. Pour le préciser, ouvrez une plateforme puis « Associer des catégories ».',
                style: TextStyle(color: novaMuted, fontSize: 12, height: 1.6),
              ),
            ),
          ),
        ],
      );

  Widget _logo(CatalogPlatform? platform, double size) => SizedBox(
    width: size,
    height: size,
    child: platform == null
        ? const Icon(Icons.video_library_outlined, size: 38, color: novaMuted)
        : PlatformLogo(platform: platform, width: size, height: size),
  );

  Future<void> _configure(CatalogPlatform platform) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _PlatformGroupsDialog(
        controller: widget.controller,
        platform: platform,
      ),
    );
  }
}

class _PlatformGroupsDialog extends StatefulWidget {
  const _PlatformGroupsDialog({
    required this.controller,
    required this.platform,
  });
  final AppController controller;
  final CatalogPlatform platform;
  @override
  State<_PlatformGroupsDialog> createState() => _PlatformGroupsDialogState();
}

class _PlatformGroupsDialogState extends State<_PlatformGroupsDialog> {
  final _search = TextEditingController();
  final _groups = <String, MediaItem>{};
  final _counts = <String, int>{};
  final _selected = <String>{};
  final _changed = <String>{};

  @override
  void initState() {
    super.initState();
    final app = widget.controller;
    for (final item in app.items.where((item) => item.kind != MediaKind.live)) {
      final key = PlatformPreferences.groupKey(item.kind, item.category);
      _groups[key] = item;
      _counts[key] = (_counts[key] ?? 0) + 1;
      if (app.platformPreferences
          .platformsFor(item)
          .contains(widget.platform)) {
        _selected.add(key);
      }
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _save() {
    final app = widget.controller;
    final preferences = app.platformPreferences;
    final changes = <String, Set<CatalogPlatform>?>{};
    for (final key in _changed) {
      final item = _groups[key]!;
      final platforms = Set<CatalogPlatform>.of(preferences.platformsFor(item));
      if (_selected.contains(key)) {
        platforms.add(widget.platform);
      } else {
        platforms.remove(widget.platform);
      }
      final automatic = detectPlatforms(item.category);
      changes[key] =
          platforms.length == automatic.length &&
              platforms.containsAll(automatic)
          ? null
          : platforms;
    }
    app.updatePlatformPreferences(preferences.updateGroups(changes));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.toLowerCase().trim();
    final keys =
        _groups.keys
            .where(
              (key) => _groups[key]!.category.toLowerCase().contains(query),
            )
            .toList()
          ..sort(
            (a, b) => _groups[a]!.category.compareTo(_groups[b]!.category),
          );
    return AlertDialog(
      title: Text('Catégories · ${widget.platform.label}'),
      content: SizedBox(
        width: 600,
        height: 420,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Choisissez les catégories à retrouver dans cette plateforme.',
              style: TextStyle(color: novaMuted),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'Rechercher une catégorie',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: keys.isEmpty
                  ? const Center(child: Text('Aucune catégorie disponible'))
                  : ListView.builder(
                      itemCount: keys.length,
                      itemBuilder: (context, index) {
                        final key = keys[index];
                        final item = _groups[key]!;
                        return CheckboxListTile(
                          key: ValueKey('platform-group-$key'),
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            item.category,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            '${item.kind == MediaKind.movie ? 'Films' : 'Séries'} · ${_counts[key]} contenus',
                          ),
                          value: _selected.contains(key),
                          onChanged: (value) => setState(() {
                            _changed.add(key);
                            if (value == true) {
                              _selected.add(key);
                            } else {
                              _selected.remove(key);
                            }
                          }),
                        );
                      },
                    ),
            ),
            TextButton(
              onPressed: () => setState(() {
                _changed.addAll(_groups.keys);
                _selected.clear();
                for (final entry in _groups.entries) {
                  if (detectPlatforms(entry.value.category)
                      .contains(widget.platform)) {
                    _selected.add(entry.key);
                  }
                }
              }),
              child: const Text('Rétablir le classement automatique'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton(onPressed: _save, child: const Text('Enregistrer')),
      ],
    );
  }
}
