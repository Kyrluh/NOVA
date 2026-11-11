import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'state/app_controller.dart';
import 'player/desktop_fullscreen.dart';
import 'ui/shell.dart';
import 'ui/theme.dart';
import 'ui/tv/tv_shell.dart';
import 'ui/tv/tv_widgets.dart';
import 'ui/pages/profiles_page.dart';
import 'ui/window_close_host.dart';
import 'ui/pages/source_loading_page.dart';

class NovaApp extends StatelessWidget {
  const NovaApp({
    super.key,
    required this.controller,
    this.nativeReady = true,
    this.manageWindow = true,
    this.fullscreenController,
    this.mobileUI,
    this.television = false,
    this.requireProfiles = false,
  });
  final AppController controller;
  final bool nativeReady;
  final bool manageWindow;
  final DesktopFullscreen? fullscreenController;
  final bool? mobileUI;
  final bool television;
  final bool requireProfiles;

  @override
  Widget build(BuildContext context) => WindowCloseHost(
    controller: controller,
    enabled: manageWindow,
    child: ListenableBuilder(
      listenable: controller,
      builder: (context, _) => MaterialApp(
        title: television ? 'NOVA IPTV TV' : 'NOVA IPTV',
        debugShowCheckedModeBanner: false,
        locale: const Locale('fr'),
        supportedLocales: const [Locale('fr')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: television
            ? novaTvTheme(controller.settings.accent)
            : novaTheme(controller.settings.accent),
        themeAnimationDuration: controller.settings.animations
            ? const Duration(milliseconds: 180)
            : Duration.zero,
        builder: (context, child) {
          final source = controller.sources;
          final importing =
              controller.isReady &&
              source?.catalogLoading == true &&
              !source!.startupRefreshing;
          return Stack(
            children: [
              ExcludeFocus(
                excluding: importing,
                child: IgnorePointer(
                  ignoring: importing,
                  child: child ?? const SizedBox(),
                ),
              ),
              if (importing)
                Positioned.fill(child: SourceLoadingPage(controller: source)),
            ],
          );
        },
        home:
            !controller.isReady ||
                (controller.refreshSourcesOnStartup &&
                    controller.sources?.hasConfiguredSources == true &&
                    !controller.sources!.startupFinished)
            ? SourceLoadingPage(
                controller: controller.sources,
                initializing: !controller.isReady,
              )
            : requireProfiles && !controller.profileChosen
            ? ProfilesPage(controller: controller)
            : requireProfiles && !controller.activeProfile.genresConfigured
            ? ProfileEditor(
                key: ValueKey(controller.activeProfileId),
                controller: controller,
                onboarding: true,
              )
            : television
            ? NovaTvShell(
                key: ValueKey(controller.activeProfileId),
                controller: controller,
                nativeReady: nativeReady,
              )
            : NovaShell(
                key: ValueKey(controller.activeProfileId),
                controller: controller,
                nativeReady: nativeReady,
                manageWindow: manageWindow,
                handleWindowClose: false,
                fullscreenController: fullscreenController,
                mobileUI: mobileUI,
              ),
      ),
    ),
  );
}
