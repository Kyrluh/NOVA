import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../data/source_repository.dart';
import '../domain/internet_catalog.dart';
import '../domain/models.dart';
import '../domain/catalog_preferences.dart';
import '../domain/recent_catalog.dart';
import '../domain/source_models.dart';
import '../sources/iptv_client.dart';
import '../sources/m3u_series.dart';

List<MediaItem> _groupCachedM3u(List<MediaItem> items) => groupM3uSeries(items);

/// Coordinates provider requests and protected, transactional catalogue saves.
/// Cache initialization is separate from the app's once-per-launch refresh.
class SourceController extends ChangeNotifier {
  SourceController({
    required SourceRepository repository,
    required IptvClient client,
    // Keep the public dependency names independent of the private fields.
    // ignore: prefer_initializing_formals
  }) : _repository = repository,
       // ignore: prefer_initializing_formals
       _client = client {
    _client.catalogProgress.addListener(_catalogProgressChanged);
  }

  final SourceRepository _repository;
  final IptvClient _client;
  CatalogPreferences Function()? preferencesForRefresh;

  /// Manual reload remains available after the once-per-launch refresh.
  Future<void> reloadSources() async {
    await Future.wait(
      _pending.toList().map((operation) async {
        try {
          await operation;
        } catch (_) {
          /* Retry below. */
        }
      }),
    );
    Object? failure;
    for (final id in _records.keys.toList()) {
      if (_closed) return;
      if (!_tokens.containsKey(id)) {
        try {
          await refresh(id);
        } catch (error) {
          failure = error;
        }
      }
    }
    if (failure != null) throw failure;
  }

  final Map<String, SourceRecord> _records = {};
  final Map<String, CancellationToken> _tokens = {};
  final Map<String, CancellationToken> _detailTokens = {};
  final Map<String, Future<MediaItem>> _details = {};
  final Set<CancellationToken> _testTokens = {};
  final Map<String, String> _sourceErrors = {};
  final Map<String, DateTime> _epgAttempts = {};
  final Map<String, DateTime> _epgSuccesses = {};
  final Map<String, String> _epgErrors = {};
  final Set<String> _epgLoads = {};
  final Set<Future<dynamic>> _pending = {};
  List<MediaItem> _items = const [];
  List<EpgProgramme> _programmes = const [];
  Future<void> _commitTail = Future<void>.value();
  Future<void>? _initialization;
  Future<void>? _closing;
  bool _isInitializing = true;
  bool _closed = false;
  bool _disposed = false;
  Future<void>? _startupRefresh;
  bool _startupRefreshing = false;
  bool _startupFinished = false;
  int _startupCompleted = 0;
  int _startupTotal = 0;
  int _startupFailures = 0;
  String? _startupCurrentId;
  String? _startupSourceName;
  String _startupPhase = 'Connexion à la source';
  double? _startupFraction = 0;
  final Map<String, String> _catalogLoads = {};
  CatalogLoadProgress? _loadProgress;
  bool get catalogLoading => _catalogLoads.isNotEmpty;
  double? get catalogLoadProgress => _loadProgress?.fraction;
  String? get catalogLoadName =>
      _catalogLoads[_loadProgress?.sourceId] ??
      _catalogLoads.values.firstOrNull;
  String get catalogLoadPhase =>
      _loadProgress?.phase ?? 'Connexion à la source';

  bool get startupRefreshing => _startupRefreshing;
  bool get startupFinished => _startupFinished;
  int get startupCompleted => _startupCompleted;
  int get startupTotal => _startupTotal;
  int get startupFailures => _startupFailures;
  String? get startupSourceName => _startupSourceName;
  String get startupPhase => _startupPhase;
  double? get startupProgress => _startupTotal == 0
      ? 0
      : _startupFraction == null
      ? null
      : ((_startupCompleted + _startupFraction!) / _startupTotal).clamp(0, 1);

  /// Invoked once by the production app after preferences and cache are ready.
  /// Sequential requests avoid opening several provider connections at once.
  Future<void> refreshAtStartup() => _startupRefresh ??= _refreshAtStartup();

  Future<void> _refreshAtStartup() async {
    await init();
    if (_closed) return;
    if (_records.isEmpty) {
      _startupFinished = true;
      _notify();
      return;
    }
    final ids = _records.keys.toList();
    _startupTotal = ids.length;
    _startupRefreshing = true;
    _notify();
    try {
      for (final id in ids) {
        if (_closed) break;
        final record = _records[id];
        if (record != null && !_tokens.containsKey(id)) {
          _startupCurrentId = id;
          _startupSourceName = record.config.name;
          _startupPhase = 'Connexion à la source';
          _startupFraction = 0;
          _notify();
          try {
            await refresh(id);
            if (_records[id]?.catalog.warnings.isNotEmpty == true) {
              _startupFailures++;
            }
          } on SourceCancelled {
            if (_closed) break;
            _startupFailures++;
          } catch (_) {
            _startupFailures++;
          }
        }
        _startupCompleted++;
        _startupFraction = 0;
        _notify();
      }
    } finally {
      _startupCurrentId = null;
      _startupSourceName = null;
      _startupRefreshing = false;
      _startupFinished = !_closed;
      _startupFraction = 0;
      _notify();
    }
  }

  void _catalogProgressChanged() {
    final progress = _client.catalogProgress.value;
    if (progress != null && _catalogLoads.containsKey(progress.sourceId)) {
      final previous = _loadProgress;
      if (previous?.sourceId == progress.sourceId &&
          previous?.phase == progress.phase &&
          (previous?.fraction == progress.fraction ||
              (previous?.fraction != null &&
                  progress.fraction != null &&
                  (previous!.fraction! - progress.fraction!).abs() < .01))) {
        return;
      }
      _loadProgress = progress;
      if (!_startupRefreshing) _notify();
    }
    if (progress == null ||
        !_startupRefreshing ||
        progress.sourceId != _startupCurrentId) {
      return;
    }
    final previous = _startupFraction;
    if (_startupPhase == progress.phase &&
        previous == null &&
        progress.fraction == null) {
      return;
    }
    if (_startupPhase == progress.phase &&
        previous != null &&
        progress.fraction != null &&
        (previous - progress.fraction!).abs() < .01) {
      return;
    }
    _startupFraction = progress.fraction;
    _startupPhase = progress.phase;
    _notify();
  }

  String? _error;
  int _catalogRevision = 0;
  int _epgRevision = 0;

  List<SourceSummary> get sources => List.unmodifiable(
    _records.values.map(
      (record) => SourceSummary(
        id: record.config.id,
        name: record.config.name,
        kind: record.config.kind,
        itemCount: record.catalog.items.length,
        updatedAt: record.updatedAt,
        error: _sourceErrors[record.config.id],
      ),
    ),
  );
  List<MediaItem> get items => _items;
  List<EpgProgramme> get programmes => _programmes;
  List<EpgProgramme> programmesFor(String sourceId) => List.unmodifiable(
    _records[sourceId]?.programmes ?? const <EpgProgramme>[],
  );
  Set<String> get busyIds => Set.unmodifiable(_tokens.keys);
  bool epgLoading(String id) => _epgLoads.contains(id);
  String? epgError(String id) => _epgErrors[id];
  bool get isInitializing => _isInitializing;
  bool get hasConfiguredSources => _records.isNotEmpty;
  String? get error => _error;
  int get catalogRevision => _catalogRevision;
  int get epgRevision => _epgRevision;
  List<String> get warnings => List.unmodifiable({
    ..._repository.warnings,
    for (final record in _records.values) ...record.catalog.warnings,
  });

  Future<void> init() => _initialization ??= _load();

  Future<void> _load() async {
    try {
      final records = await _repository.readAll();
      if (_closed) return;
      for (final record in records) {
        var restored = record;
        if (record.config.kind != SourceKind.xtream &&
            hasUngroupedM3uSeries(record.catalog.items)) {
          final grouped = await compute(_groupCachedM3u, record.catalog.items);
          if (_closed) return;
          restored = SourceRecord(
            config: record.config,
            catalog: SourceCatalog(
              items: grouped,
              suggestedEpgUrl: record.catalog.suggestedEpgUrl,
              warnings: record.catalog.warnings,
              failedKinds: record.catalog.failedKinds,
            ),
            programmes: record.programmes,
            updatedAt: record.updatedAt,
          );
          try {
            await _repository.write(restored);
          } catch (_) {
            // The grouped catalogue remains usable even if migration cannot save.
          }
        }
        _records[record.config.id] = SourceRecord(
          config: restored.config,
          catalog: _datedCatalog(
            restored.catalog,
            observedAt: restored.updatedAt,
          ),
          programmes: restored.programmes,
          updatedAt: restored.updatedAt,
        );
      }
      _rebuild(catalog: true, epg: true);
    } catch (exception) {
      _error = _friendly(exception).message;
    } finally {
      _isInitializing = false;
      _notify();
    }
  }

  SourceDraft? draftFor(String id) => _records[id]?.config.draft;

  Future<String> test(SourceDraft draft, {CancellationToken? cancel}) async {
    _checkOpen();
    _validateDraft(draft);
    final token = cancel ?? CancellationToken();
    token.throwIfCancelled();
    _testTokens.add(token);
    try {
      final result = await _client.testConnection(draft, cancel: token);
      token.throwIfCancelled();
      if (_closed) throw const SourceCancelled();
      return result;
    } catch (exception) {
      if (token.isCancelled || _closed) throw const SourceCancelled();
      throw _friendly(exception);
    } finally {
      _testTokens.remove(token);
    }
  }

  Future<void> add(SourceDraft draft, {CancellationToken? cancel}) {
    _checkOpen();
    _validateDraft(draft);
    final normalized = SourceConfig.fromDraft(_newId(), draft);
    _checkDuplicate(normalized);
    return _track(_catalogJob(normalized, external: cancel));
  }

  Future<void> update(
    String id,
    SourceDraft draft, {
    CancellationToken? cancel,
  }) {
    _checkOpen();
    _validateDraft(draft);
    if (!_records.containsKey(id)) {
      throw const SourceException('Cette source n’existe plus.');
    }
    final normalized = SourceConfig.fromDraft(id, draft);
    _checkDuplicate(normalized);
    return _track(_catalogJob(normalized, external: cancel));
  }

  Future<void> refresh(String id) {
    _checkOpen();
    final record = _records[id];
    if (record == null) {
      throw const SourceException('Cette source n’existe plus.');
    }
    return _track(_catalogJob(record.config));
  }

  Future<void> _catalogJob(
    SourceConfig config, {
    CancellationToken? external,
  }) async {
    final id = config.id;
    final token = _begin(id, external);
    final original = _records[id];
    _catalogLoads[id] = config.name;
    _loadProgress = null;
    _notify();
    try {
      final selection =
          original != null &&
              original.catalog.items.isNotEmpty &&
              _sameProvider(original.config, config) &&
              config.kind == SourceKind.xtream
          ? preferencesForRefresh?.call()
          : null;
      var imported = selection == null
          ? await _client.loadCatalog(config, cancel: token)
          : await _client.loadSelectedCatalog(config, selection, cancel: token);
      if (selection != null) {
        final importedIds = imported.items.map((item) => item.id).toSet();
        final visibleIds = applyCatalogPreferences(
          original!.catalog.items,
          selection,
        ).map((item) => item.id).toSet();
        final merged = [
          ...imported.items,
          ...original.catalog.items.where(
            (item) =>
                !visibleIds.contains(item.id) && !importedIds.contains(item.id),
          ),
        ];
        // Category requests must not scramble the provider's known TV order.
        final positions = {
          for (var i = 0; i < original.catalog.items.length; i++)
            original.catalog.items[i].id: i,
        };
        final live = merged
            .where((item) => item.kind == MediaKind.live)
            .toList();
        final incomingPositions = {
          for (var i = 0; i < live.length; i++) live[i].id: i,
        };
        live.sort(
          (a, b) =>
              (positions[a.id] ?? positions.length + incomingPositions[a.id]!)
                  .compareTo(
                    positions[b.id] ??
                        positions.length + incomingPositions[b.id]!,
                  ),
        );
        final orderedLive = live.iterator;
        imported = SourceCatalog(
          items: [
            for (final item in merged)
              if (item.kind == MediaKind.live && orderedLive.moveNext())
                orderedLive.current
              else
                item,
          ],
          suggestedEpgUrl: imported.suggestedEpgUrl,
          warnings: imported.warnings,
          failedKinds: imported.failedKinds,
        );
      }
      _ensureActive(id, token);
      final catalog = _datedCatalog(
        _retainKnownDetails(imported, original, config),
        previous: original != null && _sameProvider(original.config, config)
            ? original.catalog.items
            : const [],
        observedAt: DateTime.now().toUtc(),
      );
      final suggested = catalog.suggestedEpgUrl?.trim();
      final effective =
          config.epgUrl.isEmpty && suggested != null && suggested.isNotEmpty
          ? config.copyWith(epgUrl: suggested)
          : config;
      final unchangedGuide =
          original != null &&
          _sameProvider(original.config, effective) &&
          original.config.epgUrl == effective.epgUrl;
      if (!unchangedGuide) {
        _epgAttempts.remove(id);
        _epgSuccesses.remove(id);
        _epgErrors.remove(id);
      }
      final next = SourceRecord(
        config: effective,
        catalog: catalog,
        programmes: unchangedGuide ? original.programmes : const [],
        updatedAt: DateTime.now().toUtc(),
      );
      _loadProgress = CatalogLoadProgress(
        id,
        .95,
        'Enregistrement du catalogue',
      );
      if (_startupCurrentId == id) {
        _startupFraction = .95;
        _startupPhase = 'Enregistrement du catalogue';
      }
      _notify();
      await _commit(() async {
        _ensureActive(id, token);
        await _repository.write(next);
        if (!_active(id, token)) {
          // Cancellation can arrive while DPAPI or SQLite is working. Restore
          // the previous committed record before allowing a later mutation.
          if (original == null) {
            await _repository.delete(id);
          } else {
            await _repository.write(original);
          }
          throw const SourceCancelled();
        }
        _records[id] = next;
        _sourceErrors.remove(id);
        _rebuild(catalog: true, epg: true);
      });
    } catch (exception) {
      _operationFailed(id, token, exception);
    } finally {
      _catalogLoads.remove(id);
      if (_loadProgress?.sourceId == id) _loadProgress = null;
      _finish(id, token);
    }
  }

  Future<void> refreshEpg(String id) {
    _checkOpen();
    final record = _records[id];
    if (record == null) {
      throw const SourceException('Cette source n’existe plus.');
    }
    return _track(_epgJob(record));
  }

  /// One background request per source, shared by every channel and HUD.
  /// An unavailable guide never changes the catalogue or playback errors.
  Future<void> ensureEpg(String id) {
    final record = _records[id];
    if (_closed ||
        _disposed ||
        record == null ||
        _tokens.containsKey(id) ||
        (record.config.kind != SourceKind.xtream &&
            record.config.epgUrl.trim().isEmpty)) {
      return Future<void>.value();
    }
    final now = DateTime.now();
    final attempt = _epgAttempts[id];
    if (attempt != null &&
        now.difference(attempt) < const Duration(minutes: 5)) {
      return Future<void>.value();
    }
    final success = _epgSuccesses[id];
    if (success != null &&
        now.difference(success) < const Duration(hours: 3) &&
        record.programmes.any((programme) => programme.end.isAfter(now))) {
      return Future<void>.value();
    }
    _epgAttempts[id] = now;
    return _track(_epgJob(record, background: true));
  }

  Future<void> _epgJob(SourceRecord original, {bool background = false}) async {
    final id = original.config.id;
    final token = _begin(id);
    _epgLoads.add(id);
    _epgErrors.remove(id);
    _notify();
    try {
      final programmes = await _client.loadEpg(original.config, cancel: token);
      _ensureActive(id, token);
      await _commit(() async {
        _ensureActive(id, token);
        final latest = _records[id];
        if (latest == null) throw const SourceCancelled();
        final next = SourceRecord(
          config: latest.config,
          catalog: latest.catalog,
          programmes: programmes,
          updatedAt: latest.updatedAt,
        );
        // Automatic guide loading keeps a session cache without rewriting the
        // entire encrypted IPTV catalogue while the decoder is running.
        if (!background) await _repository.write(next);
        if (!_active(id, token)) {
          if (!background) await _repository.write(latest);
          throw const SourceCancelled();
        }
        _records[id] = next;
        _epgSuccesses[id] = DateTime.now();
        _epgAttempts[id] = DateTime.now();
        _sourceErrors.remove(id);
        _rebuild(catalog: false, epg: true);
      });
    } catch (exception) {
      if (_active(id, token) && exception is! SourceCancelled) {
        _epgErrors[id] = _friendly(exception).message;
      }
      if (!background) _operationFailed(id, token, exception);
    } finally {
      _epgLoads.remove(id);
      _finish(id, token);
    }
  }

  Future<void> remove(String id) {
    _checkOpen();
    cancel(id);
    return _track(
      _commit(() async {
        try {
          await _repository.delete(id);
          _records.remove(id);
          _epgAttempts.remove(id);
          _epgSuccesses.remove(id);
          _epgErrors.remove(id);
          _sourceErrors.remove(id);
          _error = null;
          _rebuild(catalog: true, epg: true);
          _notify();
        } catch (exception) {
          final safe = _friendly(exception);
          _error = safe.message;
          _sourceErrors[id] = safe.message;
          _notify();
          throw safe;
        }
      }),
    );
  }

  /// Deduplicate requests for the same film/series and merge details into the
  /// latest catalogue instead of overwriting a concurrent catalogue refresh.
  Future<MediaItem> details(MediaItem item) {
    if (item.isDemo || item.detailsLoaded) return Future.value(item);
    final existing = _details[item.id];
    if (existing != null) return existing;
    final record = _records[item.sourceId];
    if (record == null) {
      return Future.error(const SourceException('Cette source n’existe plus.'));
    }
    final token = CancellationToken();
    _detailTokens[item.id] = token;
    final result = _detailJob(record.config, item, token);
    _details[item.id] = result;
    result.then<void>(
      (_) => _finishDetails(item.id, token),
      onError: (Object _, StackTrace _) => _finishDetails(item.id, token),
    );
    return _track(result);
  }

  Future<MediaItem> _detailJob(
    SourceConfig config,
    MediaItem item,
    CancellationToken token,
  ) async {
    try {
      final detail = await _client.loadDetails(config, item, cancel: token);
      token.throwIfCancelled();
      await _commit(() async {
        final latest = _records[config.id];
        if (_closed ||
            token.isCancelled ||
            latest == null ||
            !_sameProvider(config, latest.config)) {
          throw const SourceCancelled();
        }
        final index = latest.catalog.items.indexWhere(
          (entry) => entry.id == item.id,
        );
        if (index < 0) throw const SourceCancelled();
        final merged = List<MediaItem>.of(latest.catalog.items)
          ..[index] = detail;
        final next = SourceRecord(
          config: latest.config,
          catalog: SourceCatalog(
            items: merged,
            suggestedEpgUrl: latest.catalog.suggestedEpgUrl,
            warnings: latest.catalog.warnings,
            failedKinds: latest.catalog.failedKinds,
          ),
          programmes: latest.programmes,
          updatedAt: latest.updatedAt,
        );
        await _repository.writeDetails(next, detail);
        if (_closed || token.isCancelled || !_records.containsKey(config.id)) {
          await _repository.writeDetails(latest, latest.catalog.items[index]);
          throw const SourceCancelled();
        }
        _records[config.id] = next;
        _rebuild(catalog: true, epg: false);
        _notify();
      });
      return detail;
    } catch (exception) {
      if (_closed || token.isCancelled || exception is SourceCancelled) {
        throw const SourceCancelled();
      }
      final safe = _friendly(exception);
      _error = safe.message;
      _sourceErrors[config.id] = safe.message;
      _notify();
      throw safe;
    }
  }

  void _finishDetails(String id, CancellationToken token) {
    if (identical(_detailTokens[id], token)) {
      _detailTokens.remove(id);
      _details.remove(id);
    }
  }

  void cancelDetails(String id) {
    _detailTokens.remove(id)?.cancel();
    _details.remove(id);
  }

  void cancel(String id) {
    _tokens.remove(id)?.cancel();
    for (final entry in _detailTokens.entries.toList()) {
      if (_records[id]?.catalog.items.any((item) => item.id == entry.key) ??
          false) {
        entry.value.cancel();
        _detailTokens.remove(entry.key);
        _details.remove(entry.key);
      }
    }
    _notify();
  }

  CancellationToken _begin(String id, [CancellationToken? external]) {
    _checkOpen();
    if (_tokens.containsKey(id)) {
      throw const SourceException(
        'Une opération est déjà en cours pour cette source.',
      );
    }
    final token = external ?? CancellationToken();
    token.throwIfCancelled();
    _tokens[id] = token;
    _sourceErrors.remove(id);
    _error = null;
    _notify();
    return token;
  }

  bool _active(String id, CancellationToken token) =>
      !_closed && !token.isCancelled && identical(_tokens[id], token);
  void _ensureActive(String id, CancellationToken token) {
    if (!_active(id, token)) throw const SourceCancelled();
  }

  Never _operationFailed(String id, CancellationToken token, Object exception) {
    if (!_active(id, token) || exception is SourceCancelled) {
      throw const SourceCancelled();
    }
    final safe = _friendly(exception);
    _error = safe.message;
    _sourceErrors[id] = safe.message;
    throw safe;
  }

  void _finish(String id, CancellationToken token) {
    if (identical(_tokens[id], token)) _tokens.remove(id);
    _notify();
  }

  Future<T> _commit<T>(Future<T> Function() action) {
    final result = _commitTail.then((_) => action());
    _commitTail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }

  Future<T> _track<T>(Future<T> task) {
    _pending.add(task);
    task.then<void>(
      (_) {
        _pending.remove(task);
      },
      onError: (Object _, StackTrace _) {
        _pending.remove(task);
      },
    );
    return task;
  }

  void _rebuild({required bool catalog, required bool epg}) {
    if (catalog) {
      _items = List.unmodifiable(
        _records.values.expand((record) => record.catalog.items),
      );
      _catalogRevision++;
    }
    if (epg) {
      _programmes = List.unmodifiable(
        _records.values.expand((record) => record.programmes),
      );
      _epgRevision++;
    }
  }

  void _validateDraft(SourceDraft draft) {
    if (draft.name.trim().isEmpty || draft.name.trim().length > 100) {
      throw const SourceException(
        'Donnez un nom de 1 à 100 caractères à cette source.',
      );
    }
  }

  void _checkDuplicate(SourceConfig config) {
    if (_records.values.any(
      (record) =>
          record.config.id != config.id && _sameProvider(record.config, config),
    )) {
      throw const SourceException(
        'Cette source est déjà enregistrée. Modifiez-la ou actualisez-la depuis la liste.',
      );
    }
  }

  bool _sameProvider(SourceConfig a, SourceConfig b) =>
      a.kind == b.kind &&
      a.address == b.address &&
      a.username == b.username &&
      a.password == b.password;

  SourceCatalog _datedCatalog(
    SourceCatalog catalog, {
    List<MediaItem> previous = const [],
    required DateTime observedAt,
  }) => SourceCatalog(
    items: rememberCatalogAdditions(
      catalog.items,
      previous: previous,
      observedAt: observedAt,
    ),
    suggestedEpgUrl: catalog.suggestedEpgUrl,
    warnings: catalog.warnings,
    failedKinds: catalog.failedKinds,
  );

  SourceCatalog _retainKnownDetails(
    SourceCatalog incoming,
    SourceRecord? original,
    SourceConfig config,
  ) {
    if (original == null || !_sameProvider(original.config, config)) {
      return incoming;
    }
    final cached = {for (final item in original.catalog.items) item.id: item};
    final importedIds = incoming.items.map((item) => item.id).toSet();
    final retained = original.catalog.items.where(
      (item) =>
          incoming.failedKinds.contains(item.kind) &&
          !importedIds.contains(item.id),
    );
    return SourceCatalog(
      suggestedEpgUrl: incoming.suggestedEpgUrl,
      warnings: incoming.warnings,
      failedKinds: incoming.failedKinds,
      items: [
        ...incoming.items.map((item) {
          final previous = cached[item.id];
          if (previous == null ||
              item.detailsLoaded ||
              previous.kind != item.kind ||
              internetTitleKey(previous.title) !=
                  internetTitleKey(item.title) ||
              (mediaIdentityYear(item) > 0 &&
                  mediaIdentityYear(previous) > 0 &&
                  mediaIdentityYear(item) != mediaIdentityYear(previous))) {
            return item;
          }
          // Keep stable episode IDs and their cached metadata across a catalogue
          // refresh. Details remain stale so opening the series fetches its new
          // episodes instead of treating the previous list as permanently final.
          return item.copyWith(
            seasons: item.seasons.isEmpty ? previous.seasons : item.seasons,
            description: item.description.isEmpty
                ? previous.description
                : item.description,
            durationMinutes: item.durationMinutes == 0
                ? previous.durationMinutes
                : item.durationMinutes,
            year: item.year == 0 ? previous.year : item.year,
            posterUrl: item.posterUrl ?? previous.posterUrl,
          );
        }),
        ...retained,
      ],
    );
  }

  SourceException _friendly(Object exception) {
    if (exception is SourceException) return exception;
    if (exception is SourceRepositoryException) {
      return SourceException(exception.message);
    }
    return const SourceException(
      'L’opération a échoué. Vérifiez la source, votre connexion et le stockage local.',
    );
  }

  void _checkOpen() {
    if (_closed) {
      throw const SourceException('La gestion des sources est fermée.');
    }
  }

  void _notify() {
    if (!_disposed && !_closed) notifyListeners();
  }

  String _newId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return 'src-${bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join()}';
  }

  Future<void> close() => _closing ??= _close();
  Future<void> _close() async {
    _closed = true;
    _client.catalogProgress.removeListener(_catalogProgressChanged);
    for (final token in [
      ..._tokens.values,
      ..._detailTokens.values,
      ..._testTokens,
    ]) {
      token.cancel();
    }
    _tokens.clear();
    final pending = _pending.toList();
    await Future.wait(
      pending.map(
        (job) => job.then<void>((_) {}, onError: (Object _, StackTrace _) {}),
      ),
    ).timeout(const Duration(seconds: 10), onTimeout: () => <void>[]);
    await _commitTail;
    await _repository.close();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    unawaited(close().catchError((Object _) {}));
    super.dispose();
  }
}
