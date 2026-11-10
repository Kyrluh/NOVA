import 'dart:async';

import 'package:flutter/foundation.dart';

/// Visibility for the title and controls, independent of media error handling.
class PlayerChrome extends ChangeNotifier {
  PlayerChrome({this.inactivityDelay = const Duration(seconds: 3)});
  final Duration inactivityDelay;
  Timer? _timer;
  bool _visible = true;
  bool _focused = true;
  bool _pointerInside = true;
  int _menus = 0;
  bool _disposed = false;
  bool get visible => _visible;

  void hide() {
    _timer?.cancel();
    _show(false);
  }

  void toggle() {
    if (_visible) {
      hide();
    } else {
      activity();
    }
  }

  void activity() {
    if (_disposed || !_focused) return;
    _show(true);
    _timer?.cancel();
    if (_menus == 0) _timer = Timer(inactivityDelay, () => _show(false));
  }

  void pointerEnter() {
    _pointerInside = true;
    activity();
  }

  void pointerExit() {
    _pointerInside = false;
    if (_menus == 0) {
      _timer?.cancel();
      _show(false);
    }
  }

  void focusLost() {
    _focused = false;
    _pointerInside = false;
    _timer?.cancel();
    _show(false);
  }

  void focusGained() {
    _focused = true;
    if (_pointerInside) activity();
  }

  void menuOpened() {
    _menus++;
    activity();
  }

  void dismissMenus() {
    _menus = 0;
    if (_pointerInside) {
      activity();
    } else {
      _show(false);
    }
  }

  void menuClosed() {
    if (_menus > 0) _menus--;
    if (_menus == 0) {
      if (_pointerInside) {
        activity();
      } else {
        _timer?.cancel();
        _show(false);
      }
    }
  }

  void _show(bool value) {
    if (_disposed || _visible == value) return;
    _visible = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}
