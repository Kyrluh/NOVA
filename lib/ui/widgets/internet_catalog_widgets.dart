import 'dart:async';

import 'package:flutter/material.dart';

import '../../domain/internet_catalog.dart';
import '../../domain/models.dart';
import '../../domain/platform_catalog.dart';
import '../../state/app_controller.dart';
import '../theme.dart';
import 'media_artwork.dart';

class InternetCatalogControls extends StatelessWidget {
  const InternetCatalogControls({super.key, required this.controller});
  final AppController controller;
  @override
  Widget build(BuildContext context) {
    final api = controller.internetCatalog;
    final button = FilledButton.icon(
      key: const ValueKey('internet-update'),
      onPressed: api == null || api.running
          ? null
          : () => unawaited(api.refresh()),
      icon: api?.running == true
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.cloud_sync_outlined, size: 18),
      label: const Text(
        'Mettre a jour par internet',
        maxLines: 2,
        textAlign: TextAlign.center,
      ),
    );
    return LayoutBuilder(
      builder: (context, bounds) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (api?.running == true)
            IconButton(
              tooltip: 'Arrêter la mise à jour internet',
              onPressed: api!.cancel,
              icon: const Icon(Icons.close_rounded, size: 19),
            ),
          if (bounds.maxWidth.isFinite) Flexible(child: button) else button,
        ],
      ),
    );
  }
}

class InternetCatalogStatus extends StatelessWidget {
  const InternetCatalogStatus({super.key, required this.controller});
  final AppController controller;
  @override
  Widget build(BuildContext context) {
    final api = controller.internetCatalog;
    if (api == null) return const SizedBox.shrink();
    final date = api.lastUpdated?.toLocal();
    final status = api.running
        ? 'Actualisation en cours · ${api.completed}/${api.total}. Vous pouvez continuer à utiliser NOVA.'
        : api.message ??
              (date == null
                  ? 'Sans clé ni compte · actualise aussi les tendances de l’accueil.'
                  : 'Dernière réception : ${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')} à ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}.');
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            status,
            style: const TextStyle(color: novaMuted, fontSize: 12, height: 1.5),
          ),
          const SizedBox(height: 5),
          const Text(
            'Sélections non exhaustives : Streaming Catalogs / JustWatch · Popularité : Cinemeta. La disponibilité varie selon le pays.',
            style: TextStyle(color: novaMuted, fontSize: 10, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class InternetTitlesRail extends StatefulWidget {
  const InternetTitlesRail({
    super.key,
    required this.controller,
    required this.titles,
    required this.onDetails,
  });
  final AppController controller;
  final List<InternetTitle> titles;
  final void Function(MediaItem) onDetails;
  @override
  State<InternetTitlesRail> createState() => _InternetTitlesRailState();
}

class InternetHomeTrends extends StatelessWidget {
  const InternetHomeTrends({
    super.key,
    required this.controller,
    required this.onDetails,
  });
  final AppController controller;
  final void Function(MediaItem) onDetails;
  @override
  Widget build(BuildContext context) {
    final api = controller.internetCatalog;
    final available = {
      for (final kind in [MediaKind.movie, MediaKind.series])
        kind:
            api?.availableTrending(kind, controller.items) ?? <InternetTitle>[],
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final kind in [MediaKind.movie, MediaKind.series])
          if (available[kind]!.isNotEmpty) ...[
            const SizedBox(height: 28),
            Text(
              kind == MediaKind.movie
                  ? 'Tendances du moment · Films'
                  : 'Tendances du moment · Séries',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            const Text(
              'Tendances présentes dans vos sources.',
              style: TextStyle(color: novaMuted, fontSize: 12),
            ),
            const SizedBox(height: 16),
            InternetTitlesRail(
              key: ValueKey('home-trends-${kind.name}'),
              controller: controller,
              titles: available[kind]!,
              onDetails: onDetails,
            ),
          ],
      ],
    );
  }
}

class _InternetTitlesRailState extends State<InternetTitlesRail> {
  final _scroll = ScrollController();
  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final titles = widget.titles
        .where(
          (title) =>
              widget.controller.internetCatalog?.libraryMatch(
                title,
                widget.controller.items,
              ) !=
              null,
        )
        .toList();
    if (titles.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 300,
      child: Scrollbar(
        controller: _scroll,
        child: ListView.separated(
          controller: _scroll,
          scrollDirection: Axis.horizontal,
          itemCount: titles.length,
          padding: const EdgeInsets.only(bottom: 12),
          separatorBuilder: (_, _) => const SizedBox(width: 16),
          itemBuilder: (context, index) => SizedBox(
            width: 156,
            child: InternetTitleCard(
              controller: widget.controller,
              key: ValueKey('${titles[index].kind.name}/${titles[index].id}'),
              title: titles[index],
              onDetails: widget.onDetails,
            ),
          ),
        ),
      ),
    );
  }
}

class InternetTitleCard extends StatelessWidget {
  const InternetTitleCard({
    super.key,
    required this.controller,
    required this.title,
    required this.onDetails,
  });
  final AppController controller;
  final InternetTitle title;
  final void Function(MediaItem) onDetails;
  @override
  Widget build(BuildContext context) {
    final match = controller.internetCatalog?.libraryMatch(
      title,
      controller.items,
    );
    if (match == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              fit: StackFit.expand,
              children: [
                MediaArtwork(item: match, controller: controller),
                Material(
                  type: MaterialType.transparency,
                  child: InkWell(
                    onTap: () {
                      onDetails(match);
                    },
                    child: Semantics(
                      button: true,
                      label: 'Ouvrir ${match.title}',
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  left: 7,
                  right: 7,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 5,
                          horizontal: 6,
                        ),
                        child: Text(
                          'DANS VOS SOURCES',
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xffa4e7ca),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          match.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(
          '${title.year > 0 ? '${title.year} · ' : ''}${title.kind == MediaKind.movie ? 'Film' : 'Série'}',
          style: const TextStyle(color: novaMuted, fontSize: 11),
        ),
      ],
    );
  }
}

Future<void> showInternetSelection(
  BuildContext context,
  AppController app,
  CatalogPlatform platform,
  void Function(MediaItem) onDetails,
) async {
  await showDialog<void>(
    context: context,
    builder: (context) => ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final titles =
            app.internetCatalog?.availableSelection(platform, app.items) ??
            <InternetTitle>[];
        return Dialog(
          child: SizedBox(
            width: 1000,
            height: 650,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Disponibles · ${platform.label}',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Fermer la sélection internet',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 22),
                  child: Text(
                    'Uniquement les films et séries retrouvés dans vos sources. Chaque titre ouvre sa fiche de lecture.',
                    style: TextStyle(color: novaMuted, fontSize: 12),
                  ),
                ),
                Expanded(
                  child: titles.isEmpty
                      ? const Center(
                          child: Text(
                            'Aucun titre de cette sélection dans vos sources.',
                          ),
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.all(22),
                          itemCount: titles.length,
                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 185,
                                childAspectRatio: .57,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 20,
                              ),
                          itemBuilder: (_, index) => InternetTitleCard(
                            controller: app,
                            title: titles[index],
                            onDetails: (item) {
                              Navigator.of(context).pop();
                              onDetails(item);
                            },
                          ),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
