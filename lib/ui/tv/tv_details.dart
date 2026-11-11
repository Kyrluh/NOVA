import 'package:flutter/material.dart';

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
          120.0 *
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
              child: Column(
                children: [
                  Expanded(
                    child: SizedBox(
                      width: double.infinity,
                      child: MediaArtwork(item: _item, controller: app),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_item.kind == MediaKind.series &&
                      resume?.episode.mediaUrl?.isNotEmpty == true)
                    FilledButton.icon(
                      autofocus: true,
                      onPressed: () => _play(
                        resume!.episode.mediaUrl!,
                        resume.episode.title,
                        resume.episode.id,
                      ),
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Reprendre l’épisode'),
                    ),
                  OutlinedButton.icon(
                    onPressed: () => app.toggleFavorite(_item.id),
                    icon: Icon(
                      app.favorites.contains(_item.id)
                          ? Icons.favorite
                          : Icons.favorite_border,
                    ),
                    label: const Text('Favori'),
                  ),
                  if (app.canResume(_item))
                    TextButton(
                      onPressed: () => app.dismissResume(_item.id),
                      child: const Text(
                        'Retirer de Reprendre',
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
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
                  const SizedBox(height: 12),
                  Text(
                    _item.description.isEmpty
                        ? 'Aucun synopsis fourni par cette source.'
                        : _item.description,
                    maxLines: _item.kind == MediaKind.series ? 3 : 8,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 16),
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
                  if (_item.kind == MediaKind.movie &&
                      _item.mediaUrl?.isNotEmpty == true)
                    FilledButton.icon(
                      autofocus: true,
                      onPressed: () =>
                          _play(_item.mediaUrl!, _item.title, _item.id),
                      icon: const Icon(Icons.play_arrow),
                      label: Text(
                        app.canResume(_item)
                            ? 'Reprendre le film'
                            : 'Lire le film',
                      ),
                    ),
                  if (_item.kind == MediaKind.series &&
                      _item.seasons.isNotEmpty) ...[
                    SizedBox(
                      width: 220,
                      child: DropdownButtonFormField<int>(
                        key: ValueKey('tv-season-${_item.id}-$_season'),
                        initialValue: _season,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Saison'),
                        items: [
                          for (var i = 0; i < _item.seasons.length; i++)
                            DropdownMenuItem(
                              value: i,
                              child: Text('Saison ${_item.seasons[i].number}'),
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
                    ),
                    const SizedBox(height: 12),
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
                              autofocus: index == 0 && resume == null,
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
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          '${episode.number}'.padLeft(2, '0'),
                                          style: const TextStyle(fontSize: 20),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Text(
                                            episode.title,
                                            maxLines: 2,
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
                                        padding: const EdgeInsets.only(top: 8),
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
          ],
        ),
      );
    },
  );
}
