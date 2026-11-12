import 'dart:async';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../state/app_controller.dart';
import 'widgets/exit_choice.dart';

/// Stays mounted while the profile picker replaces the application shell.
class WindowCloseHost extends StatefulWidget {
  const WindowCloseHost({
    super.key,
    required this.controller,
    required this.enabled,
    this.child,
    this.builder,
  });
  final AppController controller;
  final bool enabled;
  final Widget? child;
  final Widget Function(GlobalKey<NavigatorState>)? builder;
  @override
  State<WindowCloseHost> createState() => _WindowCloseHostState();
}

class _WindowCloseHostState extends State<WindowCloseHost> with WindowListener {
  bool _closing = false;
  final _navigatorKey = GlobalKey<NavigatorState>();
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
    final dialogContext = _navigatorKey.currentState?.overlay?.context;
    if (dialogContext != null) {
      await showExitChoice(dialogContext, widget.controller);
    } else {
      await widget.controller.shutdown();
      await windowManager.setPreventClose(false);
      await windowManager.close();
    }
    _closing = false;
  }

  @override
  void dispose() {
    if (widget.enabled) windowManager.removeListener(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder?.call(_navigatorKey) ?? widget.child!;
}
