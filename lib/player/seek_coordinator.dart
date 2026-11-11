import 'dart:async';

/// Coalesces remote repeats and slider changes. Only one native seek runs at a
/// time; repeated input accumulates against the target, not stale native time.
class SeekCoordinator {
  SeekCoordinator({required this.seek, required this.changed});
  final Future<void> Function(Duration) seek;
  final void Function() changed;
  Duration? target;
  Timer? _timer;
  Timer? _settleTimer;
  bool _busy = false;
  bool _dirty = false;
  bool _disposed = false;
  int _revision = 0;

  void request(Duration value) {
    target = value;
    _settleTimer?.cancel();
    _dirty = true;
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 180), flush);
    changed();
  }

  void position(Duration position) {
    if (!_busy &&
        !_dirty &&
        target != null &&
        (position - target!).abs() < const Duration(seconds: 1)) {
      target = null;
      changed();
    }
  }

  Future<void> flush() async {
    _timer?.cancel();
    if (_disposed || _busy || !_dirty) return;
    _busy = true;
    final revision = _revision;
    final value = target!;
    _dirty = false;
    try {
      await seek(value);
    } finally {
      _busy = false;
      if (!_disposed) {
        if (_dirty) {
          unawaited(flush());
        } else if (revision == _revision) {
          _settleTimer = Timer(const Duration(seconds: 3), () {
            target = null;
            changed();
          });
          changed();
        }
      }
    }
  }

  void reset() {
    _revision++;
    _timer?.cancel();
    _settleTimer?.cancel();
    target = null;
    _dirty = false;
  }

  void dispose() {
    _disposed = true;
    reset();
  }
}
