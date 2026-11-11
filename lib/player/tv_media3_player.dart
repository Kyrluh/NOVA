import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';

/// Only decoder identifiers are accepted here, never native error messages or
/// media locations. These fields are shown on request in stream information.
@immutable
class TvPlaybackDiagnostics {
  const TvPlaybackDiagnostics({
    this.engineVersion = '1.11.1',
    this.videoCodec,
    this.audioCodec,
    this.videoDecoder,
    this.audioDecoder,
    this.firstFrame = false,
  });

  final String engineVersion;
  final String? videoCodec;
  final String? audioCodec;
  final String? videoDecoder;
  final String? audioDecoder;
  final bool firstFrame;

  static final _identifier = RegExp(r'^[a-zA-Z0-9_.+/\-]{1,120}$');
  static final _version = RegExp(r'^\d+\.\d+\.\d+(?:-[a-zA-Z0-9.]+)?$');
  static String? _safeIdentifier(Object? value) =>
      value is String && _identifier.hasMatch(value) ? value : null;

  TvPlaybackDiagnostics update(Map<Object?, Object?> event) =>
      TvPlaybackDiagnostics(
        engineVersion:
            event['engineVersion'] is String &&
                _version.hasMatch(event['engineVersion'] as String)
            ? event['engineVersion'] as String
            : engineVersion,
        videoCodec: event.containsKey('videoCodec')
            ? _safeIdentifier(event['videoCodec'])
            : videoCodec,
        audioCodec: event.containsKey('audioCodec')
            ? _safeIdentifier(event['audioCodec'])
            : audioCodec,
        videoDecoder: event.containsKey('videoDecoder')
            ? _safeIdentifier(event['videoDecoder'])
            : videoDecoder,
        audioDecoder: event.containsKey('audioDecoder')
            ? _safeIdentifier(event['audioDecoder'])
            : audioDecoder,
        firstFrame: event['firstFrame'] is bool
            ? event['firstFrame'] as bool
            : firstFrame,
      );

  @override
  bool operator ==(Object other) =>
      other is TvPlaybackDiagnostics &&
      engineVersion == other.engineVersion &&
      videoCodec == other.videoCodec &&
      audioCodec == other.audioCodec &&
      videoDecoder == other.videoDecoder &&
      audioDecoder == other.audioDecoder &&
      firstFrame == other.firstFrame;

  @override
  int get hashCode => Object.hash(
    engineVersion,
    videoCodec,
    audioCodec,
    videoDecoder,
    audioDecoder,
    firstFrame,
  );
}

/// Keeps NOVA's playback controls/state contract while Android owns decoding and
/// the SurfaceView. No mpv player or Flutter video texture is created for TV.
class TvMedia3Player extends PlatformPlayer {
  TvMedia3Player({this.isLive = false})
    : id = ++_nextId,
      super(configuration: const PlayerConfiguration(title: 'NOVA IPTV')) {
    _sessions[id] = this;
    _channel.setMethodCallHandler(_receive);
    _ready = _channel.invokeMethod<void>('create', {'id': id});
    // Observe initialization failures even if the widget is removed immediately.
    unawaited(_ready.then<void>((_) {}, onError: (Object _, StackTrace _) {}));
  }

  static const _channel = MethodChannel('nova/tv_player');
  static final _sessions = <int, TvMedia3Player>{};
  static int _nextId = 0;
  final int id;
  bool isLive;
  late final Future<void> _ready;
  bool _disposed = false;
  int _generation = 0;
  SubtitleTrack? _externalSubtitle;
  final diagnostics = ValueNotifier(const TvPlaybackDiagnostics());

  Future<void> get ready => _ready;

  static Future<void> _receive(MethodCall call) async {
    if (call.method != 'event' || call.arguments is! Map) return;
    final event = Map<Object?, Object?>.from(call.arguments as Map);
    final session = _sessions[event['id']];
    if (session == null || session._disposed) return;
    if (event['generation'] != session._generation) return;
    session._event(event);
  }

  Future<void> _command(
    String method, [
    Map<String, Object?> args = const {},
  ]) async {
    await _ready;
    if (_disposed) return;
    await _channel.invokeMethod<void>(method, {
      'id': id,
      'generation': _generation,
      ...args,
    });
  }

  void _event(Map<Object?, Object?> event) {
    switch (event['type']) {
      case 'state':
        final old = state;
        final width = (event['width'] as num?)?.toInt() ?? old.width;
        final height = (event['height'] as num?)?.toInt() ?? old.height;
        final audioId = event['audioTrack'] as String?;
        final subtitleId = event['subtitleTrack'] as String?;
        final track = old.track.copyWith(
          audio: audioId == null ? null : _audio(audioId),
          subtitle: subtitleId == null ? null : _subtitle(subtitleId),
        );
        state = old.copyWith(
          playing: event['playing'] as bool?,
          buffering: event['buffering'] as bool?,
          completed: event['completed'] as bool?,
          position: _duration(event['positionMs']) ?? old.position,
          duration: _duration(event['durationMs']) ?? old.duration,
          buffer: _duration(event['bufferedMs']) ?? old.buffer,
          rate: (event['rate'] as num?)?.toDouble(),
          volume: (event['volume'] as num?)?.toDouble(),
          width: width,
          height: height,
          track: track,
        );
        if (state.playing != old.playing) playingController.add(state.playing);
        if (state.buffering != old.buffering) {
          bufferingController.add(state.buffering);
        }
        if (state.completed != old.completed) {
          completedController.add(state.completed);
        }
        if (state.position != old.position) {
          positionController.add(state.position);
        }
        if (state.duration != old.duration) {
          durationController.add(state.duration);
        }
        if (state.buffer != old.buffer) bufferController.add(state.buffer);
        if (state.rate != old.rate) rateController.add(state.rate);
        if (state.volume != old.volume) volumeController.add(state.volume);
        if (state.track != old.track) trackController.add(state.track);
        if (width != old.width || height != old.height) {
          state = state.copyWith(
            videoParams: VideoParams(
              w: width,
              h: height,
              dw: width,
              dh: height,
              rotate: 0,
            ),
          );
          widthController.add(width);
          heightController.add(height);
          videoParamsController.add(state.videoParams);
        }
      case 'tracks':
        final tracks = Tracks(
          audio: [
            AudioTrack.auto(),
            AudioTrack.no(),
            for (final entry in (event['audio'] as List? ?? const []))
              if (entry is Map && entry['id'] is String)
                AudioTrack(
                  entry['id'] as String,
                  entry['title'] as String?,
                  entry['language'] as String?,
                  codec: entry['codec'] as String?,
                ),
          ],
          subtitle: [
            SubtitleTrack.auto(),
            SubtitleTrack.no(),
            for (final entry in (event['subtitles'] as List? ?? const []))
              if (entry is Map && entry['id'] is String)
                entry['id'] == 'external' && _externalSubtitle != null
                    ? _externalSubtitle!
                    : SubtitleTrack(
                        entry['id'] as String,
                        entry['title'] as String?,
                        entry['language'] as String?,
                        codec: entry['codec'] as String?,
                      ),
          ],
        );
        state = state.copyWith(tracks: tracks);
        tracksController.add(tracks);
      case 'error':
        // Never propagate a native exception or a signed media URL.
        errorController.add('Le lecteur Android ne peut pas lire ce contenu.');
      case 'diagnostics':
        diagnostics.value = diagnostics.value.update(event);
    }
  }

  static Duration? _duration(Object? value) => value is num
      ? Duration(milliseconds: value.toInt().clamp(0, 1 << 53))
      : null;

  AudioTrack _audio(String id) =>
      state.tracks.audio.where((t) => t.id == id).firstOrNull ??
      AudioTrack(id, null, null);
  SubtitleTrack _subtitle(String id) =>
      id == 'external' && _externalSubtitle != null
      ? _externalSubtitle!
      : state.tracks.subtitle.where((t) => t.id == id).firstOrNull ??
            SubtitleTrack(id, null, null);

  @override
  Future<void> open(Playable playable, {bool play = true}) async {
    if (playable is! Media) {
      throw UnsupportedError('Single media session required');
    }
    _generation++;
    _externalSubtitle = null;
    diagnostics.value = const TvPlaybackDiagnostics();
    state = PlayerState(
      playlist: Playlist([playable]),
      track: Track(subtitle: SubtitleTrack.no()),
      volume: state.volume,
      rate: state.rate,
      buffering: true,
    );
    playlistController.add(state.playlist);
    playingController.add(false);
    completedController.add(false);
    bufferingController.add(true);
    positionController.add(Duration.zero);
    durationController.add(Duration.zero);
    tracksController.add(state.tracks);
    trackController.add(state.track);
    await _command('open', {
      'uri': playable.uri,
      'isLive': isLive,
      'startMs': isLive ? 0 : playable.start?.inMilliseconds ?? 0,
      'headers': playable.httpHeaders,
    });
    if (play) await this.play();
  }

  @override
  Future<void> stop() async {
    _generation++;
    diagnostics.value = const TvPlaybackDiagnostics();
    await _command('stop');
    state = state.copyWith(
      playing: false,
      buffering: false,
      completed: false,
      position: Duration.zero,
    );
    playingController.add(false);
    bufferingController.add(false);
    completedController.add(false);
    positionController.add(Duration.zero);
  }

  @override
  Future<void> play() => _command('play');
  @override
  Future<void> pause() => _command('pause');
  @override
  Future<void> playOrPause() => state.playing ? pause() : play();
  @override
  Future<void> seek(Duration duration) => isLive
      ? Future.value()
      : _command('seek', {
          'positionMs': duration.inMilliseconds.clamp(0, 1 << 53),
        });
  @override
  Future<void> setVolume(double volume) =>
      _command('volume', {'value': volume.clamp(0, 100)});
  @override
  Future<void> setRate(double rate) =>
      _command('rate', {'value': rate.clamp(.25, 3)});
  @override
  Future<void> setAudioTrack(AudioTrack track) =>
      _command('audio', {'idTrack': track.id});
  @override
  Future<void> setSubtitleTrack(SubtitleTrack track) async {
    if (!track.uri && !track.data) {
      await _command('subtitle', {'idTrack': track.id});
      return;
    }
    if (_externalSubtitle == track && state.tracks.subtitle.contains(track)) {
      await _command('subtitle', {'idTrack': 'external'});
      return;
    }
    final previous = _externalSubtitle;
    _externalSubtitle = track;
    try {
      await _command('externalSubtitle', {
        if (track.uri) 'uri': track.id,
        if (track.data) 'data': track.id,
        'title': track.title,
      });
    } catch (_) {
      _externalSubtitle = previous;
      rethrow;
    }
  }

  Future<void> resize(BoxFit fit) => _command('resize', {'fit': _fit(fit)});
  static String _fit(BoxFit fit) => switch (fit) {
    BoxFit.cover => 'cover',
    BoxFit.fill => 'fill',
    _ => 'contain',
  };

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _sessions.remove(id);
    try {
      await _ready;
      await _channel.invokeMethod<void>('dispose', {'id': id});
    } catch (_) {
      // The activity may already be gone. Local streams still need releasing.
    } finally {
      diagnostics.dispose();
      await super.dispose();
    }
  }
}

/// Hybrid composition keeps the decoder's SurfaceView out of Flutter's external
/// texture pipeline. Rebuilding controls does not recreate the Android player.
class TvMedia3Surface extends StatefulWidget {
  const TvMedia3Surface({super.key, required this.player, required this.fit});
  final TvMedia3Player player;
  final BoxFit fit;
  @override
  State<TvMedia3Surface> createState() => _TvMedia3SurfaceState();
}

class _TvMedia3SurfaceState extends State<TvMedia3Surface> {
  @override
  void didUpdateWidget(TvMedia3Surface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fit != widget.fit) {
      unawaited(widget.player.resize(widget.fit).catchError((Object _) {}));
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
    future: widget.player.ready,
    builder: (context, snapshot) =>
        snapshot.connectionState != ConnectionState.done || snapshot.hasError
        ? const ColoredBox(color: Colors.black)
        : PlatformViewLink(
            viewType: 'nova/tv_video',
            surfaceFactory: (context, controller) => AndroidViewSurface(
              controller: controller as AndroidViewController,
              gestureRecognizers:
                  const <Factory<OneSequenceGestureRecognizer>>{},
              hitTestBehavior: PlatformViewHitTestBehavior.transparent,
            ),
            onCreatePlatformView: (params) =>
                PlatformViewsService.initExpensiveAndroidView(
                    id: params.id,
                    viewType: 'nova/tv_video',
                    layoutDirection: TextDirection.ltr,
                    creationParams: {
                      'id': widget.player.id,
                      'fit': TvMedia3Player._fit(widget.fit),
                    },
                    creationParamsCodec: const StandardMessageCodec(),
                  )
                  ..addOnPlatformViewCreatedListener(
                    params.onPlatformViewCreated,
                  )
                  ..create(),
          ),
  );
}
