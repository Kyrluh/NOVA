import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../data/demo_catalog.dart';
import '../data/local_store.dart';
import '../domain/catalog_preferences.dart';
import '../domain/models.dart';
import '../domain/recent_catalog.dart';
import '../domain/artwork_identity.dart';
import '../domain/platform_catalog.dart';
import '../domain/source_models.dart';
import 'source_controller.dart';
import 'internet_catalog_controller.dart';

class AppController extends ChangeNotifier {
  // Keep the injected store's public argument independent of the private field.
  AppController({
    required LocalStore store,
    this.sources,
    this.internetCatalog,
    this.refreshSourcesOnStartup = false,
    bool? android,
  })
    // ignore: prefer_initializing_formals
    : _store = store,
       _android = android ?? Platform.isAndroid {
    sources?.addListener(_sourceChanged);
    internetCatalog?.addListener(_internetChanged);
  }

  final LocalStore _store;
  final bool _android;
  final bool refreshSourcesOnStartup;
  final SourceController? sources;
  final InternetCatalogController? internetCatalog;
  void _internetChanged() {
    if (!_disposed) notifyListeners();
  }

  Set<CatalogPlatform> platformsFor(MediaItem item) =>
      _platformPreferences.hasOverride(item)
      ? _platformPreferences.platformsFor(item)
      : {
          ..._platformPreferences.platformsFor(item),
          ...?internetCatalog?.platformsFor(item),
        };
  int _indexedRevision = -2;
  int _guideRevision = -2;
  final Map<String, MediaItem> _itemById = {};
  final Set<String> _ids = {};
  final Map<String, String> _episodeParents = {};
  final Map<String, List<EpgProgramme>> _guideIndex = {};
  AppSettings _settings = const AppSettings();
  CatalogPreferences _catalogPreferences = const CatalogPreferences();
  PlatformPreferences _platformPreferences = const PlatformPreferences();
  final Set<String> _dismissedResumeIds = {};
  int _preferencesRevision = 0;
  int _visibleCatalogRevision = -2;
  int _visiblePreferencesRevision = -1;
  List<MediaItem> _visibleItems = const [];
  List<MediaItem>? _recentCatalogInput;
  List<MediaItem> _recentCatalogItems = const [];
  final Set<String> _favorites = {};
  final Map<String, WatchProgress> _progress = {};
  final List<String> _recentIds = [];
  bool _isReady = false;
  int _androidTvSourceOrderVersion = 0;
  bool _disposed = false;
  String? _storageError;
  Timer? _saveTimer;
  Future<void>? _initialization;
  Future<void> _writeTail = Future.value();

  /// The full catalogue remains indexed even when content is hidden in lists.
  List<MediaItem> get allItems => isDemo ? demoCatalog : sources!.items;
  List<MediaItem> get items {
    final revision = sources?.catalogRevision ?? -1;
    if (_visibleCatalogRevision != revision ||
        _visiblePreferencesRevision != _preferencesRevision) {
      _visibleItems = applyCatalogPreferences(allItems, _catalogPreferences);
      _visibleCatalogRevision = revision;
      _visiblePreferencesRevision = _preferencesRevision;
    }
    return _visibleItems;
  }

  bool get isDemo => !(sources?.hasConfiguredSources ?? false);
  AppSettings get settings => _settings;
  CatalogPreferences get catalogPreferences => _catalogPreferences;
  PlatformPreferences get platformPreferences => _platformPreferences;

  WatchProgress? latestProgressFor(
    MediaItem item, {
    bool unfinishedOnly = false,
  }) {
    WatchProgress? latest;
    for (final id in [
      item.id,
      for (final season in item.seasons) ...season.episodes.map((e) => e.id),
    ]) {
      final value = _progress[id];
      if (value == null || (unfinishedOnly && !_unfinished(value))) continue;
      if (latest == null || value.lastWatched.isAfter(latest.lastWatched)) {
        latest = value;
      }
    }
    return latest;
  }

  bool canResume(MediaItem item) =>
      item.kind != MediaKind.live &&
      !_dismissedResumeIds.contains(item.id) &&
      latestProgressFor(item, unfinishedOnly: true) != null;

  List<MediaItem> get recentlyAddedItems {
    final visible = items;
    if (!identical(visible, _recentCatalogInput)) {
      _recentCatalogInput = visible;
      _recentCatalogItems = List.unmodifiable(recentlyAdded(visible));
    }
    return _recentCatalogItems;
  }

  List<MediaItem> get resumeItems {
    final ongoing = items.where(canResume).toList();
    ongoing.sort(
      (a, b) => latestProgressFor(b, unfinishedOnly: true)!.lastWatched
          .compareTo(latestProgressFor(a, unfinishedOnly: true)!.lastWatched),
    );
    return ongoing;
  }

  void dismissResume(String id) {
    final item = itemById(id);
    if (item == null || !canResume(item)) return;
    _dismissedResumeIds.add(id);
    _changed();
  }

  void restoreResume(String id) {
    if (_dismissedResumeIds.remove(id)) _changed();
  }

  static bool _unfinished(WatchProgress value) =>
      !value.completed &&
      value.positionSeconds > 0 &&
      (value.durationSeconds == 0 ||
          value.positionSeconds < value.durationSeconds);
  Set<String> get favorites => UnmodifiableSetView(_favorites);
  Map<String, WatchProgress> get progress => UnmodifiableMapView(_progress);
  List<String> get recentIds => List.unmodifiable(_recentIds);
  bool get isReady => _isReady;
  String? get storageError => _storageError;

  Set<String> get _knownIds {
    _ensureIndex();
    return _ids;
  }

  void _ensureIndex() {
    final revision = sources?.catalogRevision ?? -1;
    if (_indexedRevision == revision) return;
    _indexedRevision = revision;
    _itemById.clear();
    _ids.clear();
    _episodeParents.clear();
    for (final item in allItems) {
      _itemById[item.id] = item;
      _ids.add(item.id);
      for (final season in item.seasons) {
        _ids.addAll(season.episodes.map((e) => e.id));
        for (final episode in season.episodes) {
          _episodeParents[episode.id] = item.id;
        }
      }
    }
  }

  void _sourceChanged() {
    if (_disposed) return;
    _ensureIndex();
    if (_migrateEpisodeReferences() && _isReady) {
      _changed();
      return;
    }
    notifyListeners();
  }

  bool _migrateEpisodeReferences() {
    var changed = false;
    for (final set in [_favorites, _dismissedResumeIds]) {
      for (final id in set.toList()) {
        final parent = _episodeParents[id];
        if (parent != null) {
          set.remove(id);
          set.add(parent);
          changed = true;
        }
      }
    }
    return changed;
  }

  MediaItem? itemById(String id) {
    _ensureIndex();
    return _itemById[id];
  }

  /// Source artwork takes priority; public images need a confirmed local title.
  String? posterFor(MediaItem item) {
    return posterIdentity(item.posterUrl) != null
        ? item.posterUrl
        : internetCatalog?.posterFor(item);
  }

  Future<MediaItem> loadDetails(MediaItem item) async =>
      item.isDemo || sources == null ? item : await sources!.details(item);

  List<EpgProgramme> guideFor(MediaItem item) {
    final manager = sources;
    if (manager == null || item.sourceId == null) return const [];
    if (_guideRevision != manager.epgRevision) {
      _guideRevision = manager.epgRevision;
      _guideIndex.clear();
      for (final source in manager.sources) {
        for (final programme in manager.programmesFor(source.id)) {
          for (final alias in {
            programme.channelId,
            ...programme.channelAliases,
          }) {
            final key = '${source.id}|${_channelKey(alias)}';
            (_guideIndex[key] ??= []).add(programme);
          }
        }
      }
      for (final list in _guideIndex.values) {
        list.sort((a, b) => a.start.compareTo(b.start));
      }
    }
    for (final alias in [if (item.tvgId != null) item.tvgId!, item.title]) {
      final result = _guideIndex['${item.sourceId}|${_channelKey(alias)}'];
      if (result != null && result.isNotEmpty) return result;
    }
    return const [];
  }

  String _channelKey(String name) =>
      name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  Future<void> init() => _initialization ??= _load();

  Future<void> _load() async {
    var saveSourceOrder = false;
    try {
      await internetCatalog?.init();
      await sources?.init();
      final data = await _store.load();
      final settings = data['settings'];
      if (settings is Map<String, dynamic>) {
        _settings = AppSettings.fromJson(settings);
      }
      _catalogPreferences = CatalogPreferences.fromJson(
        data['catalogPreferences'],
      );
      _androidTvSourceOrderVersion = data['androidTvSourceOrderVersion'] == 1
          ? 1
          : 0;
      if (_android && _androidTvSourceOrderVersion < 1) {
        _catalogPreferences = _catalogPreferences.copyWithRule(
          MediaKind.live,
          _catalogPreferences
              .ruleFor(MediaKind.live)
              .copyWith(order: CatalogOrder.source),
        );
        _androidTvSourceOrderVersion = 1;
        // Persist once; later explicit sorting choices remain the user's choice.
        saveSourceOrder = true;
      }
      _preferencesRevision++;
      _platformPreferences = PlatformPreferences.fromJson(
        data['platformPreferences'],
      );
      final dismissed = data['dismissedResumeIds'];
      if (dismissed is List) {
        _ensureIndex();
        _dismissedResumeIds.addAll(
          dismissed
              .whereType<String>()
              .map((id) => _episodeParents[id] ?? id)
              .where(_itemById.containsKey),
        );
      }
      final favorites = data['favorites'];
      if (favorites is List) {
        _ensureIndex();
        final itemIds = _itemById.keys.toSet();
        _favorites.addAll(
          favorites
              .whereType<String>()
              .map((id) => _episodeParents[id] ?? id)
              .where(itemIds.contains),
        );
      }
      final progress = data['progress'];
      if (progress is Map) {
        final ids = _knownIds;
        for (final entry in progress.entries) {
          if (entry.key is! String || !ids.contains(entry.key)) continue;
          final parsed = WatchProgress.fromJson(entry.value);
          if (parsed != null) _progress[entry.key as String] = parsed;
        }
      }
      final recent = data['recentIds'];
      if (recent is List) {
        final ids = _knownIds;
        _recentIds.addAll(
          recent.whereType<String>().where(ids.contains).toSet().take(20),
        );
      }
      if (saveSourceOrder) await _enqueueSave();
    } catch (_) {
      _storageError =
          'Les données locales n’ont pas pu être chargées. '
          'Les réglages par défaut restent disponibles.';
    } finally {
      _isReady = true;
      if (!_disposed) notifyListeners();
      if (!_disposed && refreshSourcesOnStartup && sources != null) {
        unawaited(sources!.refreshAtStartup());
      }
    }
  }

  void toggleFavorite(String id) {
    if (itemById(id) == null) return;
    if (!_favorites.remove(id)) _favorites.add(id);
    _changed();
  }

  void updateSettings(AppSettings settings) {
    _settings = AppSettings.fromJson(settings.toJson());
    _changed();
  }

  void updateCatalogPreferences(CatalogPreferences preferences) {
    _catalogPreferences = CatalogPreferences.fromJson(preferences.toJson());
    _preferencesRevision++;
    _changed();
  }

  void updatePlatformPreferences(PlatformPreferences preferences) {
    _platformPreferences = PlatformPreferences.fromJson(preferences.toJson());
    _changed();
  }

  void recordProgress(String id, WatchProgress progress) {
    if (!_knownIds.contains(id)) return;
    final validated = WatchProgress.fromJson(progress.toJson());
    if (validated == null) return;
    _progress[id] = validated;
    _dismissedResumeIds.remove(id);
    for (final item in allItems.where(
      (item) => _dismissedResumeIds.contains(item.id),
    )) {
      if (item.seasons.any(
        (season) => season.episodes.any((episode) => episode.id == id),
      )) {
        _dismissedResumeIds.remove(item.id);
      }
    }
    _recentIds.remove(id);
    _recentIds.insert(0, id);
    if (_recentIds.length > 20) _recentIds.removeRange(20, _recentIds.length);
    _changed();
  }

  void markWatched(String id) {
    if (!_knownIds.contains(id)) return;
    var duration = _progress[id]?.durationSeconds ?? 0;
    for (final item in allItems) {
      if (item.id == id && item.kind == MediaKind.live) return;
      if (item.id == id) duration = item.durationMinutes * 60;
      for (final season in item.seasons) {
        for (final episode in season.episodes) {
          if (episode.id == id) duration = episode.durationMinutes * 60;
        }
      }
    }
    recordProgress(
      id,
      WatchProgress(
        positionSeconds: duration,
        durationSeconds: duration,
        lastWatched: DateTime.now(),
        completed: true,
      ),
    );
  }

  void resetData() {
    _settings = const AppSettings();
    _catalogPreferences = const CatalogPreferences();
    _platformPreferences = const PlatformPreferences();
    _dismissedResumeIds.clear();
    _preferencesRevision++;
    _favorites.clear();
    _progress.clear();
    _recentIds.clear();
    _storageError = null;
    _changed();
  }

  void _changed() {
    if (_disposed) return;
    notifyListeners();
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 180), () {
      _saveTimer = null;
      unawaited(_enqueueSave());
    });
  }

  Map<String, dynamic> _snapshot() => {
    'schemaVersion': 1,
    'settings': _settings.toJson(),
    'catalogPreferences': _catalogPreferences.toJson(),
    'androidTvSourceOrderVersion': _androidTvSourceOrderVersion,
    'platformPreferences': _platformPreferences.toJson(),
    'dismissedResumeIds': _dismissedResumeIds.toList(),
    'favorites': _favorites.toList(),
    'progress': {
      for (final entry in _progress.entries) entry.key: entry.value.toJson(),
    },
    'recentIds': _recentIds.toList(),
  };

  Future<void> _enqueueSave() {
    final snapshot = _snapshot();
    _writeTail = _writeTail.then((_) async {
      try {
        await _store.save(snapshot);
        if (_storageError != null) {
          _storageError = null;
          if (!_disposed) notifyListeners();
        }
      } catch (_) {
        _storageError =
            'La sauvegarde locale a échoué. '
            'Vérifiez les droits d’écriture et l’espace disponible.';
        if (!_disposed) notifyListeners();
      }
    });
    return _writeTail;
  }

  Future<void> flush() {
    _saveTimer?.cancel();
    _saveTimer = null;
    return _enqueueSave();
  }

  Future<void> shutdown() async {
    await internetCatalog?.close();
    await flush();
    await sources?.close();
  }

  @override
  void dispose() {
    _disposed = true;
    sources?.removeListener(_sourceChanged);
    internetCatalog?.removeListener(_internetChanged);
    if (_saveTimer != null) {
      _saveTimer!.cancel();
      unawaited(_enqueueSave());
    }
    super.dispose();
  }
}
