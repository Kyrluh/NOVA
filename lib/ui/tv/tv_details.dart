import 'package:flutter/material.dart';

import '../../domain/models.dart';
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
  DemoEpisode? get _resumeEpisode {
    DemoEpisode? result;
    DateTime? latest;
    for (final season in _item.seasons) {
      for (final episode in season.episodes) {
        final progress = widget.controller.progress[episode.id];
        if (progress != null &&
            !progress.completed &&
            progress.positionSeconds > 0 &&
            (latest == null || progress.lastWatched.isAfter(latest))) {
          result = episode;
          latest = progress.lastWatched;
        }
      }
    }
    return result;
  }

  void _resumeSeason() {
    final episode = _resumeEpisode;
    if (episode == null) return;
    final index = _item.seasons.indexWhere(
      (season) => season.episodes.any((e) => e.id == episode.id),
    );
    if (index >= 0) _season = index;
  }

  bool _loading = false;
  String? _error;
  int _request = 0;
  @override
  void initState() {
    super.initState();
    _resumeSeason();
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
          _resumeSeason();
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

  void _play(String uri, String title, String id) {
    Navigator.of(context).push(
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
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final app = widget.controller;
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
                      _resumeEpisode?.mediaUrl?.isNotEmpty == true)
                    FilledButton.icon(
                      autofocus: true,
                      onPressed: () => _play(
                        _resumeEpisode!.mediaUrl!,
                        _resumeEpisode!.title,
                        _resumeEpisode!.id,
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
                      setState(() {
                        _item = version;
                        _season = 0;
                        _error = null;
                        _loading = false;
                        _resumeSeason();
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
                          if (value != null) setState(() => _season = value);
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView.separated(
                        key: ValueKey('tv-episodes-$_season'),
                        itemCount: episodes.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final episode = episodes[index];
                          final progress = app.progress[episode.id];
                          return TvTile(
                            autofocus: index == 0 && _resumeEpisode == null,
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
                                  if (progress != null && progress.fraction > 0)
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
