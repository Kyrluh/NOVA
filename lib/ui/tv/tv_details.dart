import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/models.dart';
import '../../domain/episode_resume.dart';
import '../../state/app_controller.dart';
import '../pages/playback_page.dart';
import '../widgets/media_artwork.dart';
import '../theme.dart';
import 'tv_widgets.dart';
import '../widgets/variant_picker.dart';

class TvDetails extends StatefulWidget {
  const TvDetails({super.key, required this.controller, required this.item});
  final AppController controller;
  final MediaItem item;
  @override
  State<TvDetails> createState() => _TvDetailsState();
}

class _TvDetailsState extends State<TvDetails> {
  late MediaItem _item = widget.controller.preferredVariant(widget.item);
  int _season = 0;
  final _episodesScroll = ScrollController(keepScrollOffset: false);
  final _resumeFocus = FocusNode(debugLabel: 'TV current resume episode');
  String? _lastResumeId;
  bool _revealRequested = false;
  bool _playing = false;
  bool _focusAfterReturn = false;

  EpisodeResumeTarget? _syncResume(double extent) {
    final target = episodeResumeTarget(_item, widget.controller.progress);
    final token = target == null
        ? null
        : '${target.episode.id}|${target.seasonIndex}|${target.episodeIndex}';
    if (target == null) _focusAfterReturn = false;
    if (_lastResumeId != token) {
      _lastResumeId = token;
      _revealRequested = target != null;
      if (target != null) _season = target.seasonIndex;
    }
    if (_revealRequested &&
        target?.seasonIndex == _season &&
        !_playing &&
        (ModalRoute.of(context)?.isCurrent ?? true)) {
      _revealRequested = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted ||
            _lastResumeId != token ||
            !_episodesScroll.hasClients ||
            _playing) {
          return;
        }
        _episodesScroll.jumpTo(
          (target!.episodeIndex * extent).clamp(
            0.0,
            _episodesScroll.position.maxScrollExtent,
          ),
        );
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted &&
              _lastResumeId == token &&
              _focusAfterReturn &&
              !_playing) {
            _focusAfterReturn = false;
            _resumeFocus.requestFocus();
          }
        });
        if (_focusAfterReturn) WidgetsBinding.instance.scheduleFrame();
      });
    }
    return target;
  }

  @override
  void dispose() {
    widget.controller.cancelDetails(_item);
    _episodesScroll.dispose();
    _resumeFocus.dispose();
    super.dispose();
  }

  bool _loading = false;
  String? _error;
  int _request = 0;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final request = ++_request;
    if (_item.detailsLoaded || _item.isDemo) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final detailed = await widget.controller.loadDetails(_item);
      if (mounted && request == _request) {
        setState(() {
          _item = detailed;
          _lastResumeId = null;
        });
      }
    } catch (_) {
      if (mounted && request == _request) {
        setState(
          () => _error = 'Informations indisponibles. Vous pouvez réessayer.',
        );
      }
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  Future<void> _play(String uri, String title, String id) async {
    setState(() => _playing = true);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => NovaPlaybackPage(
          controller: widget.controller,
          uri: uri,
          title: title,
          live: false,
          mediaId: id,
          seriesId: _item.kind == MediaKind.series ? _item.id : null,
          television: true,
        ),
      ),
    );
    if (mounted) {
      setState(() {
        _playing = false;
        _lastResumeId = null;
        _focusAfterReturn = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final app = widget.controller;
      final extent =
          96.0 *
          (MediaQuery.textScalerOf(context).scale(16) / 16).clamp(1.0, 3.0);
      final resume = _syncResume(extent);
      final episodes = _item.seasons.isEmpty
          ? const <DemoEpisode>[]
          : _item.seasons[_season].episodes;
      return TvPageFrame(
        title: _item.title,
        autofocusBack: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 170,
              child: AspectRatio(
                aspectRatio: 2 / 3,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    height: double.infinity,
                    width: double.infinity,
                    child: MediaArtwork(item: _item, controller: app),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: LayoutBuilder(
                builder: (context, bounds) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Flexible(
                      flex: 0,
                      fit: FlexFit.loose,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight:
                              _item.kind == MediaKind.series &&
                                  _item.seasons.isNotEmpty
                              ? bounds.maxHeight * .40
                              : bounds.maxHeight * .60,
                        ),
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              VariantPicker(
                                controller: app,
                                item: _item,
                                onChanged: (version) {
                                  widget.controller.cancelDetails(_item);
                                  setState(() {
                                    _item = version;
                                    _season = 0;
                                    _error = null;
                                    _loading = false;
                                    _lastResumeId = null;
                                  });
                                  _load();
                                },
                              ),
                              Text(
                                [
                                  if (_item.year > 0) '${_item.year}',
                                  _item.category,
                                  if (_item.durationMinutes > 0)
                                    '${_item.durationMinutes} min',
                                ].join(' · '),
                                style: const TextStyle(color: novaMuted),
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 10,
                                runSpacing: 6,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  if (_item.kind == MediaKind.movie &&
                                      _item.mediaUrl?.isNotEmpty == true)
                                    FilledButton.icon(
                                      key: const ValueKey('tv-details-primary'),
                                      autofocus: true,
                                      onPressed: () => _play(
                                        _item.mediaUrl!,
                                        _item.title,
                                        _item.id,
                                      ),
                                      icon: const Icon(Icons.play_arrow),
                                      label: Text(
                                        app.canResume(_item)
                                            ? 'Reprendre le film'
                                            : 'Lire le film',
                                      ),
                                    ),
                                  OutlinedButton.icon(
                                    onPressed: () =>
                                        app.toggleFavorite(_item.id),
                                    icon: Icon(
                                      app.favorites.contains(_item.id)
                                          ? Icons.favorite
                                          : Icons.favorite_border,
                                      color: app.favorites.contains(_item.id)
                                          ? novaHighlight
                                          : null,
                                    ),
                                    label: Text(
                                      app.favorites.contains(_item.id)
                                          ? 'Dans les favoris'
                                          : 'Ajouter aux favoris',
                                    ),
                                  ),
                                  if (app.canResume(_item))
                                    TextButton(
                                      onPressed: () =>
                                          app.dismissResume(_item.id),
                                      child: const Text('Retirer de Reprendre'),
                                    ),
                                ],
                              ),
                              if (_loading) const LinearProgressIndicator(),
                              if (_error != null)
                                Row(
                                  children: [
                                    Expanded(child: Text(_error!)),
                                    TextButton(
                                      onPressed: _load,
                                      child: const Text('Réessayer'),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (_item.kind != MediaKind.series ||
                        _item.seasons.isEmpty) ...[
                      const SizedBox(height: 8),
                      _synopsis(bounds.maxHeight),
                    ],
                    if (_item.kind == MediaKind.series &&
                        _item.seasons.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          SizedBox(
                            width: 180,
                            child: DropdownButtonFormField<int>(
                              key: ValueKey('tv-season-${_item.id}-$_season'),
                              initialValue: _season,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Saison',
                              ),
                              items: [
                                for (var i = 0; i < _item.seasons.length; i++)
                                  DropdownMenuItem(
                                    value: i,
                                    child: Text(
                                      'Saison ${_item.seasons[i].number}',
                                    ),
                                  ),
                              ],
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() {
                                    _season = value;
                                    _revealRequested =
                                        resume?.seasonIndex == value;
                                  });
                                }
                              },
                            ),
                          ),
                          if (resume?.episode.mediaUrl?.isNotEmpty == true)
                            FilledButton.icon(
                              key: const ValueKey('tv-details-primary'),
                              autofocus: true,
                              onPressed: () => _play(
                                resume!.episode.mediaUrl!,
                                resume.episode.title,
                                resume.episode.id,
                              ),
                              icon: const Icon(Icons.play_arrow),
                              label: const Text('Reprendre l’épisode'),
                            )
                          else if (episodes.any(
                            (e) => e.mediaUrl?.isNotEmpty == true,
                          ))
                            FilledButton.icon(
                              key: const ValueKey('tv-details-primary'),
                              autofocus: true,
                              onPressed: () {
                                final first = episodes.firstWhere(
                                  (e) => e.mediaUrl?.isNotEmpty == true,
                                );
                                _play(first.mediaUrl!, first.title, first.id);
                              },
                              icon: const Icon(Icons.play_arrow),
                              label: const Text('Lire l’épisode'),
                            ),
                          if (resume != null)
                            Text(
                              'S${_item.seasons[resume.seasonIndex].number.toString().padLeft(2, '0')} · E${resume.episode.number.toString().padLeft(2, '0')}',
                              style: const TextStyle(color: novaMuted),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _synopsis(bounds.maxHeight),
                      const SizedBox(height: 8),
                      Expanded(
                        child: ListView.builder(
                          key: ValueKey('tv-episodes-${_item.id}-$_season'),
                          controller: _episodesScroll,
                          itemExtent: extent,
                          itemCount: episodes.length,
                          itemBuilder: (context, index) {
                            final episode = episodes[index];
                            final progress = app.progress[episode.id];
                            final highlighted =
                                !_playing &&
                                resume?.seasonIndex == _season &&
                                resume?.episodeIndex == index;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: TvTile(
                                key: ValueKey('tv-episode-${episode.id}'),
                                selected: highlighted,
                                focusNode: highlighted ? _resumeFocus : null,
                                label:
                                    'Épisode ${episode.number} : ${episode.title}',
                                onPressed: () {
                                  if (episode.mediaUrl?.isNotEmpty == true) {
                                    _play(
                                      episode.mediaUrl!,
                                      episode.title,
                                      episode.id,
                                    );
                                  }
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            '${episode.number}'.padLeft(2, '0'),
                                            style: const TextStyle(
                                              fontSize: 20,
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: Text(
                                              episode.title,
                                              maxLines: highlighted ? 1 : 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          Icon(
                                            episode.mediaUrl?.isNotEmpty == true
                                                ? Icons.play_arrow
                                                : Icons.block,
                                          ),
                                        ],
                                      ),
                                      if (highlighted)
                                        const Text(
                                          'À reprendre',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      if (progress != null &&
                                          progress.fraction > 0)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 8,
                                          ),
                                          child: LinearProgressIndicator(
                                            value: progress.fraction,
                                            minHeight: 3,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ] else if (_item.kind == MediaKind.series &&
                        !_loading &&
                        _error == null)
                      const Text('Aucun épisode disponible dans cette source.'),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    },
  );

  Widget _synopsis(double availableHeight) => _TvSynopsis(
    key: ValueKey('tv-synopsis-${_item.id}'),
    description: _item.description,
    expandedHeight: (availableHeight * .12).clamp(24.0, 64.0).toDouble(),
  );
}

class _TvSynopsis extends StatefulWidget {
  const _TvSynopsis({
    super.key,
    required this.description,
    required this.expandedHeight,
  });
  final String description;
  final double expandedHeight;
  @override
  State<_TvSynopsis> createState() => _TvSynopsisState();
}

class _TvSynopsisState extends State<_TvSynopsis> {
  final _scroll = ScrollController();
  bool _expanded = false;
  bool _focused = false;
  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  KeyEventResult _scrollWithRemote(FocusNode _, KeyEvent event) {
    if (!_expanded ||
        !_scroll.hasClients ||
        (event is! KeyDownEvent && event is! KeyRepeatEvent)) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key != LogicalKeyboardKey.arrowDown &&
        key != LogicalKeyboardKey.arrowUp) {
      return KeyEventResult.ignored;
    }
    final next =
        (_scroll.offset + (key == LogicalKeyboardKey.arrowDown ? 54 : -54))
            .clamp(0.0, _scroll.position.maxScrollExtent);
    if (next == _scroll.offset) return KeyEventResult.ignored;
    _scroll.jumpTo(next);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      final text = widget.description.isEmpty
          ? 'Aucun synopsis fourni par cette source.'
          : widget.description;
      final painter = TextPainter(
        text: TextSpan(text: text, style: DefaultTextStyle.of(context).style),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
        maxLines: 2,
      )..layout(maxWidth: bounds.maxWidth);
      final canExpand = painter.didExceedMaxLines;
      painter.dispose();
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_expanded)
            Focus(
              onFocusChange: (value) => setState(() => _focused = value),
              onKeyEvent: _scrollWithRemote,
              child: Container(
                height: widget.expandedHeight,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _focused ? novaHighlight : Colors.white12,
                    width: 2,
                  ),
                ),
                child: Scrollbar(
                  controller: _scroll,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    key: const ValueKey('tv-synopsis-expanded'),
                    controller: _scroll,
                    child: Text(text),
                  ),
                ),
              ),
            )
          else
            Text(text, maxLines: 2, overflow: TextOverflow.ellipsis),
          if (canExpand)
            TextButton.icon(
              key: const ValueKey('tv-synopsis-toggle'),
              onPressed: () => setState(() => _expanded = !_expanded),
              icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
              label: Text(_expanded ? 'Voir moins' : 'Lire la suite'),
            ),
        ],
      );
    },
  );
}
