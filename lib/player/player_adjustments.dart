import 'package:flutter/foundation.dart';

/// Keeps fast wheel/button input responsive while serializing native commands.
class PlayerAdjustments extends ChangeNotifier {
  PlayerAdjustments({
    required double volume,
    required Future<void> Function(double) applyVolume,
    required Future<void> Function(int) applyBrightness,
  }) : _volume = volume.clamp(0, 100),
       _appliedVolume = volume.clamp(0, 100),
       // Preserve the public callback names for the native adapter.
       // ignore: prefer_initializing_formals
       _applyVolume = applyVolume,
       // ignore: prefer_initializing_formals
       _applyBrightness = applyBrightness;

  final Future<void> Function(double) _applyVolume;
  final Future<void> Function(int) _applyBrightness;
  double _volume;
  double _appliedVolume;
  int _brightness = 0;
  int _appliedBrightness = 0;
  int _volumeRevision = 0;
  int _volumeSettled = 0;
  int _brightnessRevision = 0;
  Future<void> _volumeTail = Future.value();
  Future<void> _brightnessTail = Future.value();
  bool _disposed = false;

  double get volume => _volume;
  int get brightness => _brightness;

  void syncVolume(double value) {
    if (_disposed || _volumeRevision != _volumeSettled || !value.isFinite) {
      return;
    }
    final bounded = value.clamp(0, 100).toDouble();
    _appliedVolume = bounded;
    if (_volume == bounded) return;
    _volume = bounded;
    notifyListeners();
  }

  /// External system brightness changes do not issue a second native command.
  void syncBrightness(int value) {
    if (_disposed) return;
    final bounded = value.clamp(-100, 100);
    _appliedBrightness = bounded;
    if (_brightness != bounded) {
      _brightness = bounded;
      notifyListeners();
    }
  }

  Future<void> setVolume(double value) {
    if (_disposed || !value.isFinite) return Future.value();
    final target = value.clamp(0, 100).toDouble();
    final revision = ++_volumeRevision;
    _volume = target;
    notifyListeners();
    final operation = _volumeTail.then((_) async {
      if (_disposed || revision != _volumeRevision) return;
      try {
        await _applyVolume(target);
        _appliedVolume = target;
      } catch (_) {
        if (!_disposed && revision == _volumeRevision) {
          _volume = _appliedVolume;
          notifyListeners();
        }
        rethrow;
      } finally {
        if (revision == _volumeRevision) _volumeSettled = revision;
      }
    });
    _volumeTail = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return operation;
  }

  Future<void> setBrightness(int value) {
    if (_disposed) return Future.value();
    final target = value.clamp(-100, 100);
    final revision = ++_brightnessRevision;
    _brightness = target;
    notifyListeners();
    final operation = _brightnessTail.then((_) async {
      if (_disposed || revision != _brightnessRevision) return;
      try {
        await _applyBrightness(target);
        _appliedBrightness = target;
      } catch (_) {
        if (!_disposed && revision == _brightnessRevision) {
          _brightness = _appliedBrightness;
          notifyListeners();
        }
        rethrow;
      }
    });
    _brightnessTail = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return operation;
  }

  Future<void> flush() async {
    await Future.wait([_volumeTail, _brightnessTail]);
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
