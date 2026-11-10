import 'dart:async';

import 'package:flutter/services.dart';

enum MediaPlaybackCommand { toggle, play, pause }

/// Routes standard multimedia keys to the visible player, even when a search
/// field or another control has keyboard focus within NOVA.
class DesktopMediaControls {
  static final instance = DesktopMediaControls();
  static const _channel = MethodChannel('nova/media_keys');
  final _players =
      <
        Object,
        ({
          bool Function() visible,
          Future<void> Function(MediaPlaybackCommand) command,
        })
      >{};

  void register(
    Object owner, {
    required bool Function() visible,
    required Future<void> Function(MediaPlaybackCommand) command,
  }) {
    if (_players.isEmpty) {
      HardwareKeyboard.instance.addHandler(_handleKey);
      _channel.setMethodCallHandler((call) async {
        if (call.method != 'mediaCommand') return;
        final action = switch (call.arguments) {
          'playPause' => MediaPlaybackCommand.toggle,
          'play' => MediaPlaybackCommand.play,
          'pause' => MediaPlaybackCommand.pause,
          _ => null,
        };
        if (action != null) await _dispatch(action);
      });
    }
    _players[owner] = (visible: visible, command: command);
  }

  void unregister(Object owner) {
    _players.remove(owner);
    if (_players.isEmpty) {
      HardwareKeyboard.instance.removeHandler(_handleKey);
      _channel.setMethodCallHandler(null);
    }
  }

  bool _handleKey(KeyEvent event) {
    final command = switch (event.logicalKey) {
      LogicalKeyboardKey.mediaPlayPause => MediaPlaybackCommand.toggle,
      LogicalKeyboardKey.mediaPlay => MediaPlaybackCommand.play,
      LogicalKeyboardKey.mediaPause => MediaPlaybackCommand.pause,
      _ => null,
    };
    if (command == null || !_players.values.any((p) => p.visible())) {
      return false;
    }
    if (event is KeyDownEvent) unawaited(_dispatch(command));
    return true;
  }

  Future<void> _dispatch(MediaPlaybackCommand command) async {
    for (final binding in _players.values.toList().reversed) {
      if (binding.visible()) {
        await binding.command(command);
        return;
      }
    }
  }
}
