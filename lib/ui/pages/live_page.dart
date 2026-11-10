import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/models.dart';
import '../../domain/catalog_preferences.dart';
import '../../domain/source_models.dart';
import '../../player/nova_player.dart';
import '../../player/desktop_fullscreen.dart';
import '../../state/app_controller.dart';
import '../theme.dart';
import '../adaptive.dart';
import '../widgets/artwork.dart';

class LivePage extends StatefulWidget {
  const LivePage({
    super.key,
    required this.controller,
    required this.onOpenUrl,
    this.nativeReady = true,
    this.onManageSources,
    this.fullscreenController,
    this.playerBuilder,
  });

  final AppController controller;
  final VoidCallback onOpenUrl;
  final bool nativeReady;
  final VoidCallback? onManageSources;
  final DesktopFullscreen? fullscreenController;
  @visibleForTesting
  final Widget Function(MediaItem, VoidCallback onReleased)? playerBuilder;

  @override
  LivePageState createState() => LivePageState();
}

class LivePageState extends State<LivePage> {
  static const _all = 'Toutes les chaînes';
  static const _favorites = 'Mes favoris';
  final _search = TextEditingController();
  final _channelsScroll = ScrollController();
  final _previewKey = GlobalKey(debugLabel: 'fold-stable-tv-preview');
  final _fullscreenRequests = ValueNotifier<int>(0);
  double? _inlineVideoHeight;
  String _category = _all;
  String? _selectedId;
  Timer? _guideTick;
  bool _playbackSuspended = false;
  Completer<void>? _playerRelease;
  bool get playbackSuspended => _playbackSuspended;
  String? get selectedId => _selectedId;

  Future<void> suspendPlayback() async {
    if (!mounted) return;
    final release = _playerRelease;
    if (!_playbackSuspended) setState(() => _playbackSuspended = true);
    await WidgetsBinding.instance.endOfFrame;
    if (release != null) await release.future;
  }

  Future<void> resumePlayback() async {
    final release = _playerRelease;
    if (release != null) await release.future;
    if (!mounted || !_playbackSuspended) return;
    setState(() {
      _playerRelease = null;
      _playbackSuspended = false;
    });
  }

  @override
  void initState() {
    super.initState();
    _search.addListener(_updateSearch);
    _guideTick = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  void _updateSearch() => setState(() {});

  @override
  void dispose() {
    _search.removeListener(_updateSearch);
    _search.dispose();
    _channelsScroll.dispose();
    _guideTick?.cancel();
    _fullscreenRequests.dispose();
    super.dispose();
  }

  List<MediaItem> get _channels => widget.controller.items
      .where((item) => item.kind == MediaKind.live)
      .toList();

  List<MediaItem> _filter(List<MediaItem> channels) {
    final query = _search.text.trim().toLowerCase();
    return channels.where((item) {
      final categoryMatches =
          _category == _all ||
          (_category == _favorites
              ? widget.controller.favorites.contains(item.id)
              : item.category == _category);
      return categoryMatches &&
          (query.isEmpty ||
              '${item.title} ${item.category}'.toLowerCase().contains(query));
    }).toList();
  }

  void _chooseCategory(String category) {
    setState(() => _category = category);
    if (_channelsScroll.hasClients) _channelsScroll.jumpTo(0);
  }

  void _select(MediaItem item) {
    setState(() => _selectedId = item.id);
    if (!item.isDemo && item.mediaUrl?.isNotEmpty == true) {
      widget.controller.recordProgress(
        item.id,
        WatchProgress(
          positionSeconds: 0,
          durationSeconds: 0,
          lastWatched: DateTime.now(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final channels = _channels;
      final filtered = _filter(channels);
      final matchingSelection =
          (!widget.controller.isDemo && _selectedId != null
                  ? channels
                  : filtered)
              .where((item) => item.id == _selectedId);
      final selected = matchingSelection.isNotEmpty
          ? matchingSelection.first
          : filtered.isEmpty
          ? null
          : filtered.first;
      final categories = [
        _all,
        _favorites,
        ...channels.map((item) => item.category).toSet(),
      ];
      return LayoutBuilder(
        builder: (context, constraints) {
          if (NovaAdaptiveScope.isAndroid(context)) {
            return _mobileLayout(
              constraints,
              channels,
              filtered,
              selected,
              categories,
            );
          }
          final wide = constraints.maxWidth >= 740;
          final stacked = constraints.maxWidth < 570;
          if (stacked) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(22, 24, 22, 30),
              children: [
                _heading(channels.length),
                const SizedBox(height: 22),
                _categoryChips(categories, channels),
                const SizedBox(height: 14),
                SizedBox(height: 330, child: _channelPanel(filtered, selected)),
                const SizedBox(height: 22),
                _persistentPreview(selected),
              ],
            );
          }
          return Padding(
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 26),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _heading(channels.length),
                const SizedBox(height: 24),
                if (!wide) ...[
                  _categoryChips(categories, channels),
                  const SizedBox(height: 16),
                ],
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (wide) ...[
                        SizedBox(
                          width: 130,
                          child: _categoryPanel(categories, channels),
                        ),
                        const SizedBox(width: 14),
                      ],
                      SizedBox(
                        width: wide ? 220 : 200,
                        child: _channelPanel(filtered, selected),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: SingleChildScrollView(
                          child: _persistentPreview(selected),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );

  Widget _persistentPreview(MediaItem? selected, {bool compact = false}) =>
      KeyedSubtree(
        key: _previewKey,
        child: _preview(selected, compact: compact),
      );

  Widget _mobileLayout(
    BoxConstraints bounds,
    List<MediaItem> channels,
    List<MediaItem> filtered,
    MediaItem? selected,
    List<String> categories,
  ) {
    final short = bounds.maxHeight < 460;
    final horizontal =
        bounds.maxWidth >= 540 || (short && bounds.maxWidth >= 500);
    _inlineVideoHeight = horizontal
        ? (bounds.maxHeight - 115).clamp(96.0, 360.0)
        : (bounds.maxHeight * .30).clamp(96.0, 240.0);
    final separateGuide =
        bounds.maxWidth >= 1100 &&
        selected != null &&
        !widget.controller.isDemo;
    final features = MediaQuery.of(context).displayFeatures;
    final hinge = features
        .where((f) => f.bounds.width > 0 && f.bounds.height > f.bounds.width)
        .firstOrNull;
    var gap = 14.0;
    var panelWidth = (bounds.maxWidth * .29).clamp(170.0, 230.0);
    if (hinge != null) {
      final window = MediaQuery.sizeOf(context);
      final contentLeft =
          window.width - bounds.maxWidth - MediaQuery.paddingOf(context).right;
      final hingeLeft = hinge.bounds.left - contentLeft - 8;
      final hingeRight = hinge.bounds.right - contentLeft - 8;
      if (hingeLeft >= 180 && bounds.maxWidth - 32 - hingeRight >= 260) {
        panelWidth = hingeLeft - 7;
        gap = hinge.bounds.width + 14;
      }
    }
    final top = <Widget>[
      if (bounds.maxHeight >= 320) ...[
        _categoryChips(categories, channels),
        const SizedBox(height: 8),
      ],
    ];
    if (horizontal) {
      return Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            ...top,
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: panelWidth,
                    child: _channelPanel(filtered, selected),
                  ),
                  SizedBox(width: gap),
                  Expanded(
                    child: SingleChildScrollView(
                      child: _persistentPreview(selected, compact: true),
                    ),
                  ),
                  if (separateGuide) ...[
                    const SizedBox(width: 16),
                    SizedBox(
                      width: 250,
                      child: SingleChildScrollView(child: _realGuide(selected)),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    }
    final preview = _persistentPreview(selected, compact: true);
    if (bounds.maxHeight < 300) {
      // Keep the session mounted while the search keyboard occupies the screen.
      return Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            Offstage(child: preview),
            Expanded(child: _channelPanel(filtered, selected)),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          ...top,
          preview,
          const SizedBox(height: 8),
          Expanded(child: _channelPanel(filtered, selected)),
        ],
      ),
    );
  }

  Widget _heading(int count) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Container(
            width: 3,
            height: 24,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'TV en direct',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                letterSpacing: -.8,
              ),
            ),
          ),
          Tooltip(
            message: widget.controller.isDemo
                ? 'Catalogue fictif, sans flux associé'
                : 'Chaînes de vos sources personnelles',
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: novaSurface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF2A2E3C)),
              ),
              child: Text(
                '$count chaînes${widget.controller.isDemo ? ' démo' : ''}',
                style: const TextStyle(fontSize: 11, color: novaMuted),
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 9),
      const Text(
        'Vos chaînes et vos favoris, réunis au même endroit.',
        style: TextStyle(color: novaMuted, fontSize: 13),
      ),
    ],
  );

  int _count(String category, List<MediaItem> channels) => channels
      .where(
        (item) =>
            category == _all ||
            (category == _favorites
                ? widget.controller.favorites.contains(item.id)
                : item.category == category),
      )
      .length;

  Widget _categoryPanel(List<String> categories, List<MediaItem> channels) =>
      Container(
        decoration: BoxDecoration(
          color: novaSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF232733)),
        ),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(8, 18, 8, 10),
          children: [
            const Padding(
              padding: EdgeInsets.only(left: 6, bottom: 16),
              child: Text(
                'CATÉGORIES',
                style: TextStyle(
                  color: novaMuted,
                  fontSize: 9,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            for (final category in categories)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Material(
                  color: _category == category
                      ? Theme.of(context).colorScheme.primary.withAlpha(35)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  child: InkWell(
                    onTap: () => _chooseCategory(category),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 12,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (category == _favorites)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 5),
                              child: Icon(
                                Icons.favorite_outline_rounded,
                                size: 16,
                                color: _category == category
                                    ? Theme.of(context).colorScheme.primary
                                    : novaMuted,
                              ),
                            ),
                          Text(
                            category,
                            style: TextStyle(
                              fontSize: 11,
                              color: _category == category
                                  ? Colors.white
                                  : novaMuted,
                              fontWeight: _category == category
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${_count(category, channels)}',
                            style: TextStyle(
                              fontSize: 10,
                              color: _category == category
                                  ? Theme.of(context).colorScheme.primary
                                  : novaMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );

  Widget _categoryChips(List<String> categories, List<MediaItem> channels) =>
      SizedBox(
        height: 43,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: categories.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final category = categories[index];
            return ChoiceChip(
              label: Text('$category  ${_count(category, channels)}'),
              selected: _category == category,
              onSelected: (_) => _chooseCategory(category),
            );
          },
        ),
      );

  Widget _channelPanel(List<MediaItem> filtered, MediaItem? selected) =>
      Container(
        decoration: BoxDecoration(
          color: novaSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF232733)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 17, 14, 13),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'CHAÎNES',
                      style: TextStyle(
                        color: novaMuted,
                        fontSize: 10,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    '${filtered.length}',
                    style: const TextStyle(color: novaMuted, fontSize: 11),
                  ),
                  if (NovaAdaptiveScope.isAndroid(context))
                    PopupMenuButton<CatalogOrder>(
                      key: const ValueKey('tv-channel-order'),
                      tooltip: 'Ordre des chaînes',
                      popUpAnimationStyle: AnimationStyle.noAnimation,
                      icon: const Icon(Icons.sort_rounded, size: 20),
                      onSelected: (order) {
                        final app = widget.controller;
                        app.updateCatalogPreferences(
                          app.catalogPreferences.copyWithRule(
                            MediaKind.live,
                            app.catalogPreferences
                                .ruleFor(MediaKind.live)
                                .copyWith(order: order),
                          ),
                        );
                      },
                      itemBuilder: (_) => [
                        for (final entry in const {
                          CatalogOrder.source: 'Ordre de la source',
                          CatalogOrder.titleAsc: 'Titre · A → Z',
                          CatalogOrder.titleDesc: 'Titre · Z → A',
                          CatalogOrder.category: 'Mes catégories',
                        }.entries)
                          CheckedPopupMenuItem<CatalogOrder>(
                            value: entry.key,
                            checked:
                                widget.controller.catalogPreferences
                                    .ruleFor(MediaKind.live)
                                    .order ==
                                entry.key,
                            child: Text(entry.value),
                          ),
                      ],
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: TextField(
                controller: _search,
                style: const TextStyle(fontSize: 12),
                decoration: InputDecoration(
                  hintText: 'Rechercher une chaîne',
                  hintStyle: const TextStyle(color: novaMuted, fontSize: 11),
                  prefixIcon: const Icon(Icons.search_rounded, size: 17),
                  prefixIconConstraints: const BoxConstraints(minWidth: 32),
                  suffixIcon: _search.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Effacer la recherche',
                          onPressed: _search.clear,
                          icon: const Icon(Icons.close_rounded, size: 14),
                        ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 12,
                  ),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: filtered.isEmpty
                  ? _emptyChannels()
                  : Focus(
                      onKeyEvent: (_, event) =>
                          _navigateChannels(event, filtered, selected),
                      child: ListView.builder(
                        key: const ValueKey('tv-channel-list'),
                        controller: _channelsScroll,
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: ClampingScrollPhysics(),
                        ),
                        padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
                        itemExtent: NovaAdaptiveScope.isAndroid(context)
                            ? 72
                            : 86,
                        itemCount: filtered.length,
                        itemBuilder: (_, index) => _channelTile(
                          filtered[index],
                          selected?.id == filtered[index].id,
                          index,
                        ),
                      ),
                    ),
            ),
            if (!NovaAdaptiveScope.isAndroid(context))
              const Padding(
                padding: EdgeInsets.fromLTRB(14, 10, 14, 14),
                child: Text(
                  '↑ ↓ pour parcourir les chaînes',
                  style: TextStyle(color: novaMuted, fontSize: 10),
                ),
              ),
          ],
        ),
      );

  KeyEventResult _navigateChannels(
    KeyEvent event,
    List<MediaItem> items,
    MediaItem? selected,
  ) {
    if (event is! KeyDownEvent || items.isEmpty) return KeyEventResult.ignored;
    final delta = event.logicalKey == LogicalKeyboardKey.arrowDown
        ? 1
        : event.logicalKey == LogicalKeyboardKey.arrowUp
        ? -1
        : 0;
    if (delta == 0) return KeyEventResult.ignored;
    final current = items.indexWhere((item) => item.id == selected?.id);
    final next = (current + delta).clamp(0, items.length - 1);
    _select(items[next]);
    if (_channelsScroll.hasClients) {
      _channelsScroll.animateTo(
        (next * (NovaAdaptiveScope.isAndroid(context) ? 72.0 : 86.0)).clamp(
          0.0,
          _channelsScroll.position.maxScrollExtent,
        ),
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
      );
    }
    return KeyEventResult.handled;
  }

  Widget _emptyChannels() => Center(
    child: SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _category == _favorites
                  ? Icons.favorite_border_rounded
                  : Icons.search_off_rounded,
              color: novaMuted,
              size: 25,
            ),
            const SizedBox(height: 12),
            Text(
              _category == _favorites && _search.text.isEmpty
                  ? 'Vos chaînes favorites apparaîtront ici.'
                  : 'Aucune chaîne ne correspond à votre recherche.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: novaMuted, fontSize: 12),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _channelTile(MediaItem item, bool selected, int index) {
    final favorite = widget.controller.favorites.contains(item.id);
    final accent = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Material(
        color: selected ? accent.withAlpha(23) : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: selected ? accent.withAlpha(100) : Colors.transparent,
          ),
        ),
        child: InkWell(
          onTap: () => _select(item),
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(9, 10, 0, 10),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 39,
                  decoration: BoxDecoration(
                    color: Color(item.palette).withAlpha(30),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    item.title.substring(0, 1),
                    style: TextStyle(
                      color: Color(item.palette),
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: selected
                              ? Colors.white
                              : const Color(0xFFD2D6E0),
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '${(index + 1).toString().padLeft(2, '0')} · ${item.category}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: novaMuted, fontSize: 9),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: favorite
                      ? 'Retirer des favoris'
                      : 'Ajouter aux favoris',
                  onPressed: () => widget.controller.toggleFavorite(item.id),
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints(
                    minWidth: 28,
                    minHeight: 32,
                  ),
                  padding: const EdgeInsets.all(5),
                  icon: Icon(
                    favorite
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    size: 15,
                    color: favorite ? accent : novaMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _preview(MediaItem? selected, {bool compact = false}) {
    if (!widget.controller.isDemo) {
      if (selected == null) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Aucune chaîne dans cette sélection.',
              style: TextStyle(color: novaMuted),
            ),
            const SizedBox(height: 18),
            if (widget.onManageSources != null)
              OutlinedButton.icon(
                onPressed: widget.onManageSources,
                icon: const Icon(Icons.playlist_add),
                label: const Text('Gérer mes sources'),
              ),
          ],
        );
      }
      return _livePreview(selected, compact: compact);
    }
    final favorite =
        selected != null && widget.controller.favorites.contains(selected.id);
    final accent = Theme.of(context).colorScheme.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              fit: StackFit.expand,
              children: [
                NovaArtwork(
                  color: selected?.palette ?? 0xff6f70e8,
                  variant: selected?.art ?? 0,
                  landscape: true,
                ),
                const ColoredBox(color: Color(0x66090C14)),
                const Positioned(
                  left: 16,
                  top: 16,
                  child: Text(
                    'APERÇU DE LA CHAÎNE',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 9,
                      letterSpacing: 1.6,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(17),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withAlpha(55),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: const Icon(
                      Icons.tv_rounded,
                      color: Colors.white70,
                      size: 29,
                    ),
                  ),
                ),
                const Positioned(
                  left: 16,
                  bottom: 15,
                  child: Text(
                    'Aucun flux associé',
                    style: TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: Text(
                selected?.title ?? 'Votre espace TV',
                style: const TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -.6,
                ),
              ),
            ),
            if (selected != null)
              IconButton(
                tooltip: favorite
                    ? 'Retirer des favoris'
                    : 'Ajouter aux favoris',
                onPressed: () => widget.controller.toggleFavorite(selected.id),
                icon: Icon(
                  favorite
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  size: 21,
                  color: favorite ? accent : novaMuted,
                ),
              ),
          ],
        ),
        if (selected != null) ...[
          const SizedBox(height: 4),
          Text(
            '${selected.category} · Démonstration',
            style: const TextStyle(fontSize: 12, color: novaMuted),
          ),
        ],
        const SizedBox(height: 17),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: novaSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF282D3A)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Aucune source configurée',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 7),
              Text(
                selected == null
                    ? 'Sélectionnez une chaîne pour découvrir sa présentation, ou ouvrez votre propre flux.'
                    : 'Cette chaîne est fictive et aucun flux ne lui est associé. Ouvrez votre propre URL pour démarrer une lecture.',
                style: const TextStyle(
                  color: novaMuted,
                  fontSize: 12,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 15),
              FilledButton.icon(
                onPressed: widget.onOpenUrl,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 15,
                  ),
                ),
                icon: const Icon(Icons.link_rounded, size: 18),
                label: const Text(
                  'Ouvrir mon flux',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        const Row(
          children: [
            Icon(Icons.calendar_today_outlined, color: novaMuted, size: 16),
            SizedBox(width: 10),
            Text(
              'Guide TV',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 13),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(
            color: novaSurface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Aucun programme disponible',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFFD2D6E0),
                ),
              ),
              SizedBox(height: 7),
              Text(
                'Les programmes actuel et suivant apparaîtront avec un guide XMLTV associé à votre source.',
                style: TextStyle(color: novaMuted, fontSize: 11, height: 1.7),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
      ],
    );
  }

  Widget _livePreview(MediaItem item, {bool compact = false}) {
    final started = _selectedId == item.id && item.mediaUrl?.isNotEmpty == true;
    final playing = started && widget.nativeReady && !_playbackSuspended;
    if (playing && (_playerRelease == null || _playerRelease!.isCompleted)) {
      _playerRelease = Completer<void>();
    }
    final release = _playerRelease;
    void released() {
      if (release != null && !release.isCompleted) release.complete();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: LayoutBuilder(
            builder: (context, bounds) => SizedBox(
              height: NovaAdaptiveScope.isAndroid(context)
                  ? (bounds.maxWidth * 9 / 16).clamp(
                      0.0,
                      _inlineVideoHeight ?? double.infinity,
                    )
                  : bounds.maxWidth * 9 / 16,
              child: playing
                  ? widget.playerBuilder?.call(item, released) ??
                        NovaPlayer(
                          onReleased: released,
                          fullscreenController: widget.fullscreenController,
                          key: const ValueKey('live-player'),
                          fullscreenRequests: _fullscreenRequests,
                          uri: item.mediaUrl!,
                          title: item.title,
                          isLive: true,
                          initialVolume: widget.controller.settings.volume,
                          touchGestures:
                              widget.controller.settings.touchGestures,
                          brightnessGestures:
                              widget.controller.settings.brightnessGestures,
                          volumeGestures:
                              widget.controller.settings.volumeGestures,
                          seekGestures: widget.controller.settings.seekGestures,
                          reconnectEnabled:
                              widget.controller.settings.reconnectEnabled,
                          reconnectAttempts:
                              widget.controller.settings.reconnectAttempts,
                          reconnectDelaySeconds:
                              widget.controller.settings.reconnectDelaySeconds,
                          pictureInPicture:
                              widget.controller.settings.pictureInPicture,
                          landscapeFullscreen:
                              widget.controller.settings.landscapeFullscreen,
                        )
                  : ColoredBox(
                      color: novaSurface,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.live_tv_rounded,
                                size: 28,
                                color: novaMuted,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _playbackSuspended
                                    ? 'La TV reprendra au retour de la lecture.'
                                    : widget.nativeReady
                                    ? 'Sélectionnez la chaîne pour démarrer.'
                                    : 'Le moteur vidéo est indisponible.',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: novaMuted,
                                  fontSize: 12,
                                ),
                              ),
                              if (!_playbackSuspended &&
                                  widget.nativeReady &&
                                  item.mediaUrl?.isNotEmpty == true) ...[
                                const SizedBox(height: 12),
                                FilledButton.icon(
                                  onPressed: () => _select(item),
                                  icon: const Icon(Icons.play_arrow_rounded),
                                  label: const Text('Regarder'),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
            ),
          ),
        ),
        SizedBox(height: NovaAdaptiveScope.isAndroid(context) ? 4 : 18),
        Row(
          children: [
            Expanded(
              child: Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: NovaAdaptiveScope.isAndroid(context) ? 14 : 24,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (NovaAdaptiveScope.isAndroid(context) &&
                playing &&
                widget.playerBuilder == null)
              IconButton(
                key: const ValueKey('tv-fullscreen'),
                tooltip: 'Plein écran TV',
                onPressed: () => _fullscreenRequests.value++,
                icon: const Icon(Icons.fullscreen_rounded),
              ),
            IconButton(
              tooltip: widget.controller.favorites.contains(item.id)
                  ? 'Retirer des favoris'
                  : 'Ajouter aux favoris',
              onPressed: () => widget.controller.toggleFavorite(item.id),
              icon: Icon(
                widget.controller.favorites.contains(item.id)
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
              ),
            ),
            if (compact)
              IconButton(
                tooltip: 'Ouvrir le guide TV',
                icon: const Icon(Icons.calendar_view_day_outlined),
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  showDragHandle: true,
                  builder: (context) => SafeArea(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      child: _realGuide(item),
                    ),
                  ),
                ),
              ),
          ],
        ),
        Text(item.category, style: const TextStyle(color: novaMuted)),
        if (!compact) ...[const SizedBox(height: 20), _realGuide(item)],
      ],
    );
  }

  Widget _realGuide(MediaItem item) {
    final now = DateTime.now();
    final programmes = widget.controller.guideFor(item);
    final current = programmes
        .where((p) => !p.start.isAfter(now) && p.end.isAfter(now))
        .firstOrNull;
    final next = programmes.where((p) => p.start.isAfter(now)).firstOrNull;
    final sourceId = item.sourceId;
    final busy = widget.controller.sources?.busyIds.contains(sourceId) ?? false;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: novaSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Guide TV',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              if (sourceId != null)
                IconButton(
                  tooltip: 'Actualiser le guide TV',
                  onPressed: busy
                      ? null
                      : () async {
                          try {
                            await widget.controller.sources?.refreshEpg(
                              sourceId,
                            );
                          } catch (error) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    error is SourceException ? error.message : 'Impossible d’actualiser le guide TV.',
                                  ),
                                ),
                              );
                            }
                          }
                        },
                  icon: busy
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh_rounded, size: 18),
                ),
            ],
          ),
          if (current == null)
            const Text(
              'Aucun programme en cours disponible.',
              style: TextStyle(color: novaMuted, fontSize: 12),
            )
          else ...[
            Text(
              'EN CE MOMENT',
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontSize: 10,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              current.title,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 5),
            Text(
              '${_time(current.start)} – ${_time(current.end)}',
              style: const TextStyle(color: novaMuted, fontSize: 11),
            ),
            const SizedBox(height: 9),
            LinearProgressIndicator(
              value: current.progressAt(now),
              minHeight: 3,
            ),
            if (current.description.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  current.description,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: novaMuted, fontSize: 12),
                ),
              ),
          ],
          if (next != null) ...[
            const SizedBox(height: 18),
            Text(
              'À SUIVRE · ${_time(next.start)}',
              style: const TextStyle(color: novaMuted, fontSize: 10),
            ),
            const SizedBox(height: 5),
            Text(next.title, style: const TextStyle(fontSize: 13)),
          ],
        ],
      ),
    );
  }

  String _time(DateTime time) {
    final local = time.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}
