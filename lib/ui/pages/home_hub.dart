import 'package:flutter/material.dart';

import '../../domain/models.dart';
import '../../state/app_controller.dart';
import '../widgets/media_artwork.dart';
import 'catalog_page.dart';

class HomeHub extends StatelessWidget {
  const HomeHub({
    super.key,
    required this.controller,
    required this.onNavigate,
    required this.onDetails,
  });
  final AppController controller;
  final ValueChanged<String> onNavigate;
  final ValueChanged<MediaItem> onDetails;
  @override
  Widget build(BuildContext context) {
    final suggestions = controller.recommendations;
    final featured = suggestions.firstOrNull;
    return ListView(
      key: const PageStorageKey('home-scroll'),
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Bonjour ${controller.activeProfile.name}',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            IconButton(
              tooltip: 'Changer de profil',
              icon: const Icon(Icons.switch_account_outlined),
              onPressed: controller.showProfilePicker,
            ),
            IconButton(
              tooltip: 'Paramètres',
              icon: const Icon(Icons.settings_outlined),
              onPressed: () => onNavigate('settings'),
            ),
          ],
        ),
        const SizedBox(height: 18),
        if (featured != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 275),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: MediaArtwork(
                      item: featured,
                      landscape: true,
                      controller: controller,
                    ),
                  ),
                  const Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Color(0xF5080B14),
                            Color(0xA0080B14),
                            Color(0x40080B14),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'UNE ENVIE À DÉCOUVRIR',
                          style: TextStyle(letterSpacing: 2, fontSize: 11),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          featured.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          featured.category,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            FilledButton.icon(
                              onPressed: () => onDetails(featured),
                              icon: const Icon(Icons.play_arrow),
                              label: const Text('Découvrir'),
                            ),
                            OutlinedButton.icon(
                              onPressed: controller.shuffleRecommendations,
                              icon: const Icon(Icons.shuffle),
                              label: const Text('Autre suggestion'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 24),
        LayoutBuilder(
          builder: (context, bounds) {
            final columns = bounds.maxWidth < 550 ? 2 : 3;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final action in const [
                  ('resume', 'REPRENDRE', Icons.history),
                  ('favorites', 'FAVORIS', Icons.favorite_border),
                  ('live', 'TV', Icons.live_tv),
                  ('movies', 'FILMS', Icons.movie_outlined),
                  ('series', 'SÉRIES', Icons.video_library_outlined),
                  ('platforms', 'PAR PLATEFORME', Icons.dashboard_outlined),
                ])
                  SizedBox(
                    width: (bounds.maxWidth - (columns - 1) * 12) / columns,
                    child: OutlinedButton(
                      onPressed: () => onNavigate(action.$1),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 24,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(action.$3, size: 28),
                          const SizedBox(height: 12),
                          Text(
                            action.$2,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        if (controller.isDemo)
          TextButton.icon(
            onPressed: () => onNavigate('settings'),
            icon: const Icon(Icons.add),
            label: const Text('Ajouter mes sources dans les paramètres'),
          ),
        if (controller.resumeItems.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text('Reprendre', style: Theme.of(context).textTheme.headlineSmall),
          MediaRail(
            key: const ValueKey('home-resume'),
            controller: controller,
            items: controller.resumeItems.take(20).toList(),
            onDetails: onDetails,
          ),
        ],
        if (controller.recentlyAddedItems.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(
            'Récemment ajoutés',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          MediaRail(
            controller: controller,
            items: controller.recentlyAddedItems.take(24).toList(),
            onDetails: onDetails,
          ),
        ],
      ],
    );
  }
}
