import 'package:flutter/material.dart';

import '../../domain/models.dart';
import '../../domain/source_models.dart';
import '../../state/app_controller.dart';
import '../theme.dart';
import '../adaptive.dart';
import '../widgets/media_artwork.dart';
import '../widgets/page_widgets.dart';

void showMediaDetails(
  BuildContext context, {
  required AppController controller,
  required MediaItem item,
  required void Function(String uri, String title, String id) onPlay,
  bool? mobileUI,
}) {
  final android = mobileUI ?? NovaAdaptiveScope.isAndroid(context);
  showDialog<void>(
    context: context,
    builder: (context) => NovaAdaptiveScope(
      android: android,
      child: _DetailsDialog(controller: controller, item: item, onPlay: onPlay),
    ),
  );
}

class _DetailsDialog extends StatefulWidget {
  const _DetailsDialog({
    required this.controller,
    required this.item,
    required this.onPlay,
  });
  final AppController controller;
  final MediaItem item;
  final void Function(String uri, String title, String id) onPlay;
  @override
  State<_DetailsDialog> createState() => _DetailsDialogState();
}

class _DetailsDialogState extends State<_DetailsDialog> {
  late MediaItem _item;
  int _season = 0;
  bool _loading = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _item = widget.item;
    _load();
  }

  Future<void> _load() async {
    if (_item.isDemo || _item.detailsLoaded) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final detailed = await widget.controller.loadDetails(_item);
      if (mounted) {
        setState(() {
          _item = detailed;
          _season = 0;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is SourceException ? error.message : 'Impossible de charger les informations. Réessayez dans un instant.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _play(String uri, String title, String id) {
    Navigator.pop(context);
    widget.onPlay(uri, title, id);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final app = widget.controller;
      final item = _item;
      final tablet = novaTablet(context);
      final metadata = [
        if (item.year > 0) '${item.year}',
        item.category,
        if (item.durationMinutes > 0) '${item.durationMinutes} min',
        if (item.seasons.isNotEmpty) '${item.seasons.length} saisons',
      ].join('   •   ');
      return Dialog(
        insetPadding: EdgeInsets.symmetric(
          horizontal: tablet
              ? 12
              : MediaQuery.sizeOf(context).width < 600
              ? 12
              : 40,
          vertical: 24,
        ),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: tablet
              ? (MediaQuery.sizeOf(context).width - 24).clamp(0, 1000)
              : 850,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height - 70,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: tablet
                        ? 168
                        : MediaQuery.sizeOf(context).width < 600
                        ? 205
                        : 235,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (tablet)
                          Row(
                            children: [
                              SizedBox(
                                width: 112,
                                child: MediaArtwork(
                                  item: item,
                                  controller: app,
                                ),
                              ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    20,
                                    20,
                                    52,
                                    20,
                                  ),
                                  child: Text(
                                    item.title,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          )
                        else
                          MediaArtwork(
                            item: item,
                            landscape: true,
                            controller: app,
                          ),
                        if (!tablet)
                          const DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Colors.transparent, novaSurface],
                              ),
                            ),
                          ),
                        Positioned(
                          top: 12,
                          right: 12,
                          child: IconButton.filledTonal(
                            tooltip: 'Fermer',
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ),
                        if (!tablet)
                          Positioned(
                            left: 28,
                            right: 28,
                            bottom: 16,
                            child: Text(
                              item.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: MediaQuery.sizeOf(context).width < 600
                                    ? 28
                                    : 34,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (_loading) const LinearProgressIndicator(minHeight: 2),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      tablet ? 18 : 28,
                      10,
                      tablet ? 18 : 28,
                      20,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          metadata,
                          style: const TextStyle(color: novaMuted),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          item.description.isEmpty
                              ? 'Aucun synopsis fourni par cette source.'
                              : item.description,
                          style: TextStyle(
                            fontSize: tablet ? 13 : 15,
                            height: tablet ? 1.45 : 1.7,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Wrap(
                          spacing: 12,
                          runSpacing: 10,
                          children: [
                            if (item.mediaUrl?.isNotEmpty == true)
                              FilledButton.icon(
                                onPressed: () =>
                                    _play(item.mediaUrl!, item.title, item.id),
                                icon: const Icon(Icons.play_arrow_rounded),
                                label: Text(
                                  (app.progress[item.id]?.positionSeconds ??
                                                  0) >
                                              0 &&
                                          app.progress[item.id]?.completed !=
                                              true
                                      ? 'Reprendre'
                                      : 'Lecture',
                                ),
                              ),
                            OutlinedButton.icon(
                              onPressed: () => app.toggleFavorite(item.id),
                              icon: Icon(
                                app.favorites.contains(item.id)
                                    ? Icons.favorite_rounded
                                    : Icons.favorite_border_rounded,
                              ),
                              label: Text(
                                app.favorites.contains(item.id)
                                    ? 'Dans mes favoris'
                                    : 'Ajouter aux favoris',
                              ),
                            ),
                            if (_error != null)
                              TextButton.icon(
                                onPressed: _loading ? null : _load,
                                icon: const Icon(Icons.refresh),
                                label: const Text('Réessayer'),
                              ),
                          ],
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 16),
                          NovaNotice(icon: Icons.info_outline, text: _error!),
                        ],
                        if (item.isDemo) ...[
                          const SizedBox(height: 20),
                          const NovaNotice(
                            icon: Icons.auto_awesome_outlined,
                            text: 'Création fictive du catalogue de démonstration. Aucun flux vidéo n’est associé à cette fiche.',
                          ),
                        ],
                        if (!_loading &&
                            !item.isDemo &&
                            item.kind == MediaKind.series &&
                            item.seasons.isEmpty)
                          const Padding(
                            padding: EdgeInsets.only(top: 20),
                            child: Text(
                              'Aucun épisode fourni par cette source.',
                              style: TextStyle(color: novaMuted),
                            ),
                          ),
                        if (item.seasons.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          DropdownButton<int>(
                            value: _season.clamp(0, item.seasons.length - 1),
                            items: [
                              for (var i = 0; i < item.seasons.length; i++)
                                DropdownMenuItem(
                                  value: i,
                                  child: Text(
                                    'Saison ${item.seasons[i].number}',
                                  ),
                                ),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _season = value);
                              }
                            },
                          ),
                          for (final episode in item.seasons[_season].episodes)
                            _episode(app, episode, item.isDemo),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );

  Widget _episode(AppController app, DemoEpisode episode, bool demo) {
    final progress = app.progress[episode.id];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .05),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text('${episode.number}'.padLeft(2, '0')),
            ),
            title: Text(episode.title),
            subtitle: Text(
              [
                if (episode.durationMinutes > 0)
                  '${episode.durationMinutes} min',
                if (demo) 'Épisode fictif',
                if (progress?.completed == true) 'Vu',
              ].join(' • '),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (episode.mediaUrl?.isNotEmpty == true)
                  IconButton.filledTonal(
                    tooltip:
                        (progress?.positionSeconds ?? 0) > 0 &&
                            progress?.completed != true
                        ? 'Reprendre cet épisode'
                        : 'Lire cet épisode',
                    onPressed: () => _play(
                      episode.mediaUrl!,
                      '${_item.title} · ${episode.title}',
                      episode.id,
                    ),
                    icon: const Icon(Icons.play_arrow_rounded),
                  ),
                IconButton(
                  tooltip: progress?.completed == true
                      ? 'Épisode vu'
                      : 'Marquer comme vu',
                  onPressed: progress?.completed == true
                      ? null
                      : () => app.markWatched(episode.id),
                  icon: Icon(
                    progress?.completed == true
                        ? Icons.check_circle
                        : Icons.check_circle_outline,
                  ),
                ),
              ],
            ),
          ),
          if (progress != null && progress.fraction > 0)
            LinearProgressIndicator(value: progress.fraction, minHeight: 2),
        ],
      ),
    );
  }
}
