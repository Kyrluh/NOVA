import 'package:flutter/material.dart';

import '../../domain/models.dart';
import '../../domain/catalog_preferences.dart';
import '../../player/nova_player.dart';
import '../../state/app_controller.dart';
import '../theme.dart';
import 'tv_widgets.dart';
import '../widgets/search_field.dart';
import '../../player/tv_channel_panel.dart';

class TvLive extends StatefulWidget {
  const TvLive({
    super.key,
    required this.controller,
    this.nativeReady = true,
    this.initialChannelId,
  });
  final AppController controller;
  final bool nativeReady;
  final String? initialChannelId;
  @override
  State<TvLive> createState() => TvLiveState();
}

class TvLiveState extends State<TvLive> {
  bool _watching = true;
  bool _playerMounted = false;
  bool handleBack() {
    if (!_playerMounted) return false;
    _back.value++;
    return true;
  }

  final _fullscreen = ValueNotifier<int>(0);
  final _back = ValueNotifier<int>(0);
  final _search = TextEditingController();
  final _firstChannelFocus = FocusNode(debugLabel: 'TV first channel');
  late String? _selectedId = widget.initialChannelId;
  String? _category;
  @override
  void dispose() {
    _fullscreen.dispose();
    _back.dispose();
    _search.dispose();
    _firstChannelFocus.dispose();
    super.dispose();
  }

  void _change(List<MediaItem> channels, MediaItem selected, int delta) {
    final index = channels.indexWhere((c) => c.id == selected.id);
    final next = index + delta;
    if (index >= 0 && next >= 0 && next < channels.length) {
      _selectChannel(channels[next]);
    }
  }

  void _selectChannel(MediaItem channel) {
    setState(() {
      _selectedId = channel.id;
      _watching = true;
    });
    widget.controller.recordProgress(
      channel.id,
      WatchProgress(
        positionSeconds: 0,
        durationSeconds: 0,
        lastWatched: DateTime.now(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final app = widget.controller;
      final all = app.items.where((i) => i.kind == MediaKind.live).toList();
      if (_category != null && !all.any((i) => i.category == _category)) {
        _category = null;
      }
      final channels = all
          .where(
            (i) =>
                (_category == null || i.category == _category) &&
                i.title.toLowerCase().contains(
                  _search.text.trim().toLowerCase(),
                ),
          )
          .toList();
      final selected =
          all.where((i) => i.id == _selectedId).firstOrNull ??
          channels.firstOrNull;
      _playerMounted =
          _watching &&
          selected?.mediaUrl?.isNotEmpty == true &&
          widget.nativeReady;
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 4,
            child: Column(
              children: [
                NovaSearchField(
                  television: true,
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) {
                    if (channels.isNotEmpty) _firstChannelFocus.requestFocus();
                  },
                  decoration: const InputDecoration(
                    labelText: 'Rechercher une chaîne',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  key: ValueKey('tv-live-group-${_category ?? 'all'}'),
                  initialValue: _category,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Catégorie'),
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('Toutes les chaînes'),
                    ),
                    for (final group in all.map((i) => i.category).toSet())
                      DropdownMenuItem(
                        value: group,
                        child: Text(group, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (value) => setState(() => _category = value),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<CatalogOrder>(
                  key: ValueKey(
                    'tv-live-order-${app.catalogPreferences.ruleFor(MediaKind.live).order.name}',
                  ),
                  initialValue: app.catalogPreferences
                      .ruleFor(MediaKind.live)
                      .order,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Ordre des chaînes',
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
                      value: CatalogOrder.category,
                      child: Text('Mes catégories'),
                    ),
                    DropdownMenuItem(
                      value: CatalogOrder.yearDesc,
                      child: Text('Année'),
                    ),
                  ],
                  onChanged: (order) {
                    if (order != null) {
                      app.updateCatalogPreferences(
                        app.catalogPreferences.copyWithRule(
                          MediaKind.live,
                          app.catalogPreferences
                              .ruleFor(MediaKind.live)
                              .copyWith(order: order),
                        ),
                      );
                    }
                  },
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: ListView.separated(
                    itemCount: channels.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final item = channels[index];
                      return TvTile(
                        key: ValueKey('tv-channel-${item.id}'),
                        focusNode: index == 0 ? _firstChannelFocus : null,
                        selected: selected?.id == item.id,
                        label: item.title,
                        onPressed: () {
                          if (_watching &&
                              selected?.id == item.id &&
                              _selectedId == item.id) {
                            _fullscreen.value++;
                          } else {
                            _selectChannel(item);
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 13,
                          ),
                          child: Text(
                            item.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            flex: 7,
            child: selected == null
                ? const Center(
                    child: Text('Ajoutez une source ou changez vos filtres.'),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _playerMounted
                            ? NovaPlayer(
                                key: const ValueKey('tv-live-player'),
                                television: true,
                                pictureInPicture: false,
                                touchGestures: false,
                                handleBackInternally: false,
                                uri: selected.mediaUrl!,
                                title: selected.title,
                                isLive: true,
                                fullscreenRequests: _fullscreen,
                                backRequests: _back,
                                onClose: () {
                                  setState(() => _watching = false);
                                  WidgetsBinding.instance.addPostFrameCallback((
                                    _,
                                  ) {
                                    if (mounted) {
                                      _firstChannelFocus.requestFocus();
                                    }
                                  });
                                },
                                initialVolume: app.settings.volume,
                                reconnectEnabled: app.settings.reconnectEnabled,
                                reconnectAttempts:
                                    app.settings.reconnectAttempts,
                                reconnectDelaySeconds:
                                    app.settings.reconnectDelaySeconds,
                                onPreviousChannel: () =>
                                    _change(channels, selected, -1),
                                onNextChannel: () =>
                                    _change(channels, selected, 1),
                                channelChoices: [
                                  for (final channel in all)
                                    TvChannelOption(
                                      id: channel.id,
                                      title: channel.title,
                                      category: channel.category,
                                    ),
                                ],
                                selectedChannelId: selected.id,
                                onSelectChannel: (id) {
                                  final channel = all
                                      .where((c) => c.id == id)
                                      .firstOrNull;
                                  if (channel != null) {
                                    _category = channel.category;
                                    _search.clear();
                                    _selectChannel(channel);
                                  }
                                },
                              )
                            : const Center(
                                child: Icon(
                                  Icons.live_tv,
                                  size: 64,
                                  color: novaMuted,
                                ),
                              ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        selected.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          FilledButton.icon(
                            onPressed: () {
                              if (!_watching) setState(() => _watching = true);
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (mounted) _fullscreen.value++;
                              });
                              WidgetsBinding.instance.scheduleFrame();
                            },
                            icon: const Icon(Icons.fullscreen),
                            label: const Text('Regarder'),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            tooltip: 'Favori',
                            onPressed: () => app.toggleFavorite(selected.id),
                            icon: Icon(
                              app.favorites.contains(selected.id)
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Builder(
                        builder: (context) {
                          final now = DateTime.now();
                          final current = app
                              .guideFor(selected)
                              .where(
                                (p) =>
                                    !p.start.isAfter(now) && p.end.isAfter(now),
                              )
                              .firstOrNull;
                          return Text(
                            current == null
                                ? 'OK : choisir la chaîne · OK à nouveau : plein écran'
                                : '${current.title}\n${current.description}',
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: novaMuted),
                          );
                        },
                      ),
                    ],
                  ),
          ),
        ],
      );
    },
  );
}
