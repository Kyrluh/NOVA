import 'dart:async';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../state/app_controller.dart';

/// Stays mounted while the profile picker replaces the application shell.
class WindowCloseHost extends StatefulWidget {
  const WindowCloseHost({
    super.key,
    required this.controller,
    required this.enabled,
    required this.child,
  });
  final AppController controller;
  final bool enabled;
  final Widget child;
  @override
  State<WindowCloseHost> createState() => _WindowCloseHostState();
}

class _WindowCloseHostState extends State<WindowCloseHost> with WindowListener {
  bool _closing = false;
  @override
  void initState() {
    super.initState();
    if (widget.enabled) {
      windowManager.addListener(this);
      unawaited(windowManager.setPreventClose(true));
    }
  }

  @override
  void onWindowClose() async {
    if (_closing) return;
    _closing = true;
    await widget.controller.shutdown();
    await windowManager.setPreventClose(false);
    await windowManager.close();
  }

  @override
  void dispose() {
    if (widget.enabled) windowManager.removeListener(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
