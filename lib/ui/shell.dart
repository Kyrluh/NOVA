import 'dart:async';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

import '../domain/models.dart';
import '../player/desktop_fullscreen.dart';
import '../state/app_controller.dart';
import 'pages/catalog_organization_page.dart';
import 'pages/catalog_page.dart';
import 'pages/details_dialog.dart';
import 'pages/home_page.dart';
import 'pages/home_hub.dart';
import 'pages/live_page.dart';
import 'pages/platforms_page.dart';
import 'pages/settings_page.dart';
import 'pages/sources_page.dart';
import 'theme.dart';
import 'widgets/artwork.dart';
import 'widgets/page_widgets.dart';
import 'widgets/source_startup_progress.dart';
import 'adaptive.dart';
import 'pages/playback_page.dart';

enum NovaSection {
  home,
  live,
  movies,
  series,
  platforms,
  trends,
  favorites,
  resume,
  search,
  organize,
  settings,
  history,
}

const _labels = [
  'Accueil',
  'TV en direct',
  'Films',
  'Séries',
  'Par plateforme',
  'Tendances',
  'Favoris',
  'Continuer à regarder',
  'Recherche',
  'Tri et affichage',
  'Paramètres',
  'Historique',
];
const _icons = [
  Icons.home_rounded,
  Icons.live_tv_rounded,
  Icons.movie_outlined,
  Icons.video_library_outlined,
  Icons.dashboard_customize_outlined,
  Icons.trending_up,
  Icons.favorite_border_rounded,
  Icons.history_rounded,
  Icons.search_rounded,
  Icons.sort_rounded,
  Icons.tune_rounded,
  Icons.manage_history_rounded,
];

class NovaShell extends StatefulWidget {
  const NovaShell({
    super.key,
    required this.controller,
    required this.nativeReady,
    required this.manageWindow,
    this.handleWindowClose = true,
    this.fullscreenController,
    this.mobileUI,
    this.livePlayerBuilder,
    this.playbackBuilder,
  });
  final AppController controller;
  final bool nativeReady;
  final bool manageWindow;
  final bool handleWindowClose;
  final DesktopFullscreen? fullscreenController;
  final bool? mobileUI;
  @visibleForTesting
  final Widget Function(MediaItem, VoidCallback onReleased)? livePlayerBuilder;
  @visibleForTesting
  final Widget Function(EpisodePlaybackSpec)? playbackBuilder;
  @override
  State<NovaShell> createState() => _NovaShellState();
}

class _NovaShellState extends State<NovaShell> with WindowListener {
  NovaSection _section = NovaSection.home;
  bool _collapsed = false;
  bool _closing = false;
  String _query = '';
  final _search = TextEditingController();
  final _searchFocus = FocusNode(debugLabel: 'NOVA global search');
  final _navigationTrail = <({NovaSection section, bool more})>[];
  final _livePageKey = GlobalKey<LivePageState>(
    debugLabel: 'persistent-live-page',
  );
  bool _openingPlayback = false;
  bool _mobileMore = false;
  bool get _android => widget.mobileUI ?? Platform.isAndroid;
  AppController get app => widget.controller;
  DesktopFullscreen get _desktop =>
      widget.fullscreenController ?? DesktopFullscreen.instance;
  bool get _windowShortcuts =>
      widget.manageWindow || widget.fullscreenController != null;

  @override
  void initState() {
    super.initState();
    if (_android) _collapsed = true;
    if (!_android || _windowShortcuts) {
      HardwareKeyboard.instance.addHandler(_handleWindowKey);
    }
    if (widget.manageWindow && widget.handleWindowClose) {
      windowManager.addListener(this);
      unawaited(windowManager.setPreventClose(true));
    }
  }

  @override
  void onWindowClose() async {
    if (_closing) return;
    _closing = true;
    await app.shutdown();
    // Send a normal WM_CLOSE so the native window releases the Flutter engine
    // before the Windows message loop exits (destroy() only posts WM_QUIT).
    await windowManager.setPreventClose(false);
    await windowManager.close();
  }

  @override
  void dispose() {
    if (!_android || _windowShortcuts) {
      HardwareKeyboard.instance.removeHandler(_handleWindowKey);
    }
    if (widget.manageWindow && widget.handleWindowClose) {
      windowManager.removeListener(this);
    }
    _search.dispose();
    _searchFocus.dispose();
    unawaited(app.flush());
    super.dispose();
  }

  void _navigate(NovaSection section) {
    if (_section == section && !_mobileMore) return;
    setState(() {
      if (_mobileMore ||
          const {
            NovaSection.search,
            NovaSection.settings,
            NovaSection.organize,
          }.contains(section)) {
        _navigationTrail.add((section: _section, more: _mobileMore));
      } else {
        _navigationTrail.clear();
      }
      _section = section;
      _mobileMore = false;
    });
  }

  void _backToLibrary() {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      if (_mobileMore) {
        _mobileMore = false;
      } else if (_navigationTrail.isNotEmpty) {
        final previous = _navigationTrail.removeLast();
        _section = previous.section;
        _mobileMore = previous.more;
      } else {
        _section = NovaSection.home;
      }
    });
  }

  void _focusGlobalSearch() {
    _navigate(NovaSection.search);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _searchFocus.requestFocus();
      _search.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _search.text.length,
      );
    });
  }

  bool _handleWindowKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    if (!_android &&
        !_desktop.hasExpandedPlayer &&
        HardwareKeyboard.instance.isControlPressed &&
        (event.logicalKey == LogicalKeyboardKey.keyF ||
            event.logicalKey == LogicalKeyboardKey.keyK) &&
        (ModalRoute.of(context)?.isCurrent ?? true)) {
      _focusGlobalSearch();
      return true;
    }
    if (!_windowShortcuts) return false;
    if (event.logicalKey == LogicalKeyboardKey.f11) {
      unawaited(_toggleWindow());
      return true;
    }
    if (event.logicalKey == LogicalKeyboardKey.escape &&
        _desktop.isFullscreen &&
        !_desktop.hasExpandedPlayer) {
      unawaited(_desktop.setFullscreen(false));
      return true;
    }
    return false;
  }

  Future<void> _toggleWindow() async {
    try {
      if (_desktop.hasExpandedPlayer) {
        final focusedContext = FocusManager.instance.primaryFocus?.context;
        if (focusedContext != null &&
            ModalRoute.of(focusedContext) is PopupRoute) {
          Navigator.of(focusedContext).pop();
          await Future<void>.delayed(Duration.zero);
        }
      }
      await _desktop.toggle();
    } catch (_) {
      if (mounted) _message('Le plein écran est indisponible pour le moment.');
    }
  }

  void _message(String text) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
  );

  void _openSources() {
    final sources = app.sources;
    if (sources == null) {
      _message(
        'La gestion des sources est indisponible dans cet environnement.',
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('Sources IPTV')),
          body: SourcesPage(controller: sources),
        ),
      ),
    );
  }

  Future<void> _openFile() async {
    if (!_canPlay()) return;
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(
          label: 'Vidéos',
          extensions: ['mp4', 'mkv', 'avi', 'mov', 'webm', 'ts', 'm4v', 'm3u8'],
        ),
      ],
    );
    if (file != null && mounted) _play(file.path, file.name);
  }

  bool _canPlay() {
    if (widget.nativeReady) return true;
    _message(
      _android
          ? 'Le moteur vidéo est indisponible. Réinstallez ou mettez à jour l’APK NOVA IPTV.'
          : 'Le moteur vidéo est indisponible. Réinstallez le dossier complet de NOVA IPTV.',
    );
    return false;
  }

  Future<void> _openUrl() async {
    if (!_canPlay()) return;
    final url = TextEditingController();
    var direct = false;
    String? error;
    final result = await showDialog<(String, bool)>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('Ouvrir un flux vidéo'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Saisissez l’adresse HTTP ou HTTPS d’une vidéo ou d’un flux que vous êtes autorisé à lire.',
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: url,
                    autofocus: true,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: InputDecoration(
                      labelText: 'URL du média',
                      hintText: 'https://…',
                      errorText: error,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Flux en direct'),
                    subtitle: const Text(
                      'Lecture à 1×, sans déplacement dans le temps.',
                    ),
                    value: direct,
                    onChanged: (value) => update(() => direct = value),
                  ),
                  const Text(
                    'Cette adresse n’est pas enregistrée.',
                    style: TextStyle(color: novaMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () {
                final uri = Uri.tryParse(url.text.trim());
                if (uri == null ||
                    !['http', 'https'].contains(uri.scheme) ||
                    uri.host.isEmpty) {
                  update(
                    () => error = 'Saisissez une adresse HTTP ou HTTPS valide.',
                  );
                  return;
                }
                Navigator.pop(context, (uri.toString(), direct));
              },
              child: const Text('Lire le flux'),
            ),
          ],
        ),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 250));
    url.dispose();
    if (result != null && mounted) {
      _play(
        result.$1,
        result.$2 ? 'Flux en direct' : 'Vidéo personnelle',
        live: result.$2,
      );
    }
  }

  Future<void> _play(
    String uri,
    String title, {
    bool live = false,
    String? id,
    String? seriesId,
  }) async {
    if (!_canPlay()) return;
    if (_openingPlayback) {
      _message('La lecture précédente se ferme encore.');
      return;
    }
    _openingPlayback = true;
    final livePage = _livePageKey.currentState;
    var routeBuilt = false;
    final released = Completer<void>();
    try {
      if (livePage != null) {
        await livePage.suspendPlayback().timeout(const Duration(seconds: 12));
      }
      if (!mounted) return;
      if (live && id != null) {
        app.recordProgress(
          id,
          WatchProgress(
            positionSeconds: 0,
            durationSeconds: 0,
            lastWatched: DateTime.now(),
          ),
        );
      }
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) {
            routeBuilt = true;
            return NovaPlaybackPage(
              controller: app,
              uri: uri,
              title: title,
              live: live,
              mediaId: id,
              seriesId: seriesId,
              fullscreenController: _desktop,
              playerBuilder: widget.playbackBuilder,
              onReleased: () {
                if (!released.isCompleted) released.complete();
              },
            );
          },
        ),
      );
      if (routeBuilt) {
        await released.future.timeout(const Duration(seconds: 12));
      }
    } on TimeoutException {
      if (mounted) {
        _message(
          'La fermeture de la lecture précédente prend plus de temps. Réessayez dans un instant.',
        );
      }
    } finally {
      // Serialize both directions, including a late native release after a
      // timeout. Do not reopen TV or accept another route in that interval.
      unawaited(() async {
        if (routeBuilt) await released.future;
        if (livePage != null) await livePage.resumePlayback();
        _openingPlayback = false;
      }());
    }
    await app.flush();
  }

  void _details(MediaItem item) {
    if (item.kind == MediaKind.live && item.mediaUrl?.isNotEmpty == true) {
      _play(item.mediaUrl!, item.title, live: true, id: item.id);
      return;
    }
    showMediaDetails(
      context,
      mobileUI: _android,
      controller: app,
      item: item,
      onPlay: (uri, title, id) => _play(
        uri,
        title,
        id: id,
        live: item.kind == MediaKind.live,
        seriesId: item.kind == MediaKind.series
            ? (app.seriesForEpisode(id)?.id ?? item.id)
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => NovaAdaptiveScope(
    android: _android,
    child: LayoutBuilder(
      builder: (context, bounds) {
        final compact = _android && bounds.maxWidth < 600;
        // Playback owns Back while the live player is mounted. Library pages
        // use Android Back to retrace navigation instead of leaving the app.
        final handlesBack =
            _android &&
            (_mobileMore ||
                (_section != NovaSection.home && _section != NovaSection.live));
        return PopScope(
          canPop: !handlesBack,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop &&
                handlesBack &&
                (ModalRoute.of(context)?.isCurrent ?? true)) {
              _backToLibrary();
            }
          },
          child: Scaffold(
            bottomNavigationBar: compact
                ? NavigationBar(
                    key: const ValueKey('mobile-navigation'),
                    height: 68,
                    selectedIndex: !_mobileMore && _section.index < 4
                        ? _section.index
                        : 4,
                    onDestinationSelected: (index) {
                      if (index < 4) {
                        _navigate(NovaSection.values[index]);
                      } else {
                        setState(() => _mobileMore = true);
                      }
                    },
                    destinations: const [
                      NavigationDestination(
                        icon: Icon(Icons.home_outlined),
                        selectedIcon: Icon(Icons.home_rounded),
                        label: 'Accueil',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.live_tv_outlined),
                        label: 'TV',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.movie_outlined),
                        label: 'Films',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.video_library_outlined),
                        label: 'Séries',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.menu_rounded),
                        label: 'Plus',
                      ),
                    ],
                  )
                : null,
            body: SafeArea(
              top: _android,
              bottom: _android && !compact,
              child: Row(
                children: [
                  if (!compact) _sidebar(),
                  Expanded(
                    key: const ValueKey('shell-content'),
                    child: Column(
                      children: [
                        _android ? _mobileTopbar(compact) : _topbar(),
                        if (app.sources != null)
                          SourceStartupProgress(controller: app.sources!),
                        if (app.storageError != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 28),
                            child: NovaNotice(
                              icon: Icons.info_outline,
                              text: app.storageError!,
                            ),
                          ),
                        if (app.sources?.error != null)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(28, 0, 28, 8),
                            child: NovaNotice(
                              icon: Icons.cloud_off_outlined,
                              text: app.sources!.error!,
                            ),
                          ),
                        Expanded(
                          key: const ValueKey('section-body'),
                          child: _mobileMore ? _morePage() : _sectionPage(),
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
  );

  Widget _sectionPage() => switch (_section) {
    NovaSection.home => HomeHub(
      controller: app,
      onDetails: _details,
      onNavigate: (section) => _navigate(NovaSection.values.byName(section)),
      showProfileActions: false,
    ),
    NovaSection.trends => HomePage(
      controller: app,
      onDetails: _details,
      onOpenFile: _openFile,
      onNavigate: _navigate,
      onManageSources: _openSources,
      trends: true,
    ),
    NovaSection.live => LivePage(
      key: _livePageKey,
      fullscreenController: _desktop,
      controller: app,
      onOpenUrl: _openUrl,
      nativeReady: widget.nativeReady,
      onManageSources: _openSources,
      playerBuilder: widget.livePlayerBuilder,
    ),
    NovaSection.movies => MediaCatalogPage(
      key: const ValueKey('movies'),
      controller: app,
      kind: MediaKind.movie,
      onDetails: _details,
    ),
    NovaSection.series => MediaCatalogPage(
      key: const ValueKey('series'),
      controller: app,
      kind: MediaKind.series,
      onDetails: _details,
    ),
    NovaSection.favorites => CollectionPage(
      controller: app,
      resume: false,
      onDetails: _details,
    ),
    NovaSection.platforms => PlatformsPage(
      controller: app,
      onDetails: _details,
    ),
    NovaSection.resume => CollectionPage(
      controller: app,
      resume: true,
      onDetails: _details,
    ),
    NovaSection.search => SearchPage(
      controller: app,
      query: _query,
      onDetails: _details,
    ),
    NovaSection.organize => CatalogOrganizationPage(controller: app),
    NovaSection.settings => SettingsPage(
      controller: app,
      onManageSources: _openSources,
      onOrganize: () => _navigate(NovaSection.organize),
    ),
    NovaSection.history => HistoryPage(controller: app, onDetails: _details),
  };

  Widget _morePage() => ListView(
    key: const PageStorageKey('mobile-more'),
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
    children: [
      _moreHeading('Bibliothèque'),
      for (final section in [
        NovaSection.resume,
        NovaSection.favorites,
        NovaSection.history,
      ])
        _moreDestination(section),
      _moreHeading('Découvrir'),
      for (final section in [
        NovaSection.platforms,
        NovaSection.trends,
        NovaSection.search,
      ])
        _moreDestination(section),
      _moreHeading('Personnaliser'),
      _moreDestination(NovaSection.organize),
      _moreDestination(NovaSection.settings),
      ListTile(
        leading: const Icon(Icons.switch_account_outlined),
        title: const Text('Changer de profil'),
        subtitle: Text(app.activeProfile.name),
        onTap: app.showProfilePicker,
      ),
      _moreHeading('Sources et fichiers'),
      ListTile(
        leading: const Icon(Icons.playlist_add),
        title: const Text('Mes sources IPTV'),
        onTap: _openSources,
      ),
      ListTile(
        leading: const Icon(Icons.video_file_outlined),
        title: const Text('Ouvrir une vidéo'),
        onTap: _openFile,
      ),
      ListTile(
        leading: const Icon(Icons.link_rounded),
        title: const Text('Ouvrir une URL vidéo'),
        onTap: _openUrl,
      ),
    ],
  );

  Widget _moreHeading(String title) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
    child: Text(
      title,
      style: const TextStyle(color: novaMuted, fontWeight: FontWeight.w700),
    ),
  );

  Widget _moreDestination(NovaSection section) => ListTile(
    leading: Icon(_icons[section.index]),
    title: Text(_labels[section.index]),
    trailing: const Icon(Icons.chevron_right_rounded),
    onTap: () => section == NovaSection.search
        ? _focusGlobalSearch()
        : _navigate(section),
  );

  Widget _mobileTopbar(bool compact) {
    final searching = _section == NovaSection.search && !_mobileMore;
    return SizedBox(
      height: 56,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          children: [
            if (searching || _mobileMore || _navigationTrail.isNotEmpty)
              IconButton(
                tooltip: 'Retour',
                onPressed: _backToLibrary,
                icon: const Icon(Icons.arrow_back_rounded),
              )
            else if (!compact)
              IconButton(
                tooltip: _collapsed ? 'Développer le menu' : 'Réduire le menu',
                onPressed: () => setState(() => _collapsed = !_collapsed),
                icon: const Icon(Icons.menu_rounded),
              )
            else
              const Padding(
                padding: EdgeInsets.only(left: 4, right: 10),
                child: NovaMark(size: 27),
              ),
            Expanded(
              child: searching
                  ? TextField(
                      key: const ValueKey('mobile-global-search'),
                      controller: _search,
                      focusNode: _searchFocus,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _searchFocus.unfocus(),
                      onChanged: (value) => setState(() => _query = value),
                      decoration: InputDecoration(
                        hintText: 'Rechercher un titre…',
                        isDense: true,
                        border: InputBorder.none,
                        suffixIcon: _search.text.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Effacer la recherche',
                                onPressed: _clearSearch,
                                icon: const Icon(Icons.close_rounded),
                              ),
                      ),
                    )
                  : Text(
                      _mobileMore ? 'Votre espace' : _labels[_section.index],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
            if (!searching) ...[
              IconButton(
                tooltip: 'Recherche globale',
                onPressed: _focusGlobalSearch,
                icon: const Icon(Icons.search_rounded),
              ),
              IconButton(
                tooltip: 'Changer de profil',
                onPressed: app.showProfilePicker,
                icon: const Icon(Icons.switch_account_outlined),
              ),
              IconButton(
                tooltip: 'Paramètres',
                onPressed: () => _navigate(NovaSection.settings),
                icon: const Icon(Icons.settings_outlined),
              ),
            ],
            PopupMenuButton<String>(
              tooltip: 'Ouvrir un média',
              icon: const Icon(Icons.add_circle_outline_rounded),
              onSelected: (action) {
                if (action == 'sources') {
                  _openSources();
                } else if (action == 'file') {
                  _openFile();
                } else {
                  _openUrl();
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'sources',
                  child: Text('Ajouter une source IPTV'),
                ),
                PopupMenuItem(
                  value: 'file',
                  child: Text('Ouvrir un fichier vidéo'),
                ),
                PopupMenuItem(
                  value: 'url',
                  child: Text('Ouvrir une URL vidéo'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _clearSearch() {
    _search.clear();
    setState(() => _query = '');
    _searchFocus.requestFocus();
  }

  Widget _sidebar() {
    final expanded =
        !_collapsed && (_android || MediaQuery.sizeOf(context).width >= 1120);
    final compact = MediaQuery.sizeOf(context).height < 740;
    return AnimatedContainer(
      duration: app.settings.animations
          ? const Duration(milliseconds: 180)
          : Duration.zero,
      width: expanded ? 226 : (_android ? 64 : 80),
      decoration: const BoxDecoration(
        color: Color(0xFF0E1017),
        border: Border(right: BorderSide(color: Color(0xFF20232D))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 92,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: expanded ? 23 : (_android ? 12 : 20),
              ),
              child: Row(
                children: [
                  const NovaMark(size: 38),
                  if (expanded) ...[
                    const SizedBox(width: 12),
                    const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'NOVA',
                          style: TextStyle(
                            fontSize: 24,
                            letterSpacing: 4,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'I P T V',
                          style: TextStyle(
                            fontSize: 9,
                            color: novaMuted,
                            letterSpacing: 3,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                if (expanded)
                  const Padding(
                    padding: EdgeInsets.fromLTRB(25, 12, 0, 14),
                    child: Text(
                      'VOTRE UNIVERS',
                      style: TextStyle(
                        color: novaMuted,
                        fontSize: 10,
                        letterSpacing: 1.8,
                      ),
                    ),
                  ),
                for (var i = 0; i < _labels.length; i++) ...[
                  if (i == NovaSection.favorites.index ||
                      i == NovaSection.organize.index)
                    const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      child: Divider(height: 1),
                    ),
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: _android ? 6 : 12,
                      vertical: compact ? 2 : 3,
                    ),
                    child: Tooltip(
                      message: expanded ? '' : _labels[i],
                      child: Material(
                        color: _section.index == i
                            ? Color(app.settings.accent).withValues(alpha: .14)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => _navigate(NovaSection.values[i]),
                          child: Container(
                            height: _android
                                ? 48
                                : compact
                                ? 36
                                : 44,
                            padding: EdgeInsets.symmetric(
                              horizontal: expanded ? 13 : 0,
                            ),
                            child: Row(
                              mainAxisAlignment: expanded
                                  ? MainAxisAlignment.start
                                  : MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _icons[i],
                                  size: 21,
                                  color: _section.index == i
                                      ? Color(app.settings.accent)
                                      : novaMuted,
                                ),
                                if (expanded) ...[
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      _labels[i],
                                      maxLines: 1,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: _section.index == i
                                            ? FontWeight.w600
                                            : FontWeight.w400,
                                        color: _section.index == i
                                            ? Colors.white
                                            : novaMuted,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (expanded && MediaQuery.sizeOf(context).height >= 800)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: novaSurface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.circle, size: 6, color: Color(0xFF9A8AFF)),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'ESPACE PERSONNEL',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 9, letterSpacing: 1),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 7),
                    Text(
                      'Vos contenus. Votre rythme.',
                      style: TextStyle(fontSize: 11, color: novaMuted),
                    ),
                  ],
                ),
              ),
            ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              _android ? 6 : 12,
              0,
              _android ? 6 : 12,
              15,
            ),
            child: Row(
              mainAxisAlignment: expanded
                  ? MainAxisAlignment.spaceBetween
                  : MainAxisAlignment.center,
              children: [
                if (expanded)
                  const Text(
                    'NOVA IPTV',
                    style: TextStyle(fontSize: 10, color: novaMuted),
                  ),
                IconButton(
                  tooltip: _collapsed
                      ? 'Développer le menu'
                      : 'Réduire le menu',
                  onPressed: () => setState(() => _collapsed = !_collapsed),
                  icon: Icon(
                    _collapsed
                        ? Icons.keyboard_double_arrow_right
                        : Icons.keyboard_double_arrow_left,
                    size: 18,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _topbar() => Container(
    height: 80,
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: Row(
      children: [
        if (_navigationTrail.isNotEmpty)
          IconButton(
            tooltip: 'Retour',
            onPressed: _backToLibrary,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
        Expanded(
          child: Text(
            _labels[_section.index],
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
        SizedBox(
          width: MediaQuery.sizeOf(context).width < 1150 ? 200 : 290,
          child: TextField(
            key: const ValueKey('desktop-global-search'),
            controller: _search,
            focusNode: _searchFocus,
            onTap: () => _navigate(NovaSection.search),
            onChanged: (value) => setState(() {
              _query = value;
              _section = NovaSection.search;
            }),
            decoration: InputDecoration(
              hintText: 'Rechercher…',
              prefixIcon: const Tooltip(
                message: 'Rechercher (Ctrl+F / Ctrl+K)',
                child: Icon(Icons.search_rounded, size: 19),
              ),
              suffixIcon: _search.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Effacer la recherche',
                      onPressed: _clearSearch,
                      icon: const Icon(Icons.close_rounded, size: 18),
                    ),
              isDense: true,
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
        ),
        const SizedBox(width: 16),
        PopupMenuButton<String>(
          tooltip: 'Ouvrir un média',
          onSelected: (action) {
            if (action == 'sources') {
              _openSources();
            } else if (action == 'file') {
              _openFile();
            } else {
              _openUrl();
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(
              value: 'sources',
              child: Text('Ajouter une source IPTV'),
            ),
            PopupMenuItem(
              value: 'file',
              child: Text('Ouvrir un fichier vidéo'),
            ),
            PopupMenuItem(value: 'url', child: Text('Ouvrir une URL vidéo')),
          ],
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFF303544)),
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Row(
              children: [
                Icon(Icons.add_rounded, size: 18),
                SizedBox(width: 7),
                Text('Ouvrir', style: TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          tooltip: 'Mes sources IPTV',
          onPressed: _openSources,
          icon: const Icon(Icons.playlist_add_rounded),
        ),
        IconButton(
          tooltip: 'Changer de profil',
          onPressed: app.showProfilePicker,
          icon: const Icon(Icons.switch_account_outlined),
        ),
        IconButton(
          tooltip: 'Paramètres',
          onPressed: () => _navigate(NovaSection.settings),
          icon: const Icon(Icons.settings_outlined),
        ),
      ],
    ),
  );
}
