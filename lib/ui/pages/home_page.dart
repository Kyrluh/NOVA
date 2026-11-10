import 'package:flutter/material.dart';

import '../../domain/models.dart';
import '../../state/app_controller.dart';
import '../shell.dart';
import '../adaptive.dart';
import '../theme.dart';
import '../widgets/media_artwork.dart';
import '../widgets/internet_catalog_widgets.dart';
import 'catalog_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.controller,
    required this.onDetails,
    required this.onOpenFile,
    required this.onNavigate,
    this.onManageSources,
  });
  final AppController controller;
  final void Function(MediaItem) onDetails;
  final VoidCallback onOpenFile;
  final void Function(NovaSection) onNavigate;
  final VoidCallback? onManageSources;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 600;
    final android = NovaAdaptiveScope.isAndroid(context);
    final inset = novaPageInset(context);
    final textScale = (MediaQuery.textScalerOf(context).scale(14) / 14).clamp(
      1.0,
      2.5,
    );
    final resume = controller.resumeItems;
    final movies = controller.items
        .where((e) => e.kind == MediaKind.movie)
        .take(android ? 24 : controller.items.length)
        .toList();
    final series = controller.items
        .where((e) => e.kind == MediaKind.series)
        .take(android ? 24 : controller.items.length)
        .toList();
    final favorites = controller.items
        .where((e) => controller.favorites.contains(e.id))
        .take(android ? 24 : controller.items.length)
        .toList();
    final featured =
        movies.firstOrNull ??
        series.firstOrNull ??
        controller.items.firstOrNull;
    if (featured == null) {
      final hiddenByRules = controller.allItems.isNotEmpty;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.video_library_outlined,
                size: 48,
                color: novaMuted,
              ),
              const SizedBox(height: 20),
              Text(
                hiddenByRules
                    ? 'Vos contenus sont masqués par vos règles de tri.'
                    : 'Votre bibliothèque est prête à accueillir vos contenus.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              if (hiddenByRules)
                FilledButton.icon(
                  onPressed: () => onNavigate(NovaSection.organize),
                  icon: const Icon(Icons.sort_rounded),
                  label: const Text('Revoir le tri'),
                )
              else if (onManageSources != null)
                FilledButton.icon(
                  onPressed: onManageSources,
                  icon: const Icon(Icons.add),
                  label: const Text('Gérer mes sources'),
                ),
            ],
          ),
        ),
      );
    }
    return ListView(
      key: const PageStorageKey('home-scroll'),
      padding: EdgeInsets.fromLTRB(
        android
            ? inset
            : compact
            ? inset
            : 30,
        0,
        android
            ? inset
            : compact
            ? inset
            : 30,
        30,
      ),
      children: [
        RepaintBoundary(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: SizedBox(
              height:
                  (compact
                      ? (android
                            ? 370
                            : MediaQuery.sizeOf(context).width < 360
                            ? 460
                            : 420)
                      : android
                      ? 210
                      : 365) *
                  textScale,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  MediaArtwork(
                    item: featured,
                    landscape: true,
                    controller: controller,
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        stops: [0, .5, 1],
                        colors: [
                          Color(0xF5080B14),
                          Color(0xC5080B14),
                          Color(0x00080B14),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(
                      android
                          ? 12
                          : compact
                          ? 20
                          : 34,
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: SizedBox(
                        width: 500,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              featured.isDemo
                                  ? 'À LA UNE  /  DÉMONSTRATION'
                                  : 'DANS VOTRE BIBLIOTHÈQUE',
                              style: TextStyle(
                                fontSize: 10,
                                letterSpacing: 2,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            SizedBox(height: android ? 8 : 20),
                            Text(
                              featured.title,
                              maxLines: 2,
                              style: TextStyle(
                                fontSize: android
                                    ? 28
                                    : compact
                                    ? 32
                                    : 47,
                                height: 1.02,
                                letterSpacing: -1.8,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: android ? 8 : 13),
                            Text(
                              [
                                if (featured.year > 0) '${featured.year}',
                                featured.category,
                                if (featured.durationMinutes > 0)
                                  '${featured.durationMinutes} min',
                              ].join('     '),
                              maxLines: android && !compact ? 1 : 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFFBDC2D3),
                              ),
                            ),
                            SizedBox(height: android ? 8 : 14),
                            if (!android || compact)
                              Text(
                                featured.description,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  height: 1.6,
                                  color: Color(0xFFBDC2D3),
                                ),
                              ),
                            SizedBox(height: android ? 12 : 23),
                            Wrap(
                              spacing: 12,
                              runSpacing: 8,
                              children: [
                                FilledButton.icon(
                                  onPressed: () => onDetails(featured),
                                  icon: const Icon(
                                    Icons.info_outline_rounded,
                                    size: 18,
                                  ),
                                  label: const Text('Découvrir'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: onOpenFile,
                                  icon: const Icon(
                                    Icons.play_arrow_rounded,
                                    size: 19,
                                  ),
                                  label: const Text('Ouvrir ma vidéo'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (!compact)
                    const Positioned(
                      right: 24,
                      bottom: 24,
                      child: Text(
                        'NOVA COLLECTION',
                        style: TextStyle(
                          fontSize: 9,
                          letterSpacing: 2,
                          color: Colors.white54,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        _quickActions(context, compact),
        if (onManageSources != null) ...[
          const SizedBox(height: 18),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onManageSources,
              icon: const Icon(Icons.playlist_add_rounded),
              label: Text(
                controller.isDemo
                    ? 'Ajouter ma source M3U ou Xtream'
                    : 'Gérer mes sources IPTV',
              ),
            ),
          ),
        ],
        if (resume.isNotEmpty) ...[
          const SizedBox(height: 28),
          _heading(
            'Reprendre',
            'Vos histoires vous attendent',
            () => onNavigate(NovaSection.resume),
          ),
          MediaRail(
            key: const ValueKey('home-resume'),
            controller: controller,
            items: resume,
            onDetails: onDetails,
          ),
        ],
        if (controller.internetCatalog != null)
          InternetHomeTrends(controller: controller, onDetails: onDetails),
        if (movies.isNotEmpty) ...[
          const SizedBox(height: 28),
          _heading(
            'À l’affiche',
            'Une sélection pour explorer NOVA',
            () => onNavigate(NovaSection.movies),
          ),
          MediaRail(
            controller: controller,
            items: movies,
            onDetails: onDetails,
          ),
        ],
        if (series.isNotEmpty) ...[
          const SizedBox(height: 26),
          _heading(
            'Des histoires à suivre',
            'Les séries du moment',
            () => onNavigate(NovaSection.series),
          ),
          MediaRail(
            controller: controller,
            items: series,
            onDetails: onDetails,
          ),
        ],
        if (favorites.isNotEmpty) ...[
          const SizedBox(height: 26),
          _heading(
            'Votre sélection',
            'Vos favoris, toujours à portée',
            () => onNavigate(NovaSection.favorites),
          ),
          MediaRail(
            controller: controller,
            items: favorites,
            onDetails: onDetails,
          ),
        ],
        const SizedBox(height: 30),
        Text(
          controller.isDemo
              ? 'Catalogue fictif • Affiches originales créées localement • Aucune source IPTV préconfigurée'
              : '${controller.items.length} contenus provenant de vos sources personnelles',
          textAlign: TextAlign.center,
          style: TextStyle(color: novaMuted, fontSize: 11),
        ),
      ],
    );
  }

  Widget _quickActions(BuildContext context, bool compact) {
    final television = _quickTile(
      context,
      'La télévision, en un endroit',
      controller.isDemo
          ? 'Explorer les chaînes de démonstration'
          : 'Retrouver vos chaînes et leur guide TV',
      Icons.live_tv_rounded,
      () => onNavigate(NovaSection.live),
    );
    final settings = _quickTile(
      context,
      'À votre rythme',
      'Vitesse de lecture de 0,25× à 3×',
      Icons.speed_rounded,
      () => onNavigate(NovaSection.settings),
    );
    return compact
        ? Column(children: [television, const SizedBox(height: 12), settings])
        : Row(
            children: [
              Expanded(child: television),
              const SizedBox(width: 16),
              Expanded(child: settings),
            ],
          );
  }

  Widget _quickTile(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onTap,
  ) => Material(
    color: novaSurface,
    borderRadius: BorderRadius.circular(12),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Color(controller.settings.accent).withValues(alpha: .1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 20,
                color: Color(controller.settings.accent),
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 11, color: novaMuted),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_rounded, size: 17, color: novaMuted),
          ],
        ),
      ),
    ),
  );

  Widget _heading(String title, String subtitle, VoidCallback onAll) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(color: novaMuted, fontSize: 11),
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: onAll,
          child: const Row(
            children: [
              Text('Tout voir', style: TextStyle(fontSize: 12)),
              SizedBox(width: 6),
              Icon(Icons.chevron_right_rounded, size: 17),
            ],
          ),
        ),
      ],
    ),
  );
}
