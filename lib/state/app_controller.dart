import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../data/demo_catalog.dart';
import '../data/local_store.dart';
import '../domain/catalog_preferences.dart';
import '../domain/catalog_defaults.dart';
import '../domain/models.dart';
import '../domain/user_profile.dart';
import '../domain/media_variants.dart';
import '../domain/recent_catalog.dart';
import '../domain/artwork_identity.dart';
import '../domain/platform_catalog.dart';
import '../domain/source_models.dart';
import 'source_controller.dart';
import 'internet_catalog_controller.dart';
import '../sync/drive_resume.dart';

class AppController extends ChangeNotifier {
  // Keep the injected store's public argument independent of the private field.
  AppController({
    required LocalStore store,
    this.sources,
    this.internetCatalog,
    this.driveResume,
    this.refreshSourcesOnStartup = false,
    this.television = false,
    bool? android,
  })
    // ignore: prefer_initializing_formals
    : _store = store,
       _android = android ?? Platform.isAndroid {
    sources?.addListener(_sourceChanged);
    sources?.preferencesForRefresh = () => _catalogPreferences;
    internetCatalog?.addListener(_internetChanged);
  }

  final LocalStore _store;
  final DriveResumeSync? driveResume;
  DateTime? _driveAttempt;
  Timer? _driveTimer;
  int _driveProfileGeneration = 0;
  Timer? _selectionRefreshTimer;
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
          avatar: entry.value['avatar'] as String? ?? '',
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
    _driveProfileGeneration++;
    _restoreProfile(_profiles[id]!);
    _profileChosen = true;
    _preferencesRevision++;
    _recommendationInput = null;
    _changed();
    unawaited(syncDriveResume());
  }

  void updateProfile(String name, Set<String> genres, {String? avatar}) {
    if (name.trim().isEmpty) return;
    _profiles[_activeProfileId] = {
      ...?_profiles[_activeProfileId],
      'name': name.trim().substring(0, min(name.trim().length, 32)),
      'genres': genres.where(preferredGenres.containsKey).toList(),
      'genresConfigured': true,
      'avatar': ?avatar,
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
      final matches = genres.isEmpty
          ? const <MediaItem>[]
          : movies.where((item) {
              final text = genreText(
                variantsFor(item)
                    .map((v) => '${v.category} ${v.description} ${v.subtitle}')
                    .join(' '),
              );
              return genres.any(
                (g) =>
                    preferredGenres[g]?.any((word) => text.contains(word)) ??
                    false,
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
    _catalogPreferences = _profileCatalogPreferences(data);
    _defaultsCatalogRevision = -2;
    _applyInitialCategoryFilters();
    _restoreTvChannelOrder();
    _platformPreferences = PlatformPreferences.fromJson(
      data['platformPreferences'],
    );
    _watchlist
      ..clear()
      ..addAll((data['watchlist'] as List? ?? []).whereType<String>());
    _favorites
      ..clear()
      ..addAll((data['favorites'] as List? ?? []).whereType<String>());
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
    _restoreResumeResets(data);
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
  final Map<String, Set<String>> _sharedEpisodeParents = {};
  final Map<String, List<EpgProgramme>> _guideIndex = {};
  AppSettings _settings = const AppSettings();
  CatalogPreferences _catalogPreferences = const CatalogPreferences();
  PlatformPreferences _platformPreferences = const PlatformPreferences();
  final _resumeResetAt = <String, DateTime>{};
  int _preferencesRevision = 0;
  int _defaultsCatalogRevision = -2;
  int _visibleCatalogRevision = -2;
  int _visiblePreferencesRevision = -1;
  List<MediaItem> _visibleItems = const [];
  final Map<String, MediaItem> _visibleCardsById = {};
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
  List<MediaItem>? _resumeProjection;
  List<MediaItem>? _resumeProjectionInput;
  final Set<String> _favorites = {};
  final Set<String> _watchlist = {};
  bool _prefetchingDetails = false;
  Timer? _detailPrefetchTimer;
  String? _priorityDetail;
  final _detailQueue =
      <String, ({MediaItem item, bool Function()? relevant})>{};
  final _failedPrefetches = <String, DateTime>{};
  Set<String>? _favoriteProjection;
  List<MediaItem>? _favoriteProjectionInput;
  final Map<String, WatchProgress> _progress = {};
  final List<String> _recentIds = [];
  bool _isReady = false;
  int _androidTvSourceOrderVersion = 0;
  bool _disposed = false;
  String? _storageError;
  Timer? _saveTimer;
  Timer? _progressNotificationTimer;
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
      _visibleCardsById
        ..clear()
        ..addEntries(_visibleItems.map((item) => MapEntry(item.id, item)));
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
    if (_progress.isEmpty) return const [];
    final visible = items;
    if (identical(visible, _resumeProjectionInput) &&
        _resumeProjection != null) {
      return _resumeProjection!;
    }
    _ensureIndex();
    final ongoing = <String, ({MediaItem item, DateTime lastWatched})>{};
    // Visit watched IDs, not every film and every episode in the catalogue.
    for (final entry in _progress.entries) {
      if (!_unfinished(entry.value)) continue;
      for (final parentId
          in _sharedEpisodeParents[entry.key] ??
              {_episodeParents[entry.key] ?? entry.key}) {
        final group = _variants?.byId[parentId];
        if (group == null) continue;
        final item = _visibleCardsById[group.first.id];
        if (item == null || item.kind == MediaKind.live) {
          continue;
        }
        final previous = ongoing[item.id];
        if (previous == null ||
            entry.value.lastWatched.isAfter(previous.lastWatched)) {
          ongoing[item.id] = (item: item, lastWatched: entry.value.lastWatched);
        }
      }
    }
    final ordered = ongoing.values.toList()
      ..sort((a, b) => b.lastWatched.compareTo(a.lastWatched));
    _resumeProjectionInput = visible;
    return _resumeProjection = List.unmodifiable(
      ordered.map((entry) => entry.item),
    );
  }

  VoidCallback? dismissResume(String id) {
    final item = itemById(id);
    if (item == null || item.kind == MediaKind.live || !canResume(item)) {
      return null;
    }
    final profile = _activeProfileId;
    final identity = variantIdentity(item);
    final variants = allItems
        .where(
          (entry) =>
              entry.id == id ||
              (entry.kind == item.kind &&
                  entry.sourceId == item.sourceId &&
                  variantIdentity(entry) == identity),
        )
        .toList();
    final ids = {
      for (final variant in variants) ...[
        variant.id,
        for (final season in variant.seasons)
          ...season.episodes.map((episode) => episode.id),
      ],
    };
    final previous = {
      for (final entry in _progress.entries)
        if (ids.contains(entry.key)) entry.key: entry.value,
    };
    final previousRecent = _recentIds.where(ids.contains).toList();
    var now = DateTime.now();
    for (final date in [
      ...previous.values.map((entry) => entry.lastWatched),
      ...variants.map((variant) => _resumeResetAt[variant.id]).nonNulls,
    ]) {
      if (!now.isAfter(date)) now = date.add(const Duration(microseconds: 1));
    }
    for (final variant in variants) {
      _resumeResetAt[variant.id] = now;
    }
    _forgetResetProgress();
    _changed(invalidateFavorites: false);
    unawaited(syncDriveResume(force: true));

    return () {
      if (_disposed || _activeProfileId != profile) return;
      final undoAt = DateTime.now();
      final restoredAt = undoAt.isAfter(now)
          ? undoAt
          : now.add(const Duration(microseconds: 1));
      final restoredIds = <String>{};
      for (final entry in previous.entries) {
        if (_progress.containsKey(entry.key) ||
            _resetFor(entry.key)?.isAtSameMomentAs(now) != true) {
          continue;
        }
        final value = entry.value;
        _progress[entry.key] = WatchProgress(
          positionSeconds: value.positionSeconds,
          durationSeconds: value.durationSeconds,
          lastWatched: restoredAt,
          completed: value.completed,
        );
        restoredIds.add(entry.key);
      }
      if (restoredIds.isEmpty) return;
      _recentIds.insertAll(0, previousRecent.where(restoredIds.contains));
      if (_recentIds.length > 20) _recentIds.removeRange(20, _recentIds.length);
      _changed(invalidateFavorites: false);
      unawaited(syncDriveResume(force: true));
    };
  }

  DateTime? _resetFor(String id) {
    var reset = _resumeResetAt[id];
    final parents = _sharedEpisodeParents[id];
    if (parents == null) return reset ?? _resumeResetAt[_episodeParents[id]];
    for (final parent in parents) {
      final candidate = _resumeResetAt[parent];
      if (candidate != null && (reset == null || candidate.isAfter(reset))) {
        reset = candidate;
      }
    }
    return reset;
  }

  bool _forgetResetProgress() {
    if (_resumeResetAt.isEmpty) return false;
    _ensureIndex();
    final removed = <String>{};
    _progress.removeWhere((id, progress) {
      final reset = _resetFor(id);
      if (reset == null || progress.lastWatched.isAfter(reset)) return false;
      removed.add(id);
      return true;
    });
    _recentIds.removeWhere(removed.contains);
    return removed.isNotEmpty;
  }

  bool _restoreResumeResets(Map<String, dynamic> data) {
    _resumeResetAt.clear();
    final stored = data['resumeResetAt'];
    if (stored is Map) {
      for (final entry in stored.entries) {
        if (entry.key is! String || entry.value is! String) continue;
        final time = DateTime.tryParse(entry.value as String);
        if (time != null) _resumeResetAt[entry.key as String] = time;
      }
    }
    // Older releases only hid these titles from the row. Apply the reset to
    // those titles too, so their old positions cannot still be opened.
    final legacy = data.remove('dismissedResumeIds');
    if (legacy is List && legacy.isNotEmpty) {
      _ensureIndex();
      final now = DateTime.now();
      for (final id in legacy.whereType<String>()) {
        _resumeResetAt[_episodeParents[id] ?? id] = now;
      }
    }
    final removed = _forgetResetProgress();
    return removed || (legacy is List && legacy.isNotEmpty);
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
    for (final id in _favorites) {
      final group = _variants?.byId[id];
      if (group != null) result.add(group.first.id);
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
    _sharedEpisodeParents.clear();
    for (final item in allItems) {
      _itemById[item.id] = item;
      _ids.add(item.id);
      for (final season in item.seasons) {
        _ids.addAll(season.episodes.map((e) => e.id));
        for (final episode in season.episodes) {
          final previous = _episodeParents[episode.id];
          if (previous != null && previous != item.id) {
            (_sharedEpisodeParents[episode.id] ??= {previous}).add(item.id);
          }
          _episodeParents[episode.id] = item.id;
        }
      }
    }
  }

  void _sourceChanged() {
    if (_disposed) return;
    _scheduleDetailPrefetch();
    _ensureIndex();
    final referencesChanged = _migrateEpisodeReferences();
    final resetProgressRemoved = _forgetResetProgress();
    final defaultsChanged = _isReady && _applyInitialCategoryFilters();
    if ((referencesChanged || defaultsChanged || resetProgressRemoved) &&
        _isReady) {
      _changed();
      return;
    }
    notifyListeners();
  }

  bool _migrateEpisodeReferences() {
    var changed = false;
    for (final set in [_favorites, _watchlist]) {
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

  void cancelDetails(MediaItem item) => sources?.cancelDetails(item.id);

  Future<MediaItem> loadDetails(MediaItem item) async {
    item = itemById(item.id) ?? item;
    return item.isDemo || sources == null ? item : await sources!.details(item);
  }

  String descriptionFor(MediaItem item) {
    if (item.description.trim().isNotEmpty) return item.description;
    return sources?.prefetchedDetails(item)?.description ??
        itemById(item.id)?.description ??
        '';
  }

  bool needsDetailLoadingIndicator(MediaItem item) {
    if (item.detailsLoaded ||
        itemById(item.id)?.detailsLoaded == true ||
        sources?.prefetchedDetails(item) != null) {
      return false;
    }
    return item.kind == MediaKind.series
        ? item.seasons.isEmpty || descriptionFor(item).trim().isEmpty
        : descriptionFor(item).trim().isEmpty;
  }

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

  CatalogPreferences _profileCatalogPreferences(Map<String, dynamic> data) {
    if (data.containsKey('catalogPreferences')) {
      return CatalogPreferences.fromJson(data['catalogPreferences']);
    }
    data['useInitialCatalogFilters'] = true;
    data['initialCategoryGroups'] = <String>[];
    return initialCatalogPreferences();
  }

  /// Translate portable names into this installation's source/category keys.
  /// A source/kind is seeded only once, so users can unhide it permanently.
  bool _applyInitialCategoryFilters() {
    final profile = _profiles[_activeProfileId];
    final revision = sources?.catalogRevision ?? -1;
    if (profile?['useInitialCatalogFilters'] != true ||
        _defaultsCatalogRevision == revision) {
      return false;
    }
    _defaultsCatalogRevision = revision;
    final applied = (profile!['initialCategoryGroups'] as List? ?? [])
        .whereType<String>()
        .toSet();
    final groups = <String, List<MediaItem>>{};
    for (final item in allItems) {
      if (item.sourceId == null) continue;
      final group = '${Uri.encodeComponent(item.sourceId!)}|${item.kind.name}';
      if (!applied.contains(group)) (groups[group] ??= []).add(item);
    }
    if (groups.isEmpty) return false;
    final hidden = {
      for (final kind in MediaKind.values)
        kind: Set<String>.of(
          _catalogPreferences.ruleFor(kind).hiddenCategories,
        ),
    };
    for (final entry in groups.entries) {
      for (final item in entry.value) {
        if (initiallyHiddenCategory(item)) {
          hidden[item.kind]!.add(catalogCategoryKey(item));
        }
      }
      applied.add(entry.key);
    }
    for (final kind in MediaKind.values) {
      _catalogPreferences = _catalogPreferences.copyWithRule(
        kind,
        _catalogPreferences
            .ruleFor(kind)
            .copyWith(hiddenCategories: hidden[kind]),
      );
    }
    profile['initialCategoryGroups'] = applied.toList();
    _preferencesRevision++;
    return true;
  }

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
      if (driveResume != null) {
        unawaited(
          driveResume!.init().then((_) {
            if (_disposed) return;
            _driveTimer ??= Timer.periodic(
              const Duration(minutes: 1),
              (_) => unawaited(syncDriveResume()),
            );
          }),
        );
      }
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
      final newDefaults = !data.containsKey('catalogPreferences');
      _catalogPreferences = _profileCatalogPreferences(data);
      final categoryDefaults = _applyInitialCategoryFilters();
      if (newDefaults || categoryDefaults) saveSourceOrder = true;
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
      _watchlist.addAll((data['watchlist'] as List? ?? []).whereType<String>());
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
      if (_restoreResumeResets(data)) saveSourceOrder = true;
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

  bool isWatchlisted(MediaItem item) =>
      variantsFor(item).any((variant) => _watchlist.contains(variant.id));

  List<MediaItem> get watchlistItems => items.where(isWatchlisted).toList();

  void toggleWatchlist(MediaItem item) {
    final group = variantsFor(item).map((variant) => variant.id).toSet();
    if (group.any(_watchlist.contains)) {
      _watchlist.removeAll(group);
    } else {
      _watchlist.addAll(group);
    }
    _changed();
  }

  void prefetchDetails(
    MediaItem item, {
    bool priority = false,
    bool Function()? relevant,
  }) {
    if (_disposed ||
        sources == null ||
        item.isDemo ||
        item.kind == MediaKind.live ||
        item.providerId == null) {
      return;
    }
    _detailQueue[item.id] = (item: item, relevant: relevant);
    if (priority) _priorityDetail = item.id;
    if (_detailQueue.length > 24) {
      _detailQueue.remove(_detailQueue.keys.first);
    }
    _scheduleDetailPrefetch();
  }

  void _scheduleDetailPrefetch() {
    if (_disposed ||
        _prefetchingDetails ||
        _detailPrefetchTimer != null ||
        _detailQueue.isEmpty ||
        sources?.catalogLoading == true ||
        sources?.startupRefreshing == true) {
      return;
    }
    _detailPrefetchTimer = Timer(const Duration(milliseconds: 120), () {
      _detailPrefetchTimer = null;
      unawaited(_prefetchNextDetail());
    });
  }

  Future<void> _prefetchNextDetail() async {
    final manager = sources;
    if (_disposed ||
        manager == null ||
        manager.catalogLoading ||
        manager.startupRefreshing) {
      return;
    }
    while (_detailQueue.isNotEmpty) {
      final request =
          _detailQueue.remove(_priorityDetail) ??
          _detailQueue.remove(_detailQueue.keys.first)!;
      _priorityDetail = null;
      if (request.relevant?.call() == false) continue;
      final variant = preferredVariant(request.item);
      final item = itemById(variant.id);
      if (item == null ||
          item.detailsLoaded ||
          item.description.trim().isNotEmpty ||
          manager.prefetchedDetails(item) != null ||
          (_failedPrefetches[item.id]?.isAfter(DateTime.now()) ?? false)) {
        continue;
      }
      _prefetchingDetails = true;
      try {
        await manager.details(item, background: true);
      } on SourceCancelled {
        // A catalogue refresh or closing the detail can cancel this request.
      } catch (_) {
        if (_failedPrefetches.length >= 48) {
          _failedPrefetches.remove(_failedPrefetches.keys.first);
        }
        _failedPrefetches[item.id] = DateTime.now().add(
          const Duration(minutes: 1),
        );
      } finally {
        _prefetchingDetails = false;
        _scheduleDetailPrefetch();
      }
      return;
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
    final previous = _catalogPreferences;
    _catalogPreferences = CatalogPreferences.fromJson(preferences.toJson());
    _preferencesRevision++;
    _changed();
    final expanded = MediaKind.values.any((kind) {
      final before = previous.ruleFor(kind), after = preferences.ruleFor(kind);
      return before.hiddenLanguages
              .difference(after.hiddenLanguages)
              .isNotEmpty ||
          before.hiddenCategories.difference(after.hiddenCategories).isNotEmpty;
    });
    if (expanded && sources != null) {
      _selectionRefreshTimer?.cancel();
      _selectionRefreshTimer = Timer(
        const Duration(milliseconds: 800),
        () => unawaited(_refreshSelectedSources()),
      );
    }
  }

  Future<void> _refreshSelectedSources() async {
    try {
      await sources?.reloadSources();
    } catch (_) {
      /* Source errors are exposed by the controller. */
    }
  }

  void updatePlatformPreferences(PlatformPreferences preferences) {
    _platformPreferences = PlatformPreferences.fromJson(preferences.toJson());
    _changed();
  }

  void recordProgress(String id, WatchProgress progress) {
    if (_disposed) return;
    if (!_knownIds.contains(id)) return;
    final validated = WatchProgress.fromJson(progress.toJson());
    if (validated == null) return;
    final previous = _progress[id];
    final changedItem = _recentIds.firstOrNull != id;
    final reset = _resetFor(id);
    if (reset != null && !validated.lastWatched.isAfter(reset)) return;
    _progress[id] = validated;
    _recentIds.remove(id);
    _recentIds.insert(0, id);
    if (_recentIds.length > 20) _recentIds.removeRange(20, _recentIds.length);
    // Memory stays current on every tick. TV menus and disk do not need to
    // rebuild/rewrite each second while the same episode keeps playing.
    final immediate =
        !television ||
        previous == null ||
        changedItem ||
        previous.completed != validated.completed ||
        previous.durationSeconds != validated.durationSeconds ||
        (previous.positionSeconds - validated.positionSeconds).abs() > 2 ||
        validated.lastWatched.difference(previous.lastWatched).abs() >=
            const Duration(seconds: 5);
    if (immediate) {
      _changed(invalidateFavorites: false);
    } else {
      _resumeProjection = null;
      _progressNotificationTimer ??= Timer(const Duration(seconds: 5), () {
        _progressNotificationTimer = null;
        if (!_disposed) notifyListeners();
      });
      _saveTimer ??= Timer(const Duration(seconds: 5), () {
        _saveTimer = null;
        unawaited(_enqueueSave());
      });
    }
  }

  /// Progress is keyed by the Xtream content ID, independently of each
  /// installation's source and profile UUIDs.
  Future<void> syncDriveResume({bool force = false}) async {
    final drive = driveResume;
    final manager = sources;
    final profile = _activeProfileId;
    final generation = _driveProfileGeneration;
    if (_disposed ||
        !_isReady ||
        !_profileChosen ||
        drive == null ||
        manager == null ||
        !drive.connected ||
        drive.codeFor(profile) == null ||
        drive.busy) {
      return;
    }
    final now = DateTime.now();
    if (!force &&
        _driveAttempt != null &&
        now.difference(_driveAttempt!) < const Duration(seconds: 15)) {
      return;
    }
    _driveAttempt = now;
    bool stillActive() =>
        !_disposed &&
        _profileChosen &&
        profile == _activeProfileId &&
        generation == _driveProfileGeneration;
    await drive.sync(profile, (code, remote) async {
      if (!stillActive()) return null;
      if (remote.isEmpty && _progress.isEmpty && _resumeResetAt.isEmpty) {
        return {};
      }
      final namespaces = <String, List<String>>{};
      for (final source in manager.sources) {
        final draft = manager.draftFor(source.id);
        if (draft?.kind != SourceKind.xtream) continue;
        final uri = Uri.tryParse(draft!.address);
        if (uri == null || uri.host.isEmpty) continue;
        namespaces[source.id] = [
          uri.host.toLowerCase(),
          if (uri.hasPort && uri.port != 80 && uri.port != 443) '${uri.port}',
          uri.path.replaceFirst(RegExp(r'/+$'), ''),
          draft.username,
        ];
      }
      String? itemKey(MediaItem item) {
        final namespace = namespaces[item.sourceId];
        if (namespace == null ||
            item.providerId == null ||
            item.kind == MediaKind.live) {
          return null;
        }
        return driveMediaKey(code, [
          ...namespace,
          item.kind.name,
          item.providerId!,
        ]);
      }

      final unresolved = <String, DateTime>{};
      for (final entry in remote.values) {
        final key = entry.seriesKey;
        if (key == null || entry.progress.completed) continue;
        final date = entry.progress.lastWatched;
        final cutoff = remote[key];
        if (cutoff?.reset == true &&
            !date.isAfter(cutoff!.progress.lastWatched)) {
          continue;
        }
        if (unresolved[key]?.isAfter(date) != true) unresolved[key] = date;
      }
      if (unresolved.isNotEmpty && !manager.catalogLoading) {
        final missing =
            allItems
                .where(
                  (item) =>
                      item.kind == MediaKind.series &&
                      !item.detailsLoaded &&
                      item.seasons.isEmpty &&
                      unresolved.containsKey(itemKey(item)),
                )
                .toList()
              ..sort(
                (a, b) =>
                    unresolved[itemKey(b)]!.compareTo(unresolved[itemKey(a)]!),
              );
        // Only hydrate a few recent remote series, never the entire catalogue.
        for (final item in missing.take(2)) {
          if (!stillActive()) return null;
          try {
            await manager.details(item);
          } catch (_) {
            // Retain the remote progress for a later attempt.
          }
        }
      }
      if (!stillActive()) return null;
      var changed = false;
      for (final item in allItems) {
        final key = itemKey(item);
        final marker = remote[key];
        if (marker?.reset != true) continue;
        final time = marker!.progress.lastWatched;
        final current = _resumeResetAt[item.id];
        if (current == null || time.isAfter(current)) {
          _resumeResetAt[item.id] = time;
          changed = true;
        }
      }
      changed = _forgetResetProgress() || changed;
      final snapshot = <String, DriveResumeEntry>{};
      void include(String key, String id, {String? seriesKey}) {
        final remoteEntry = remote[key];
        final incoming = remoteEntry?.reset == false
            ? remoteEntry!.progress
            : null;
        final current = _progress[id];
        final cutoff = _resetFor(id);
        if (incoming != null &&
            (cutoff == null || incoming.lastWatched.isAfter(cutoff)) &&
            (current == null ||
                incoming.lastWatched.isAfter(current.lastWatched))) {
          _progress[id] = incoming;
          changed = true;
        }
        final progress = _progress[id];
        if (progress != null &&
            (snapshot[key]?.progress.lastWatched.isAfter(
                  progress.lastWatched,
                ) !=
                true)) {
          snapshot[key] = DriveResumeEntry(progress, seriesKey: seriesKey);
        }
      }

      for (final item in allItems) {
        final key = itemKey(item);
        if (key == null) continue;
        final reset = _resumeResetAt[item.id];
        if (reset != null) snapshot[key] = DriveResumeEntry.reset(reset);
        if (item.kind == MediaKind.movie) {
          include(key, item.id);
        } else {
          final namespace = namespaces[item.sourceId]!;
          final prefix = '${item.sourceId}:episode:';
          for (final season in item.seasons) {
            for (final episode in season.episodes) {
              if (!episode.id.startsWith(prefix)) continue;
              final episodeKey = driveMediaKey(code, [
                ...namespace,
                'episode',
                episode.id.substring(prefix.length),
              ]);
              include(episodeKey, episode.id, seriesKey: key);
            }
          }
        }
      }
      if (changed) _changed(invalidateFavorites: false);
      return snapshot;
    });
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
    final profile = _profiles[_activeProfileId];
    if (profile != null) profile['useInitialCatalogFilters'] = false;
    _settings = const AppSettings();
    _catalogPreferences = const CatalogPreferences();
    _platformPreferences = const PlatformPreferences();
    _resumeResetAt.clear();
    _preferencesRevision++;
    _favorites.clear();
    _watchlist.clear();
    _progress.clear();
    _recentIds.clear();
    _storageError = null;
    _changed();
  }

  void _changed({bool invalidateFavorites = true}) {
    if (_disposed) return;
    if (invalidateFavorites) _favoriteProjection = null;
    _resumeProjection = null;
    _progressNotificationTimer?.cancel();
    _progressNotificationTimer = null;
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
    'resumeResetAt': {
      for (final entry in _resumeResetAt.entries)
        entry.key: entry.value.toUtc().toIso8601String(),
    },
    'favorites': _favorites.toList(),
    'watchlist': _watchlist.toList(),
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
    if (_progressNotificationTimer != null) {
      _progressNotificationTimer!.cancel();
      _progressNotificationTimer = null;
      if (!_disposed) notifyListeners();
    }
    return _enqueueSave();
  }

  Future<void> shutdown() async {
    _selectionRefreshTimer?.cancel();
    _driveTimer?.cancel();
    await internetCatalog?.close();
    await flush();
    await sources?.close();
  }

  @override
  void dispose() {
    _selectionRefreshTimer?.cancel();
    _detailPrefetchTimer?.cancel();
    _detailQueue.clear();
    _disposed = true;
    _driveTimer?.cancel();
    driveResume?.dispose();
    _progressNotificationTimer?.cancel();
    sources?.removeListener(_sourceChanged);
    internetCatalog?.removeListener(_internetChanged);
    if (_saveTimer != null) {
      _saveTimer!.cancel();
      unawaited(_enqueueSave());
    }
    super.dispose();
  }
}
