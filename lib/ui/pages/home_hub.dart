import 'package:flutter/material.dart';

import '../../domain/models.dart';
import '../../state/app_controller.dart';
import '../adaptive.dart';
import '../tv/tv_widgets.dart';
import '../widgets/media_artwork.dart';
import 'catalog_page.dart';

class HomeHub extends StatelessWidget {
  const HomeHub({
    super.key,
    required this.controller,
    required this.onNavigate,
    required this.onDetails,
    this.television = false,
    this.showHeader = true,
    this.showProfileActions = true,
  });
  final AppController controller;
  final ValueChanged<String> onNavigate;
  final ValueChanged<MediaItem> onDetails;
  final bool television;
  final bool showHeader;
  final bool showProfileActions;

  static const _actions = [
    ('resume', 'REPRENDRE', Icons.history),
    ('favorites', 'FAVORIS', Icons.favorite_border),
    ('live', 'TV', Icons.live_tv),
    ('movies', 'FILMS', Icons.movie_outlined),
    ('series', 'SÉRIES', Icons.video_library_outlined),
    ('platforms', 'PAR PLATEFORME', Icons.dashboard_outlined),
  ];
  @override
  Widget build(BuildContext context) {
    final mobile = !television && NovaAdaptiveScope.isAndroid(context);
    final suggestions = controller.recommendations;
    final featured = suggestions.firstOrNull;
    return ListView(
      key: const PageStorageKey('home-scroll'),
      padding: television
          ? const EdgeInsets.fromLTRB(4, 0, 4, 16)
          : const EdgeInsets.all(20),
      children: [
        if (showHeader)
          Row(
            children: [
              Expanded(
                child: Text(
                  'Bonjour ${controller.activeProfile.name}',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              if (!television && showProfileActions)
                IconButton(
                  tooltip: 'Changer de profil',
                  icon: const Icon(Icons.switch_account_outlined),
                  onPressed: controller.showProfilePicker,
                ),
              if (!television && showProfileActions)
                IconButton(
                  tooltip: 'Paramètres',
                  icon: const Icon(Icons.settings_outlined),
                  onPressed: () => onNavigate('settings'),
                ),
            ],
          ),
        if (showHeader) SizedBox(height: television ? 12 : 18),
        _shortcuts(),
        SizedBox(height: television ? 16 : 24),
        if (featured != null)
          ClipRRect(
            key: const ValueKey('home-featured'),
            borderRadius: BorderRadius.circular(18),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: television
                    ? 170
                    : mobile
                    ? 220
                    : 275,
              ),
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
                    padding: EdgeInsets.all(television ? 16 : 22),
                    child: television
                        ? _tvFeaturedContent(featured)
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                'UNE ENVIE À DÉCOUVRIR',
                                style: TextStyle(
                                  letterSpacing: 2,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                featured.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: mobile ? 25 : 30,
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
                                    onPressed:
                                        controller.shuffleRecommendations,
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

  Widget _shortcuts() => LayoutBuilder(
    builder: (context, bounds) {
      final mobile = !television && NovaAdaptiveScope.isAndroid(context);
      final gap = television ? 8.0 : 12.0;
      final columns = television
          ? (bounds.maxWidth >= 660 ? 6 : 3)
          : mobile
          ? (bounds.maxWidth >= 300 ? 3 : 2)
          : (bounds.maxWidth >= 1000
                ? 6
                : bounds.maxWidth < 550
                ? 2
                : 3);
      return FocusTraversalGroup(
        child: Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final action in _actions)
              SizedBox(
                key: ValueKey('home-shortcut-${action.$1}'),
                width: (bounds.maxWidth - (columns - 1) * gap) / columns,
                child: television
                    ? ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 82),
                        child: TvTile(
                          label: action.$2,
                          onPressed: () => onNavigate(action.$1),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 8,
                            ),
                            child: _shortcutContent(action.$2, action.$3),
                          ),
                        ),
                      )
                    : OutlinedButton(
                        onPressed: () => onNavigate(action.$1),
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: NovaAdaptiveScope.isAndroid(context)
                                ? 14
                                : 20,
                          ),
                        ),
                        child: _shortcutContent(
                          action.$2,
                          action.$3,
                          mobile: mobile,
                        ),
                      ),
              ),
          ],
        ),
      );
    },
  );

  Widget _shortcutContent(String label, IconData icon, {bool mobile = false}) =>
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: television || mobile ? 24 : 28),
          SizedBox(height: television || mobile ? 7 : 12),
          Text(
            label,
            maxLines: television || mobile ? 2 : 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: television || mobile
                ? TextStyle(
                    fontSize: television ? 11 : 12,
                    fontWeight: FontWeight.w700,
                  )
                : null,
          ),
        ],
      );

  Widget _tvFeaturedContent(MediaItem featured) => LayoutBuilder(
    builder: (context, bounds) {
      final title = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'UNE ENVIE À DÉCOUVRIR',
            style: TextStyle(letterSpacing: 1.5, fontSize: 10),
          ),
          const SizedBox(height: 8),
          Text(
            featured.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 24,
              height: 1.15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            featured.category,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12),
          ),
        ],
      );
      final actions = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton.icon(
            onPressed: () => onDetails(featured),
            icon: const Icon(Icons.play_arrow),
            label: const Text('Découvrir'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: controller.shuffleRecommendations,
            icon: const Icon(Icons.shuffle),
            label: const Text('Autre suggestion'),
          ),
        ],
      );
      if (bounds.maxWidth < 460) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [title, const SizedBox(height: 12), actions],
        );
      }
      return Row(
        children: [
          Expanded(child: title),
          const SizedBox(width: 20),
          SizedBox(width: 180, child: actions),
        ],
      );
    },
  );
}
