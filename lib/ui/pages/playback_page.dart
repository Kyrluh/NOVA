import 'package:flutter/material.dart';

import '../../domain/models.dart';
import '../../player/desktop_fullscreen.dart';
import '../../player/nova_player.dart';
import '../../state/app_controller.dart';
import '../episode_navigation.dart';
import '../widgets/live_guide_hud.dart';

@immutable
class EpisodePlaybackSpec {
  const EpisodePlaybackSpec({
    required this.uri,
    required this.title,
    required this.live,
    required this.start,
    required this.episodeNavigation,
    required this.onClose,
    required this.onReleased,
    this.mediaId,
    this.onPreviousEpisode,
    this.onNextEpisode,
    this.onProgress,
  });
  final String uri;
  final String title;
  final bool live;
  final String? mediaId;
  final Duration start;
  final bool episodeNavigation;
  final VoidCallback onClose;
  final VoidCallback onReleased;
  final VoidCallback? onPreviousEpisode;
  final VoidCallback? onNextEpisode;
  final void Function(Duration position, Duration duration)? onProgress;
}

/// A route owns one player State while only its media changes for next episode.
class NovaPlaybackPage extends StatefulWidget {
  const NovaPlaybackPage({
    super.key,
    required this.controller,
    required this.uri,
    required this.title,
    required this.live,
    this.mediaId,
    this.seriesId,
    this.fullscreenController,
    this.onReleased,
    this.playerBuilder,
    this.television = false,
  });
  final AppController controller;
  final String uri;
  final String title;
  final bool live;
  final bool television;
  final String? mediaId;
  final String? seriesId;
  final DesktopFullscreen? fullscreenController;
  final VoidCallback? onReleased;
  @visibleForTesting
  final Widget Function(EpisodePlaybackSpec)? playerBuilder;
  @override
  State<NovaPlaybackPage> createState() => _NovaPlaybackPageState();
}

class _NovaPlaybackPageState extends State<NovaPlaybackPage> {
  late String _uri = widget.uri;
  late final String _profileId = widget.controller.activeProfileId;
  late String _title = widget.title;
  late String? _id = widget.mediaId;
  late Duration _start = _resumePosition(_id);
  Duration _resumePosition(String? id) {
    final progress = id == null ? null : widget.controller.progress[id];
    return Duration(
      seconds: progress?.completed == true ? 0 : progress?.positionSeconds ?? 0,
    );
  }

  void _changeEpisode(DemoEpisode episode) {
    setState(() {
      _id = episode.id;
      _uri = episode.mediaUrl!;
      _title = episode.title;
      _start = _resumePosition(episode.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = widget.controller.settings;
    final id = _id;
    final navigation = EpisodeNavigation(
      widget.seriesId == null
          ? null
          : widget.controller.itemById(widget.seriesId!),
      id,
    );
    final previous = navigation.previous;
    final next = navigation.next;
    final spec = EpisodePlaybackSpec(
      uri: _uri,
      title: _title,
      live: widget.live,
      mediaId: id,
      start: _start,
      episodeNavigation: !widget.live && navigation.isResolved,
      onPreviousEpisode: previous == null
          ? null
          : () => _changeEpisode(previous),
      onNextEpisode: next == null ? null : () => _changeEpisode(next),
      onClose: () => Navigator.of(context).pop(),
      onReleased: () => widget.onReleased?.call(),
      onProgress: id == null
          ? null
          : (position, duration) {
              if (duration.inSeconds <= 0 ||
                  widget.controller.activeProfileId != _profileId) {
                return;
              }
              widget.controller.recordProgress(
                id,
                WatchProgress(
                  positionSeconds: position.inSeconds,
                  durationSeconds: duration.inSeconds,
                  lastWatched: DateTime.now(),
                  completed: position.inSeconds >= duration.inSeconds * .95,
                ),
              );
            },
    );
    final liveChannel = widget.live
        ? widget.controller.items.where((item) => item.id == _id).firstOrNull
        : null;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child:
            widget.playerBuilder?.call(spec) ??
            NovaPlayer(
              television: widget.television,
              key: const ValueKey('route-player'),
              fullscreenController: widget.fullscreenController,
              uri: _uri,
              title: _title,
              isLive: widget.live,
              liveGuideBuilder: liveChannel != null
                  ? (compact) => LiveGuideHud(
                      controller: widget.controller,
                      channel: liveChannel,
                      compact: compact,
                    )
                  : null,
              initialRate: settings.playbackRate,
              initialVolume: settings.volume,
              touchGestures: !widget.television && settings.touchGestures,
              brightnessGestures: settings.brightnessGestures,
              volumeGestures: settings.volumeGestures,
              seekGestures: settings.seekGestures,
              reconnectEnabled: settings.reconnectEnabled,
              reconnectAttempts: settings.reconnectAttempts,
              reconnectDelaySeconds: settings.reconnectDelaySeconds,
              pictureInPicture: !widget.television && settings.pictureInPicture,
              landscapeFullscreen: settings.landscapeFullscreen,
              autoNext: settings.autoNext,
              episodeNavigation: spec.episodeNavigation,
              onPreviousEpisode: spec.onPreviousEpisode,
              onNextEpisode: spec.onNextEpisode,
              start: spec.start,
              onClose: spec.onClose,
              onProgress: spec.onProgress,
              onReleased: spec.onReleased,
            ),
      ),
    );
  }
}
