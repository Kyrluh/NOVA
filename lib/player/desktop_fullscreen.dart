import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

abstract interface class FullscreenWindow {
  Future<void> setFullscreen(bool value);
}

class NativeFullscreenWindow implements FullscreenWindow {
  static const _channel = MethodChannel('nova/window');
  @override
  Future<void> setFullscreen(bool value) =>
      _channel.invokeMethod<void>('setFullscreen', value);
}

/// One window mode shared by global F11 and the active player's overlay.
class DesktopFullscreen extends ChangeNotifier {
  DesktopFullscreen({FullscreenWindow? window})
    : _window = window ?? NativeFullscreenWindow();
  static final instance = DesktopFullscreen();
  final FullscreenWindow _window;
  final Map<Object, _PlayerBinding> _players = {};
  bool _fullscreen = false;
  bool _busy = false;
  bool get isFullscreen => _fullscreen;
  bool get hasExpandedPlayer => _players.values.any((p) => p.expanded());

  void registerPlayer(
    Object owner, {
    required bool Function() visible,
    required bool Function() expanded,
    required Future<void> Function() toggle,
  }) {
    _players[owner] = _PlayerBinding(visible, expanded, toggle);
  }

  void unregisterPlayer(Object owner) => _players.remove(owner);

  Future<void> toggle() async {
    for (final player in _players.values.toList().reversed) {
      if (player.expanded()) {
        await player.toggle();
        return;
      }
    }
    for (final player in _players.values.toList().reversed) {
      if (player.visible()) {
        await player.toggle();
        return;
      }
    }
    await setFullscreen(!_fullscreen);
  }

  Future<void> setFullscreen(bool value) async {
    if (_busy || value == _fullscreen) return;
    _busy = true;
    try {
      await _window.setFullscreen(value);
      _fullscreen = value;
      notifyListeners();
    } finally {
      _busy = false;
    }
  }
}

class _PlayerBinding {
  const _PlayerBinding(this.visible, this.expanded, this.toggle);
  final bool Function() visible;
  final bool Function() expanded;
  final Future<void> Function() toggle;
}
