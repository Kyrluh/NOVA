import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'state/app_controller.dart';
import 'player/desktop_fullscreen.dart';
import 'ui/shell.dart';
import 'ui/theme.dart';

class NovaApp extends StatelessWidget {
  const NovaApp({
    super.key,
    required this.controller,
    this.nativeReady = true,
    this.manageWindow = true,
    this.fullscreenController,
    this.mobileUI,
  });
  final AppController controller;
  final bool nativeReady;
  final bool manageWindow;
  final DesktopFullscreen? fullscreenController;
  final bool? mobileUI;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => MaterialApp(
      title: 'NOVA IPTV',
      debugShowCheckedModeBanner: false,
      locale: const Locale('fr'),
      supportedLocales: const [Locale('fr')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: novaTheme(controller.settings.accent),
      themeAnimationDuration: controller.settings.animations
          ? const Duration(milliseconds: 180)
          : Duration.zero,
      home: !controller.isReady
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : NovaShell(
              controller: controller,
              nativeReady: nativeReady,
              manageWindow: manageWindow,
              fullscreenController: fullscreenController,
              mobileUI: mobileUI,
            ),
    ),
  );
}
