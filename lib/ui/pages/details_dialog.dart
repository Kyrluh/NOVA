import 'package:flutter/material.dart';

import '../../domain/models.dart';
import '../../domain/episode_resume.dart';
import '../../domain/source_models.dart';
import '../../state/app_controller.dart';
import '../theme.dart';
import '../adaptive.dart';
import '../widgets/media_artwork.dart';
import '../widgets/page_widgets.dart';
import '../widgets/variant_picker.dart';

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
  int _request = 0;
  final _resumeKey = GlobalKey(debugLabel: 'current-resume-episode');
  String? _lastResumeId;
  bool _revealRequested = false;
  bool _expandedSynopsis = false;

  EpisodeResumeTarget? _syncResume() {
    final target = episodeResumeTarget(_item, widget.controller.progress);
    if (_lastResumeId != target?.episode.id) {
      _lastResumeId = target?.episode.id;
      _revealRequested = target != null;
      if (target != null) _season = target.seasonIndex;
    }
    if (_revealRequested && target?.seasonIndex == _season) {
      _revealRequested = false;
      final expected = target!.episode.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _lastResumeId != expected) return;
        final targetContext = _resumeKey.currentContext;
        if (targetContext != null) {
          Scrollable.ensureVisible(
            targetContext,
            alignment: .35,
            duration: const Duration(milliseconds: 160),
          );
        }
      });
    }
    return target;
  }

  @override
  void initState() {
    super.initState();
    _item = widget.controller.preferredVariant(widget.item);
    _load();
  }

  @override
  void dispose() {
    _request++;
    widget.controller.cancelDetails(_item);
    super.dispose();
  }

  Future<void> _load() async {
    final request = ++_request;
    if (_item.isDemo || _item.detailsLoaded) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final detailed = await widget.controller.loadDetails(_item);
      if (mounted && request == _request) {
        setState(() {
          _item = detailed;
          _season = 0;
          _lastResumeId = null;
        });
      }
    } catch (error) {
      if (mounted && request == _request) {
        setState(
          () => _error = error is SourceException ? error.message : 'Impossible de charger les informations. Réessayez dans un instant.',
        );
      }
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
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
      final resume = _syncResume();
      final tablet = novaTablet(context);
      final android = NovaAdaptiveScope.isAndroid(context);
      final compact = android && MediaQuery.sizeOf(context).width < 600;
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
              : compact
              ? 8
              : 40,
          vertical: compact ? 12 : 24,
        ),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: tablet
              ? (MediaQuery.sizeOf(context).width - 24).clamp(0, 1000)
              : compact
              ? MediaQuery.sizeOf(context).width - 16
              : (MediaQuery.sizeOf(context).width - 80).clamp(0, 1100),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight:
                  (MediaQuery.sizeOf(context).height -
                          MediaQuery.viewInsetsOf(context).bottom -
                          (compact ? 32 : 70))
                      .clamp(0, double.infinity),
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: tablet
                        ? 168
                        : compact
                        ? 160
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
                            constraints: const BoxConstraints(
                              minWidth: 48,
                              minHeight: 48,
                            ),
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
                      compact
                          ? 16
                          : tablet
                          ? 18
                          : 28,
                      10,
                      compact
                          ? 16
                          : tablet
                          ? 18
                          : 28,
                      20,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        VariantPicker(
                          controller: app,
                          item: item,
                          onChanged: (version) {
                            widget.controller.cancelDetails(_item);
                            setState(() {
                              _item = version;
                              _season = 0;
                              _lastResumeId = null;
                              _error = null;
                              _loading = false;
                              _expandedSynopsis = false;
                            });
                            _load();
                          },
                        ),
                        Text(
                          metadata,
                          style: const TextStyle(color: novaMuted),
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 12,
                          runSpacing: 10,
                          children: [
                            if (item.kind != MediaKind.series &&
                                item.mediaUrl?.isNotEmpty == true)
                              FilledButton.icon(
                                key: const ValueKey('details-primary'),
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size(0, 48),
                                ),
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
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(0, 48),
                              ),
                              onPressed: () => app.toggleFavorite(item.id),
                              icon: Icon(
                                app.favorites.contains(item.id)
                                    ? Icons.favorite_rounded
                                    : Icons.favorite_border_rounded,
                                color: app.favorites.contains(item.id)
                                    ? novaHighlight
                                    : null,
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
                        if (item.seasons.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          _seasonActions(item, resume),
                        ],
                        const SizedBox(height: 16),
                        _synopsis(tablet),
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
                          for (final entry
                              in item.seasons[_season].episodes.indexed)
                            _episode(
                              app,
                              entry.$2,
                              item.isDemo,
                              resume?.seasonIndex == _season &&
                                  resume?.episodeIndex == entry.$1,
                            ),
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

  Widget _seasonActions(MediaItem item, EpisodeResumeTarget? resume) {
    final episodes =
        item.seasons[_season.clamp(0, item.seasons.length - 1)].episodes;
    final firstPlayable = episodes
        .where((episode) => episode.mediaUrl?.isNotEmpty == true)
        .firstOrNull;
    return Wrap(
      key: const ValueKey('details-season-actions'),
      spacing: 14,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        DropdownButton<int>(
          value: _season.clamp(0, item.seasons.length - 1),
          itemHeight: 48,
          items: [
            for (var i = 0; i < item.seasons.length; i++)
              DropdownMenuItem(
                value: i,
                child: Text('Saison ${item.seasons[i].number}'),
              ),
          ],
          onChanged: (value) {
            if (value != null) {
              setState(() {
                _season = value;
                _revealRequested = resume?.seasonIndex == value;
              });
            }
          },
        ),
        if (resume?.episode.mediaUrl?.isNotEmpty == true)
          FilledButton.icon(
            key: const ValueKey('details-primary'),
            style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
            onPressed: () => _play(
              resume!.episode.mediaUrl!,
              '${item.title} · ${resume.episode.title}',
              resume.episode.id,
            ),
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Reprendre l’épisode'),
          )
        else if (firstPlayable != null)
          FilledButton.icon(
            key: const ValueKey('details-primary'),
            style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
            onPressed: () => _play(
              firstPlayable.mediaUrl!,
              '${item.title} · ${firstPlayable.title}',
              firstPlayable.id,
            ),
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Lire l’épisode'),
          ),
        if (resume != null)
          Text(
            'S${item.seasons[resume.seasonIndex].number.toString().padLeft(2, '0')} · E${resume.episode.number.toString().padLeft(2, '0')}',
            style: const TextStyle(color: novaMuted),
          ),
      ],
    );
  }

  Widget _synopsis(bool tablet) => LayoutBuilder(
    builder: (context, bounds) {
      final description = _item.description.isEmpty
          ? 'Aucun synopsis fourni par cette source.'
          : _item.description;
      final style = TextStyle(
        fontSize: tablet ? 13 : 15,
        height: tablet ? 1.45 : 1.7,
      );
      final painter = TextPainter(
        text: TextSpan(text: description, style: style),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
        maxLines: 3,
      )..layout(maxWidth: bounds.maxWidth);
      final canExpand = painter.didExceedMaxLines;
      painter.dispose();
      return Column(
        key: const ValueKey('details-synopsis'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            description,
            style: style,
            maxLines: _expandedSynopsis ? null : 3,
            overflow: _expandedSynopsis
                ? TextOverflow.visible
                : TextOverflow.ellipsis,
          ),
          if (canExpand)
            TextButton.icon(
              onPressed: () =>
                  setState(() => _expandedSynopsis = !_expandedSynopsis),
              icon: Icon(
                _expandedSynopsis ? Icons.expand_less : Icons.expand_more,
              ),
              label: Text(_expandedSynopsis ? 'Voir moins' : 'Lire la suite'),
            ),
        ],
      );
    },
  );

  Widget _episode(
    AppController app,
    DemoEpisode episode,
    bool demo,
    bool resume,
  ) {
    final progress = app.progress[episode.id];
    return Padding(
      key: resume ? _resumeKey : ValueKey('episode-${episode.id}'),
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        children: [
          ListTile(
            selected: resume,
            selectedTileColor: Theme.of(context).colorScheme.primary
                .withValues(alpha: .16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(
                color: resume
                    ? Theme.of(context).colorScheme.primary
                    : Colors.transparent,
              ),
            ),
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
            title: Text(
              episode.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              [
                if (episode.durationMinutes > 0)
                  '${episode.durationMinutes} min',
                if (demo) 'Épisode fictif',
                if (resume) 'À reprendre',
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
