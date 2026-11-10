import 'dart:async';

import 'package:flutter/foundation.dart';

/// Confirms stalled playback without treating native decoder logs as a failure.
/// No native message or media address is retained by this policy.
class PlaybackHealth extends ChangeNotifier {
  PlaybackHealth({
    this.diagnosticGrace = const Duration(seconds: 8),
    this.startupTimeout = const Duration(seconds: 25),
  }) : assert(!diagnosticGrace.isNegative),
       assert(!startupTimeout.isNegative);

  final Duration diagnosticGrace;
  final Duration startupTimeout;

  Timer? _startupTimer;
  Timer? _diagnosticTimer;
  int _generation = 0;
  int _timerEpoch = 0;
  bool _begun = false;
  bool _disposed = false;
  bool _paused = false;
  bool _failed = false;
  bool _hasProgress = false;
  bool _awaitingProgress = false;
  bool _pendingDiagnostic = false;
  Duration _lastPosition = Duration.zero;

  bool get failed => _failed;
  bool get hasProgress => _hasProgress;

  /// Starts a fresh observation for a newly selected medium or explicit retry.
  void begin() {
    if (_disposed) return;
    final changed = _failed || _hasProgress;
    ++_generation;
    _cancelTimers();
    _begun = true;
    _paused = false;
    _failed = false;
    _hasProgress = false;
    _pendingDiagnostic = false;
    _lastPosition = Duration.zero;
    _armStartup();
    if (changed) notifyListeners();
  }

  /// Native log messages may describe recoverable probing/decoding problems.
  /// Repeated diagnostics must not postpone confirmation of a genuine stall.
  void diagnostic() {
    if (_disposed || !_begun || _paused || _failed) return;
    _pendingDiagnostic = true;
    // Initial probing and an intentional resume get the full startup window.
    if (_awaitingProgress || !_hasProgress || _diagnosticTimer != null) return;
    final generation = _generation;
    final epoch = _timerEpoch;
    _diagnosticTimer = Timer(diagnosticGrace, () {
      if (!_active(generation, epoch) || !_pendingDiagnostic) return;
      _diagnosticTimer = null;
      fail();
    });
  }

  /// A growing, positive playback clock is evidence; `playing` alone is not.
  /// Always move the baseline, including after seeks or a live timestamp reset.
  void advance(Duration position, {required bool playing}) {
    if (_disposed || !_begun) return;
    final advancing = position > Duration.zero && position > _lastPosition;
    _lastPosition = position;
    if (_paused || !playing || !advancing) return;
    final changed = !_hasProgress || _failed;
    _hasProgress = true;
    _failed = false;
    _awaitingProgress = false;
    _pendingDiagnostic = false;
    _cancelTimers();
    if (changed) notifyListeners();
  }

  /// Called for a user pause/resume, never simply because a native flag changed.
  void setPaused(bool value) {
    if (_disposed || !_begun || _paused == value) return;
    _paused = value;
    _cancelTimers();
    _pendingDiagnostic = false;
    if (!value && !_failed) _armStartup();
  }

  /// Explicit open/play failures can fail immediately; later clock activity
  /// still recovers the UI without requiring another source selection.
  void fail() {
    if (_disposed || !_begun) return;
    _cancelTimers();
    _awaitingProgress = false;
    _pendingDiagnostic = false;
    if (_failed) return;
    _failed = true;
    notifyListeners();
  }

  void _armStartup() {
    if (_disposed || !_begun || _paused || _failed) return;
    _awaitingProgress = true;
    final generation = _generation;
    final epoch = _timerEpoch;
    _startupTimer = Timer(startupTimeout, () {
      if (!_active(generation, epoch) || !_awaitingProgress) return;
      _startupTimer = null;
      fail();
    });
  }

  bool _active(int generation, int epoch) =>
      !_disposed &&
      _begun &&
      !_paused &&
      generation == _generation &&
      epoch == _timerEpoch;

  void _cancelTimers() {
    ++_timerEpoch;
    _startupTimer?.cancel();
    _diagnosticTimer?.cancel();
    _startupTimer = null;
    _diagnosticTimer = null;
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _cancelTimers();
    super.dispose();
  }
}
