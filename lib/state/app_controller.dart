import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../data/demo_catalog.dart';
import '../data/local_store.dart';
import '../domain/catalog_preferences.dart';
import '../domain/models.dart';
import '../domain/user_profile.dart';
import '../domain/media_variants.dart';
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
    this.television = false,
    bool? android,
  })
    // ignore: prefer_initializing_formals
    : _store = store,
       _android = android ?? Platform.isAndroid {
    sources?.addListener(_sourceChanged);
    internetCatalog?.addListener(_internetChanged);
  }

  final LocalStore _store;
  final Map<String, Map<String, dynamic>> _profiles = {};
  String _activeProfileId = 'main';
  bool _profileChosen = false;
  List<MediaItem>? _recommendationInput;
  List<MediaItem> _recommendations = const [];
  String get activeProfileId => _activeProfileId;
  bool get profileChosen => _profileChosen;
  List<UserProfile> get profiles => _profiles.entries
      .map(
        (entry) => UserProfile(
          id: entry.key,
          name: entry.value['name'] as String? ?? 'Mon profil',
          genres: (entry.value['genres'] as List? ?? [])
              .whereType<String>()
              .toSet(),
          genresConfigured: entry.value['genresConfigured'] == true,
        ),
      )
      .toList(growable: false);
  UserProfile get activeProfile =>
      profiles.firstWhere((p) => p.id == _activeProfileId);

  void showProfilePicker() {
    _profileChosen = false;
    notifyListeners();
  }

  String createProfile(String name) {
    if (name.trim().isEmpty || _profiles.length >= 20) return '';
    final id =
        'profile-${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 30)}';
    _profiles[id] = {
      'name': name.trim().substring(0, min(name.trim().length, 32)),
      'genres': <String>[],
      'genresConfigured': false,
    };
    _changed();
    return id;
  }

  void selectProfile(String id) {
    if (!_profiles.containsKey(id)) return;
    _profiles[_activeProfileId] = {
      ...?_profiles[_activeProfileId],
      ..._profileState(),
    };
    _activeProfileId = id;
    _restoreProfile(_profiles[id]!);
    _profileChosen = true;
    _preferencesRevision++;
    _recommendationInput = null;
    _changed();
  }

  void updateProfile(String name, Set<String> genres) {
    if (name.trim().isEmpty) return;
    _profiles[_activeProfileId] = {
      ...?_profiles[_activeProfileId],
      'name': name.trim().substring(0, min(name.trim().length, 32)),
      'genres': genres.where(preferredGenres.containsKey).toList(),
      'genresConfigured': true,
    };
    _recommendationInput = null;
    _changed();
  }

  List<MediaItem> get recommendations {
    final visible = items;
    if (!identical(visible, _recommendationInput)) {
      _recommendationInput = visible;
      final movies = visible.where((i) => i.kind == MediaKind.movie).toList();
      final genres = activeProfile.genres;
      final matches = movies.where((item) {
        final text = genreText(
          variantsFor(item)
              .map((v) => '${v.category} ${v.description} ${v.subtitle}')
              .join(' '),
        );
        return genres.any(
          (g) =>
              preferredGenres[g]?.any((word) => text.contains(word)) ?? false,
        );
      }).toList();
      final pool = matches.isNotEmpty ? matches : movies;
      pool.shuffle();
      final previous = _profiles[_activeProfileId]?['lastRecommendationId'];
      if (pool.length > 1 && pool.first.id == previous) {
        pool.add(pool.removeAt(0));
      }
      _recommendations = pool.take(20).toList(growable: false);
      if (_recommendations.isNotEmpty) {
        _profiles[_activeProfileId]!['lastRecommendationId'] =
            _recommendations.first.id;
        unawaited(_enqueueSave());
      }
    }
    return _recommendations;
  }

  void shuffleRecommendations() {
    _recommendationInput = null;
    notifyListeners();
  }

  void _restoreProfile(Map<String, dynamic> data) {
    _settings = AppSettings.fromJson(
      Map<String, dynamic>.from(data['settings'] as Map? ?? {}),
    );
    _catalogPreferences = CatalogPreferences.fromJson(
      data['catalogPreferences'],
    );
    _restoreTvChannelOrder();
    _platformPreferences = PlatformPreferences.fromJson(
      data['platformPreferences'],
    );
    _favorites
      ..clear()
      ..addAll((data['favorites'] as List? ?? []).whereType<String>());
    _dismissedResumeIds
      ..clear()
      ..addAll((data['dismissedResumeIds'] as List? ?? []).whereType<String>());
    _recentIds
      ..clear()
      ..addAll((data['recentIds'] as List? ?? []).whereType<String>().take(20));
    _progress.clear();
    for (final entry in (data['progress'] as Map? ?? {}).entries) {
      final progress = WatchProgress.fromJson(entry.value);
      if (entry.key is String && progress != null) {
        _progress[entry.key as String] = progress;
      }
    }
  }

  final bool _android;
  final bool refreshSourcesOnStartup;
  final bool television;
  final SourceController? sources;
  final InternetCatalogController? internetCatalog;
  void _internetChanged() {
    if (!_disposed) notifyListeners();
  }

  Set<CatalogPlatform> platformsFor(MediaItem item) => {
    for (final variant in variantsFor(item)) ...{
      ..._platformPreferences.platformsFor(variant),
      if (!_platformPreferences.hasOverride(variant))
        ...?internetCatalog?.platformsFor(variant),
    },
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
  VariantCatalog? _variants;
  List<MediaItem> variantsFor(MediaItem item) {
    items;
    return _variants?.byId[item.id] ?? [item];
  }

  MediaItem preferredVariant(MediaItem item) {
    final variants = variantsFor(item);
    MediaItem selected = variants.first;
    DateTime? latest;
    for (final variant in variants) {
      WatchProgress? progress;
      for (final id in [
        variant.id,
        for (final season in variant.seasons)
          ...season.episodes.map((e) => e.id),
      ]) {
        final value = _progress[id];
        if (value != null &&
            (progress == null ||
                value.lastWatched.isAfter(progress.lastWatched))) {
          progress = value;
        }
      }
      if (progress != null &&
          (latest == null || progress.lastWatched.isAfter(latest))) {
        selected = variant;
        latest = progress.lastWatched;
      }
    }
    return selected;
  }

  List<MediaItem>? _recentCatalogInput;
  List<MediaItem> _recentCatalogItems = const [];
  final Set<String> _favorites = {};
  Set<String>? _favoriteProjection;
  List<MediaItem>? _favoriteProjectionInput;
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
      _variants = VariantCatalog(
        applyCatalogPreferences(allItems, _catalogPreferences),
      );
      _visibleItems = List.unmodifiable(_variants!.cards);
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
      for (final variant in variantsFor(item)) ...[
        variant.id,
        for (final season in variant.seasons)
          ...season.episodes.map((e) => e.id),
      ],
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
    _dismissedResumeIds.addAll(variantsFor(item).map((i) => i.id));
    _changed();
  }

  void restoreResume(String id) {
    final item = itemById(id);
    if (item == null) return;
    _dismissedResumeIds.removeAll(variantsFor(item).map((v) => v.id));
    _changed();
  }

  static bool _unfinished(WatchProgress value) =>
      !value.completed &&
      value.positionSeconds > 0 &&
      (value.durationSeconds == 0 ||
          value.positionSeconds < value.durationSeconds);
  Set<String> get favorites {
    final visible = items;
    if (identical(visible, _favoriteProjectionInput) &&
        _favoriteProjection != null) {
      return _favoriteProjection!;
    }
    final result = Set<String>.of(_favorites);
    for (final item in visible) {
      if (variantsFor(item).any((v) => _favorites.contains(v.id))) {
        result.add(item.id);
      }
    }
    _favoriteProjectionInput = visible;
    return _favoriteProjection = UnmodifiableSetView(result);
  }

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

  MediaItem? seriesForEpisode(String id) {
    _ensureIndex();
    return _itemById[_episodeParents[id]];
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

  /// Dedicated TV builds had no channel-order control. Reset legacy choices
  /// once per profile, preserving filters and future explicit sorting choices.
  bool _restoreTvChannelOrder() {
    final profile = _profiles[_activeProfileId];
    if (!television ||
        profile == null ||
        profile['tvChannelOrderVersion'] == 1) {
      return false;
    }
    _catalogPreferences = _catalogPreferences.copyWithRule(
      MediaKind.live,
      _catalogPreferences
          .ruleFor(MediaKind.live)
          .copyWith(order: CatalogOrder.source),
    );
    profile['tvChannelOrderVersion'] = 1;
    return true;
  }

  Future<void> _load() async {
    var saveSourceOrder = false;
    try {
      await internetCatalog?.init();
      await sources?.init();
      final root = await _store.load();
      for (final raw in (root['profiles'] as List? ?? []).take(20)) {
        if (raw is! Map || raw['id'] is! String || raw['name'] is! String) {
          continue;
        }
        _profiles[raw['id'] as String] = Map<String, dynamic>.from(raw)
          ..remove('id');
      }
      if (_profiles.isEmpty) {
        _profiles['main'] = {
          ...root,
          'name': 'Mon profil',
          'genres': <String>[],
          'genresConfigured': false,
        }..remove('profiles');
      }
      _activeProfileId = _profiles.containsKey(root['activeProfileId'])
          ? root['activeProfileId'] as String
          : _profiles.keys.first;
      final data = _profiles[_activeProfileId]!;
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
      if (_restoreTvChannelOrder()) saveSourceOrder = true;
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
      _profiles.putIfAbsent(
        _activeProfileId,
        () => {'name': 'Mon profil', 'genres': <String>[]},
      );
      _isReady = true;
      if (!_disposed) notifyListeners();
      if (!_disposed && refreshSourcesOnStartup && sources != null) {
        unawaited(sources!.refreshAtStartup());
      }
    }
  }

  void toggleFavorite(String id) {
    final item = itemById(id);
    if (item == null) return;
    final group = variantsFor(item).map((v) => v.id).toSet();
    if (group.any(_favorites.contains)) {
      _favorites.removeAll(group);
    } else {
      _favorites.addAll(group);
    }
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
    final parent = itemById(_episodeParents[id] ?? id);
    if (parent != null) {
      _dismissedResumeIds.removeAll(variantsFor(parent).map((v) => v.id));
    }
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
    _favoriteProjection = null;
    notifyListeners();
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 180), () {
      _saveTimer = null;
      unawaited(_enqueueSave());
    });
  }

  Map<String, dynamic> _profileState() => {
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

  Map<String, dynamic> _snapshot() {
    _profiles[_activeProfileId] = {
      ...?_profiles[_activeProfileId],
      ..._profileState(),
    };
    return {
      ..._profileState(),
      'activeProfileId': _activeProfileId,
      'profiles': [
        for (final entry in _profiles.entries)
          {...entry.value, 'id': entry.key},
      ],
    };
  }

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
