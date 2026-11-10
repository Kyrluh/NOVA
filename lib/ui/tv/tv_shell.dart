import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../widgets/platform_logo.dart';
import '../pages/profiles_page.dart';
import '../pages/home_hub.dart';

import '../../domain/models.dart';
import '../../domain/platform_catalog.dart';
import '../../state/app_controller.dart';
import '../adaptive.dart';
import '../pages/catalog_organization_page.dart';
import '../pages/sources_page.dart';
import '../widgets/media_artwork.dart';
import '../widgets/source_startup_progress.dart';
import '../theme.dart';
import 'tv_catalog.dart';
import 'tv_details.dart';
import 'tv_live.dart';
import 'tv_widgets.dart';

class NovaTvShell extends StatefulWidget {
  const NovaTvShell({
    super.key,
    required this.controller,
    this.nativeReady = true,
  });
  final AppController controller;
  final bool nativeReady;
  @override
  State<NovaTvShell> createState() => _NovaTvShellState();
}

class _NovaTvShellState extends State<NovaTvShell> {
  static const _sections = {
    'home': ('Accueil', Icons.home_rounded),
    'live': ('TV en direct', Icons.live_tv_rounded),
    'movies': ('Films', Icons.movie_outlined),
    'series': ('Séries', Icons.video_library_outlined),
    'platforms': ('Plateformes', Icons.dashboard_outlined),
    'trends': ('Tendances', Icons.trending_up),
    'resume': ('Reprendre', Icons.history_rounded),
    'favorites': ('Favoris', Icons.favorite_border),
    'history': ('Historique', Icons.history),
    'search': ('Recherche', Icons.search),
    'sources': ('Sources', Icons.cloud_outlined),
    'settings': ('Paramètres', Icons.settings_outlined),
  };
  final _navigation = {
    for (final section in _sections.keys)
      section: FocusNode(debugLabel: 'TV navigation $section'),
  };
  String _section = 'home';
  CatalogPlatform? _platform;
  String? _requestedChannel;
  final _liveKey = GlobalKey<TvLiveState>();
  AppController get app => widget.controller;
  @override
  void dispose() {
    for (final node in _navigation.values) {
      node.dispose();
    }
    super.dispose();
  }

  void _select(String section) => setState(() {
    _section = section;
    _platform = null;
  });
  Future<void> _back() async {
    if (_section == 'live' && (_liveKey.currentState?.handleBack() ?? false)) {
      return;
    }
    if (_section != 'home') {
      _select('home');
      _navigation['home']!.requestFocus();
      return;
    }
    final quit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Quitter NOVA IPTV TV ?'),
        actions: [
          TextButton(
            autofocus: true,
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Rester'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Quitter'),
          ),
        ],
      ),
    );
    if (quit == true) {
      await app.shutdown();
      await SystemNavigator.pop();
    }
  }

  void _details(MediaItem item) {
    if (item.kind == MediaKind.live) {
      setState(() {
        _requestedChannel = item.id;
        _section = 'live';
      });
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TvDetails(controller: app, item: item),
      ),
    );
  }

  void _organize() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => TvPageFrame(
        title: 'Tri et langues',
        child: CatalogOrganizationPage(controller: app),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => NovaAdaptiveScope(
    android: true,
    child: PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.contextMenu): () =>
              _navigation[_section]!.requestFocus(),
        },
        child: FocusTraversalGroup(
          child: Scaffold(
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: MediaQuery.sizeOf(context).width < 900 ? 155 : 185,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.fromLTRB(8, 8, 4, 22),
                            child: Text(
                              'NOVA\nIPTV TV',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 2,
                              ),
                            ),
                          ),
                          Expanded(
                            child: ListView.separated(
                              itemCount: _sections.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 5),
                              itemBuilder: (context, index) {
                                final key = _sections.keys.elementAt(index);
                                final entry = _sections[key]!;
                                return TvTile(
                                  key: ValueKey('tv-nav-$key'),
                                  focusNode: _navigation[key],
                                  autofocus: index == 0,
                                  selected: _section == key,
                                  onPressed: () => _select(key),
                                  label: entry.$1,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 9,
                                      vertical: 11,
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(entry.$2, size: 21),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            entry.$1,
                                            style: const TextStyle(
                                              fontSize: 15,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.only(top: 10),
                            child: Text(
                              'Menu : navigation\nRetour : écran précédent',
                              style: TextStyle(color: novaMuted, fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: Text(
                              _sections[_section]!.$1,
                              style: const TextStyle(
                                fontSize: 27,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (app.sources != null)
                            SourceStartupProgress(controller: app.sources!),
                          if (app.storageError != null)
                            Text(
                              app.storageError!,
                              style: const TextStyle(color: novaMuted),
                            ),
                          Expanded(child: _body()),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _body() => switch (_section) {
    'home' => HomeHub(
      controller: app,
      onNavigate: _select,
      onDetails: _details,
    ),
    'trends' => _home(),
    'live' => TvLive(
      key: _liveKey,
      controller: app,
      nativeReady: widget.nativeReady,
      initialChannelId: _requestedChannel,
    ),
    'movies' => _catalog(
      app.items.where((i) => i.kind == MediaKind.movie).toList(),
    ),
    'series' => _catalog(
      app.items.where((i) => i.kind == MediaKind.series).toList(),
    ),
    'resume' => _catalog(app.resumeItems),
    'favorites' => _catalog(
      app.items.where((i) => app.favorites.contains(i.id)).toList(),
    ),
    'history' => _catalog(_history()),
    'search' => TvCatalog(
      key: const ValueKey('tv-search'),
      controller: app,
      items: app.items,
      onDetails: _details,
      search: true,
    ),
    'platforms' => _platforms(),
    'sources' =>
      app.sources == null
          ? const Center(child: Text('Gestion des sources indisponible.'))
          : SourcesPage(controller: app.sources!, television: true),
    'settings' => _settings(),
    _ => _home(),
  };
  List<MediaItem> _history() {
    final ids = app.recentIds.toSet();
    final items = app.items
        .where(
          (item) => app
              .variantsFor(item)
              .any(
                (variant) =>
                    ids.contains(variant.id) ||
                    variant.seasons.any(
                      (season) => season.episodes.any(
                        (episode) => ids.contains(episode.id),
                      ),
                    ),
              ),
        )
        .toList();
    items.sort(
      (a, b) => (app.latestProgressFor(b)?.lastWatched ?? DateTime(0))
          .compareTo(app.latestProgressFor(a)?.lastWatched ?? DateTime(0)),
    );
    return items;
  }

  Widget _catalog(List<MediaItem> items) => TvCatalog(
    key: ValueKey('tv-catalog-$_section-${_platform?.name}'),
    controller: app,
    items: items,
    onDetails: _details,
    recentCategory: _section == 'movies' || _section == 'series',
  );

  Widget _home() {
    final movies = app.items
        .where((i) => i.kind == MediaKind.movie)
        .take(20)
        .toList();
    final series = app.items
        .where((i) => i.kind == MediaKind.series)
        .take(20)
        .toList();
    final trending = <MediaItem>[];
    final api = app.internetCatalog;
    if (api != null) {
      for (final kind in [MediaKind.movie, MediaKind.series]) {
        for (final title in api.availableTrending(kind, app.items)) {
          final item = api.libraryMatch(title, app.items);
          if (item != null) trending.add(item);
        }
      }
    }
    return ListView(
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: novaSurface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                app.isDemo
                    ? 'Votre télévision, vos sources.'
                    : 'Qu’allez-vous regarder ?',
                style: const TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                app.isDemo
                    ? 'Ajoutez une playlist M3U ou un accès Xtream. Les contenus ci-dessous sont une démonstration.'
                    : 'Direct, films, séries et reprises de lecture.',
                style: const TextStyle(color: novaMuted),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 14,
                children: [
                  FilledButton.icon(
                    onPressed: () => _select('movies'),
                    icon: const Icon(Icons.movie_outlined),
                    label: Text('Explorer les films'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _select('search'),
                    icon: const Icon(Icons.search),
                    label: const Text('Rechercher'),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (app.recentlyAddedItems.isNotEmpty)
          _rail('Récemment ajoutés', app.recentlyAddedItems.take(24).toList()),
        if (trending.isNotEmpty) _rail('Tendances dans vos sources', trending),
        if (movies.isNotEmpty) _rail('Films', movies),
        if (series.isNotEmpty) _rail('Séries', series),
      ],
    );
  }

  Widget _rail(String title, List<MediaItem> items) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(top: 22, bottom: 12),
        child: Text(
          title,
          style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
        ),
      ),
      SizedBox(
        height: 238,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(width: 14),
          itemBuilder: (context, index) {
            final item = items[index];
            return SizedBox(
              width: 145,
              child: TvTile(
                label: 'Ouvrir ${item.title}',
                onPressed: () => _details(item),
                child: Column(
                  children: [
                    Expanded(
                      child: SizedBox(
                        width: double.infinity,
                        child: MediaArtwork(item: item, controller: app),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    ],
  );

  Widget _platforms() {
    final selected = _platform;
    if (selected != null) {
      return Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => _platform = null),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Toutes les plateformes'),
            ),
          ),
          Expanded(
            child: _catalog(
              app.items
                  .where(
                    (i) =>
                        i.kind != MediaKind.live &&
                        app.platformsFor(i).contains(selected),
                  )
                  .toList(),
            ),
          ),
        ],
      );
    }
    return Column(
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed:
                app.internetCatalog == null || app.internetCatalog!.running
                ? null
                : app.internetCatalog!.refresh,
            icon: const Icon(Icons.cloud_sync),
            label: const Text('Mettre a jour par internet'),
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: GridView.count(
            crossAxisCount: 3,
            childAspectRatio: 1.4,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            children: [
              for (final platform in CatalogPlatform.values)
                TvTile(
                  onPressed: () => setState(() => _platform = platform),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        PlatformLogo(
                          platform: platform,
                          height: 34,
                          width: 110,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          platform.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 15),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _settings() => ListView(
    children: [
      ProfileSettingsTile(controller: app),
      ListTile(
        title: const Text('Mes sources'),
        subtitle: const Text(
          'Ajouter M3U / Xtream, actualiser et gérer le guide TV',
        ),
        leading: const Icon(Icons.cloud),
        onTap: () => _select('sources'),
      ),
      ListTile(
        title: const Text('Tri, langues et catégories'),
        leading: const Icon(Icons.sort),
        onTap: _organize,
      ),
      SwitchListTile(
        title: const Text('Épisode suivant automatiquement'),
        value: app.settings.autoNext,
        onChanged: (value) =>
            app.updateSettings(app.settings.copyWith(autoNext: value)),
      ),
      SwitchListTile(
        title: const Text('Reconnexion automatique'),
        value: app.settings.reconnectEnabled,
        onChanged: (value) =>
            app.updateSettings(app.settings.copyWith(reconnectEnabled: value)),
      ),
      const SizedBox(height: 16),
      DropdownButtonFormField<double>(
        initialValue: app.settings.playbackRate,
        decoration: const InputDecoration(labelText: 'Vitesse VOD par défaut'),
        items: [
          for (final rate in playbackRates)
            DropdownMenuItem(value: rate, child: Text('$rate×')),
        ],
        onChanged: (value) {
          if (value != null) {
            app.updateSettings(app.settings.copyWith(playbackRate: value));
          }
        },
      ),
      const SizedBox(height: 22),
      const Text(
        'NOVA IPTV TV · application indépendante\nLes sources sont actualisées au démarrage. Le guide XMLTV se charge depuis Sources.',
        style: TextStyle(color: novaMuted),
      ),
    ],
  );
}
