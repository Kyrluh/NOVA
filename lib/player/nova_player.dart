import 'dart:async';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:window_manager/window_manager.dart';

import 'playback_health.dart';
import 'player_adjustments.dart';
import 'desktop_fullscreen.dart';
import 'desktop_media_controls.dart';
import 'player_chrome.dart';
import 'android_player_host.dart';
import 'android_video_environment.dart';
import 'android_session_player.dart';
import 'seek_coordinator.dart';
import 'tv_channel_panel.dart';
import 'tv_media3_player.dart';

/// Injectable media surface for deterministic interaction tests.
class NovaPlayerBackend {
  const NovaPlayerBackend({
    required this.player,
    required this.videoController,
    this.applyBrightness,
  });
  final Player player;
  final VideoController videoController;
  final Future<void> Function(int)? applyBrightness;
}

enum _SubtitleAction { file }

/// A single, owned playback session shared by the embedded and fullscreen views.
class NovaPlayer extends StatefulWidget {
  const NovaPlayer({
    super.key,
    required this.uri,
    required this.title,
    this.isLive = false,
    this.initialRate = 1,
    this.initialVolume = 80,
    this.start = Duration.zero,
    this.onClose,
    this.onReleased,
    this.onProgress,
    this.backendFactory,
    this.fullscreenController,
    this.fullscreenRequests,
    this.backRequests,
    this.android,
    this.androidHost,
    this.touchGestures = true,
    this.brightnessGestures = true,
    this.volumeGestures = true,
    this.seekGestures = true,
    this.reconnectEnabled = true,
    this.reconnectAttempts = 3,
    this.reconnectDelaySeconds = 3,
    this.pictureInPicture = true,
    this.landscapeFullscreen = true,
    this.onNext,
    this.onPreviousEpisode,
    this.onNextEpisode,
    this.episodeNavigation = false,
    this.autoNext = true,
    this.television = false,
    this.onPreviousChannel,
    this.onNextChannel,
    this.onFullscreenChanged,
    this.handleBackInternally = true,
    this.channelChoices = const [],
    this.selectedChannelId,
    this.onSelectChannel,
    this.liveGuideBuilder,
  });

  final String uri;
  final String title;
  final bool isLive;
  final double initialRate;
  final double initialVolume;
  final Duration start;
  final VoidCallback? onClose;

  /// Completes only after the media session and Android activity flags release.
  final VoidCallback? onReleased;
  final void Function(Duration position, Duration duration)? onProgress;
  @visibleForTesting
  final NovaPlayerBackend Function()? backendFactory;
  final DesktopFullscreen? fullscreenController;
  final ValueNotifier<int>? fullscreenRequests;
  final ValueNotifier<int>? backRequests;
  @visibleForTesting
  final bool? android;
  @visibleForTesting
  final AndroidPlayerHost? androidHost;
  final bool touchGestures;
  final bool brightnessGestures;
  final bool volumeGestures;
  final bool seekGestures;
  final bool reconnectEnabled;
  final int reconnectAttempts;
  final int reconnectDelaySeconds;
  final bool pictureInPicture;
  final bool landscapeFullscreen;
  final VoidCallback? onNext;
  final VoidCallback? onPreviousEpisode;
  final VoidCallback? onNextEpisode;
  final bool episodeNavigation;
  final bool autoNext;
  final bool television;
  final VoidCallback? onPreviousChannel;
  final VoidCallback? onNextChannel;
  final ValueChanged<bool>? onFullscreenChanged;
  final bool handleBackInternally;
  final List<TvChannelOption> channelChoices;
  final String? selectedChannelId;
  final ValueChanged<String>? onSelectChannel;
  final Widget Function(bool compact)? liveGuideBuilder;

  @override
  State<NovaPlayer> createState() => _NovaPlayerState();
}

class _NovaPlayerState extends State<NovaPlayer>
    with WindowListener, WidgetsBindingObserver {
  static const _rates = <double>[.25, .5, .75, 1, 1.25, 1.5, 1.75, 2, 2.5, 3];
  static const _playbackError =
      'La lecture n’a pas pu démarrer ou s’est interrompue. Réessayez dans un instant.';

  final _focus = FocusNode(debugLabel: 'Lecteur NOVA');
  final _fullscreenFocus = FocusNode(debugLabel: 'Lecteur NOVA plein écran');
  final _tvPauseFocus = FocusNode(debugLabel: 'TV playback controls');
  final _subscriptions = <StreamSubscription<dynamic>>[];
  final _health = PlaybackHealth();
  final _chrome = PlayerChrome();
  late final _seeking = SeekCoordinator(
    seek: (target) => _perform(() => _player!.seek(target)),
    changed: _refresh,
  );
  LogicalKeyboardKey? _seekKey;
  int _seekRepeats = 0;
  bool _tvChannelsOpen = false;
  final _videoKey = GlobalKey(debugLabel: 'NOVA owned video texture');
  final _fullscreenNavigatorKey = GlobalKey<NavigatorState>();
  StateSetter? _fullscreenRebuild;
  bool get _isAndroid => widget.android ?? Platform.isAndroid;
  AndroidPlayerHost get _android =>
      widget.androidHost ?? AndroidActivityPlayerHost.instance;
  DesktopFullscreen get _desktop =>
      widget.fullscreenController ?? DesktopFullscreen.instance;
  Player? _player;
  VideoController? _controller;
  TvMedia3Player? _tvMedia3;
  PlayerAdjustments? _adjustments;
  Timer? _hudTimer;
  String? _hud;
  Future<void> _operations = Future<void>.value();
  OverlayEntry? _fullscreenEntry;
  bool _disposed = false;
  bool _opening = true;
  bool _fullscreen = false;
  bool _fullscreenBusy = false;
  bool _showInfo = false;
  int _generation = 0;
  int _activeGeneration = -1;
  int _lastProgressSecond = -1;
  double _audibleVolume = 80;
  double? _scrubPosition;
  String? _error;
  String? _controlError;
  BoxFit _fit = BoxFit.contain;
  Timer? _reconnectTimer;
  Timer? _backgroundTimer;
  bool _touchLocked = false;
  bool _inPip = false;
  bool _pipSupported = false;
  bool _pipWasFullscreen = false;
  bool _userPaused = false;
  bool _backgroundPaused = false;
  bool _nextTriggered = false;
  bool _ended = false;
  AppLifecycleState _lifecycle = AppLifecycleState.resumed;
  bool get _androidInBackground =>
      _isAndroid &&
      !_inPip &&
      (_lifecycle == AppLifecycleState.paused ||
          _lifecycle == AppLifecycleState.hidden ||
          _lifecycle == AppLifecycleState.detached);
  int _reconnectCount = 0;
  _RecoveryState? _recovery;
  bool? _lastKeepScreenOn;
  bool? _lastPipEnabled;
  bool? _lastPlaybackActive;
  bool _verticalLeft = false;
  bool? _touchGesturesOverride;
  bool get _gesturesEnabled => _touchGesturesOverride ?? widget.touchGestures;
  VoidCallback? get _nextEpisode => widget.onNextEpisode ?? widget.onNext;
  bool get _showEpisodeNavigation =>
      !widget.isLive &&
      (widget.episodeNavigation ||
          widget.onPreviousEpisode != null ||
          _nextEpisode != null);
  double _verticalBase = 0;
  double _verticalDistance = 0;
  bool _scalingWithTwoFingers = false;
  bool _pinchApplied = false;
  final _touchPointers = <int>{};
  Offset _doubleTapPosition = Offset.zero;

  @override
  void initState() {
    super.initState();
    widget.fullscreenRequests?.addListener(_externalFullscreen);
    widget.backRequests?.addListener(_externalBack);
    _chrome.addListener(_chromeChanged);
    _chrome.activity();
    if (_isAndroid) {
      WidgetsBinding.instance.addObserver(this);
      _subscriptions.add(_android.events.listen(_androidEvent));
      unawaited(_initializeAndroid());
    } else if (widget.backendFactory == null) {
      windowManager.addListener(this);
    }
    if (!_isAndroid || widget.television) {
      DesktopMediaControls.instance.register(
        this,
        visible: () =>
            !_disposed &&
            mounted &&
            (ModalRoute.of(context)?.isCurrent ?? true),
        command: _mediaCommand,
      );
    }
    if (!_isAndroid) {
      _desktop.registerPlayer(
        this,
        visible: () =>
            !_disposed &&
            mounted &&
            (ModalRoute.of(context)?.isCurrent ?? true),
        expanded: () => !_disposed && _fullscreen,
        toggle: _toggleFullscreen,
      );
    }
    _health.addListener(_healthChanged);
    try {
      final backend = widget.backendFactory?.call();
      if (backend == null && _isAndroid && widget.television) {
        _tvMedia3 = TvMedia3Player(isLive: widget.isLive);
      }
      final player =
          backend?.player ??
          (_tvMedia3 != null
              ? Player(platformPlayer: _tvMedia3)
              : _isAndroid
              ? AndroidSessionPlayer(
                  isLive: widget.isLive,
                  configuration: const PlayerConfiguration(title: 'NOVA IPTV'),
                )
              : Player(
                  configuration: const PlayerConfiguration(title: 'NOVA IPTV'),
                ));
      _player = player;
      if (player is AndroidSessionPlayer) player.isLive = widget.isLive;
      _controller =
          backend?.videoController ??
          (_tvMedia3 == null ? createNovaVideoController(player) : null);
      _adjustments = PlayerAdjustments(
        volume: widget.initialVolume,
        applyVolume: _isAndroid ? _android.setVolume : player.setVolume,
        applyBrightness:
            backend?.applyBrightness ??
            (value) async {
              if (_isAndroid) {
                await _android.setBrightness((value / 100).clamp(.02, 1));
                return;
              }
              final native = player.platform;
              if (native is! NativePlayer) {
                throw StateError('Brightness unavailable');
              }
              await native.setProperty('brightness', '$value');
              final applied = double.tryParse(
                await native.getProperty('brightness'),
              );
              if (applied == null || (applied - value).abs() > .1) {
                throw StateError('Brightness not applied');
              }
            },
      )..addListener(_refresh);
      _audibleVolume = widget.initialVolume.clamp(1, 100).toDouble();
      _subscriptions.add(
        player.stream.playing.listen((_) {
          _syncAndroidPower();
          _refresh();
        }),
      );
      _watch(player.stream.duration);
      _subscriptions.add(
        player.stream.buffering.listen((buffering) {
          if (buffering && !_opening) _health.diagnostic();
          _refresh();
        }),
      );
      _subscriptions.add(
        player.stream.volume.listen((value) {
          if (!_isAndroid && !_opening && !_disposed) {
            _adjustments?.syncVolume(value);
          }
          _refresh();
        }),
      );
      _watch(player.stream.rate);
      _watch(player.stream.tracks);
      _watch(player.stream.track);
      _watch(player.stream.videoParams);
      _watch(player.stream.width);
      _watch(player.stream.height);
      _subscriptions.add(player.stream.completed.listen(_completed));
      _subscriptions.add(
        player.stream.position.listen((position) {
          _seeking.position(position);
          if (_disposed) return;
          if (_activeGeneration == _generation) {
            _health.advance(position, playing: player.state.playing);
          }
          _refresh();
          if (!_opening &&
              !widget.isLive &&
              position.inSeconds != _lastProgressSecond) {
            _lastProgressSecond = position.inSeconds;
            widget.onProgress?.call(position, player.state.duration);
          }
        }),
      );
      _subscriptions.add(
        player.stream.error.listen((_) {
          // Native errors may contain signed stream URLs or provider credentials.
          if (_disposed || _activeGeneration != _generation) return;
          // This stream also contains recoverable decoder diagnostics. A log
          // alone is not proof that playback stopped; advancing media time is.
          _health.diagnostic();
        }),
      );
      _scheduleOpen();
    } catch (_) {
      _opening = false;
      _error = 'Le moteur vidéo n’a pas pu démarrer. Relancez NOVA IPTV.';
    }
  }

  void _watch<T>(Stream<T> stream) {
    _subscriptions.add(stream.listen((_) => _refresh()));
  }

  Future<void> _initializeAndroid() async {
    try {
      final volume = await _android.getVolume();
      final brightness = await _android.getBrightness();
      final pip = await _android.getPipSupported();
      if (_disposed) return;
      _adjustments?.syncVolume(volume);
      _adjustments?.syncBrightness((brightness.clamp(.02, 1) * 100).round());
      _pipSupported = pip;
      _refresh();
    } catch (_) {
      // Unsupported capabilities do not prevent video playback.
    }
  }

  void _ignoreAndroid(Future<void> operation) =>
      unawaited(operation.catchError((Object _) {}));

  void _syncAndroidPower() {
    if (!_isAndroid || _disposed) return;
    final active =
        (_player?.state.playing ?? false) &&
        !_opening &&
        _error == null &&
        !_ended;
    final keepScreenOn =
        active && _lifecycle == AppLifecycleState.resumed && !_inPip;
    final pip = active && widget.pictureInPicture && _pipSupported;
    if (keepScreenOn != _lastKeepScreenOn) {
      _lastKeepScreenOn = keepScreenOn;
      _ignoreAndroid(_android.setKeepScreenOn(keepScreenOn));
    }
    if (active != _lastPlaybackActive) {
      _lastPlaybackActive = active;
      _ignoreAndroid(_android.setPlaybackActive(active));
    }
    if (pip != _lastPipEnabled) {
      _lastPipEnabled = pip;
      _ignoreAndroid(_android.setPipEnabled(pip));
    }
  }

  void _androidEvent(AndroidPlayerEvent event) {
    if (_disposed) return;
    if (event.name == 'pipChanged') {
      final inPip = event.value == true;
      if (_inPip == inPip) return;
      _inPip = inPip;
      if (inPip) {
        _backgroundTimer?.cancel();
        _fullscreenNavigatorKey.currentState?.popUntil(
          (route) => route.isFirst,
        );
        _pipWasFullscreen = _fullscreen;
        if (!_fullscreen && mounted) _enterFullscreenOverlay();
        if (_backgroundPaused && !_userPaused) {
          _backgroundPaused = false;
          _health.setPaused(false);
          _ignoreAndroid(_player!.play());
        }
        _chrome.hide();
      } else {
        if (!_pipWasFullscreen && _fullscreen) _removeFullscreenOverlay();
        _chrome.activity();
        if (_lifecycle != AppLifecycleState.resumed) _scheduleBackgroundPause();
      }
      _syncAndroidPower();
      _refresh();
    } else if (event.name == 'audioFocusPause') {
      if (_player?.state.playing == true) {
        _userPaused = true;
        _health.setPaused(true);
        _ignoreAndroid(_player!.pause());
      }
    } else if (event.name == 'volumeChanged' && event.value is num) {
      _adjustments?.syncVolume((event.value as num).toDouble());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_isAndroid || _disposed) return;
    _lifecycle = state;
    _backgroundTimer?.cancel();
    if (state == AppLifecycleState.resumed) {
      if (_backgroundPaused && !_userPaused) {
        _backgroundPaused = false;
        _health.setPaused(false);
        if (!_health.failed) _ignoreAndroid(_player!.play());
      }
      if (_health.failed) _scheduleReconnect();
      _chrome.activity();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      // PiP callbacks can follow the lifecycle callback during its animation.
      // Inactive alone (folding, rotation, notification shade) is not a pause.
      _scheduleBackgroundPause();
    }
    _syncAndroidPower();
  }

  void _scheduleBackgroundPause() {
    _backgroundTimer?.cancel();
    _backgroundTimer = Timer(const Duration(milliseconds: 300), () {
      if (!_disposed && !_inPip && _lifecycle != AppLifecycleState.resumed) {
        _pauseForBackground();
      }
    });
  }

  void _pauseForBackground() {
    if (_disposed || _player == null || _inPip) return;
    _reconnectTimer?.cancel();
    if (_player!.state.playing) {
      _backgroundPaused = true;
      _health.setPaused(true);
      _ignoreAndroid(_player!.pause());
    }
    _chrome.hide();
    _syncAndroidPower();
  }

  void _completed(bool completed) {
    if (_disposed || _opening) return;
    _ended = completed;
    if (!completed) return;
    if (widget.isLive) {
      _health.fail();
      return;
    }
    _health.setPaused(true);
    _syncAndroidPower();
    if (widget.autoNext && _nextEpisode != null && !_nextTriggered) {
      _nextTriggered = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_disposed) _nextEpisode?.call();
      });
    }
    _refresh();
  }

  void _scheduleReconnect() {
    if (!_isAndroid ||
        !widget.reconnectEnabled ||
        _reconnectTimer?.isActive == true ||
        _userPaused ||
        _backgroundPaused ||
        _androidInBackground ||
        _reconnectCount >= widget.reconnectAttempts.clamp(0, 10)) {
      return;
    }
    final delay =
        (widget.reconnectDelaySeconds.clamp(1, 30) *
                (1 << _reconnectCount.clamp(0, 4)))
            .clamp(1, 30);
    _recovery ??= _captureRecovery();
    _reconnectTimer = Timer(Duration(seconds: delay), () {
      if (_disposed ||
          _userPaused ||
          _backgroundPaused ||
          _androidInBackground) {
        return;
      }
      _reconnectCount++;
      _scheduleOpen(recovery: _recovery);
    });
  }

  _RecoveryState? _captureRecovery() {
    final state = _player?.state;
    if (state == null) return null;
    return _RecoveryState(
      widget.isLive ? Duration.zero : state.position,
      state.rate,
      state.track.audio,
      state.track.subtitle,
      !_userPaused && !_backgroundPaused,
    );
  }

  void _retryNow() {
    final recovery = _recovery ?? _captureRecovery();
    _reconnectCount = 0;
    _reconnectTimer?.cancel();
    _userPaused = false;
    _scheduleOpen(recovery: recovery);
  }

  void _healthChanged() {
    if (_disposed) return;
    if (_health.failed) {
      _error = _playbackError;
      _opening = false;
      _scheduleReconnect();
    } else if (_health.hasProgress) {
      _error = null;
      _opening = false;
      _reconnectTimer?.cancel();
      _reconnectCount = 0;
      _recovery = null;
    }
    _refresh();
  }

  void _refresh() {
    if (_disposed || !mounted) return;
    _syncAndroidPower();
    setState(() {});
    _fullscreenEntry?.markNeedsBuild();
    if (_fullscreenRebuild != null) {
      if (SchedulerBinding.instance.schedulerPhase ==
          SchedulerPhase.persistentCallbacks) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!_disposed && _fullscreen) _fullscreenRebuild?.call(() {});
        });
      } else {
        _fullscreenRebuild?.call(() {});
      }
    }
  }

  void _chromeChanged() {
    final root = _fullscreen ? _fullscreenFocus : _focus;
    final restore =
        widget.television &&
        !_chrome.visible &&
        !_tvChannelsOpen &&
        root.hasFocus;
    _refresh();
    if (restore) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_disposed && !_tvChannelsOpen && !_chrome.visible) {
          root.requestFocus();
        }
      });
    }
  }

  @override
  void didUpdateWidget(covariant NovaPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fullscreenRequests != widget.fullscreenRequests) {
      oldWidget.fullscreenRequests?.removeListener(_externalFullscreen);
      widget.fullscreenRequests?.addListener(_externalFullscreen);
    }
    if (oldWidget.backRequests != widget.backRequests) {
      oldWidget.backRequests?.removeListener(_externalBack);
      widget.backRequests?.addListener(_externalBack);
    }
    final player = _player;
    if (player is AndroidSessionPlayer) player.isLive = widget.isLive;
    _tvMedia3?.isLive = widget.isLive;
    if (oldWidget.touchGestures != widget.touchGestures) {
      _touchGesturesOverride = null;
    }
    if (oldWidget.uri != widget.uri || oldWidget.isLive != widget.isLive) {
      _recovery = null;
      _reconnectCount = 0;
      _reconnectTimer?.cancel();
      _nextTriggered = false;
      _userPaused = false;
      _backgroundPaused = false;
      _scheduleOpen();
    } else if (oldWidget.initialRate != widget.initialRate) {
      unawaited(
        _perform(
          () => _player!.setRate(
            widget.isLive ? 1 : _validRate(widget.initialRate),
          ),
        ),
      );
    }
    _fullscreenEntry?.markNeedsBuild();
  }

  double _validRate(double rate) =>
      rate.isFinite ? rate.clamp(.25, 3).toDouble() : 1;

  void _scheduleOpen({_RecoveryState? recovery}) {
    final player = _player;
    if (player == null || _disposed) return;
    final generation = ++_generation;
    final uri = widget.uri;
    final live = widget.isLive;
    final requestedStart = recovery?.position ?? widget.start;
    final start = live || requestedStart.isNegative
        ? Duration.zero
        : requestedStart;
    final rate = live ? 1.0 : _validRate(recovery?.rate ?? widget.initialRate);
    final volume =
        _adjustments?.volume ??
        (widget.initialVolume.isFinite
            ? widget.initialVolume.clamp(0, 100).toDouble()
            : 80.0);
    _opening = true;
    _ended = false;
    _error = null;
    _controlError = null;
    _scrubPosition = null;
    _seeking.reset();
    _seekKey = null;
    _activeGeneration = -1;
    _lastProgressSecond = -1;
    _health.begin();
    bool current() => !_disposed && generation == _generation;

    // Serialize stop/open so a slow previous source cannot win a rapid zap.
    _operations = _operations
        .then((_) async {
          if (!current()) return;
          await player.stop();
          if (!current()) return;
          if (uri.trim().isEmpty) throw StateError('Empty media');
          _activeGeneration = generation;
          await player.setVolume(_isAndroid ? 100 : volume);
          if (_isAndroid && !live && player.platform is NativePlayer) {
            final native = player.platform as NativePlayer;
            // media_kit disables seek frame dropping by default. Let mpv catch
            // video up to the audio clock on constrained Android decoders.
            for (final entry in const {
              'video-sync': 'audio',
              'framedrop': 'vo',
              'hr-seek-framedrop': 'yes',
            }.entries) {
              try {
                await native.setProperty(entry.key, entry.value);
              } catch (_) {}
            }
          }
          if (!current()) return;
          // Disable auto/forced subtitle selection before the first decoded
          // frame, including when this player previously displayed subtitles.
          await player.setSubtitleTrack(SubtitleTrack.no());
          if (!current()) return;
          // A live stream is not seekable: do not send mpv a start=0 option.
          await player.open(
            Media(uri, start: live || start == Duration.zero ? null : start),
            play: false,
          );
          if (!current()) return;
          await player.setSubtitleTrack(SubtitleTrack.no());
          if (!current()) return;
          await player.setRate(rate);
          if (!current()) return;
          if (recovery != null) {
            try {
              await player.setAudioTrack(recovery.audio);
            } catch (_) {}
            try {
              await player.setSubtitleTrack(recovery.subtitle);
            } catch (_) {}
          }
          if (!current()) return;
          if (recovery?.playing ?? true) {
            if (_androidInBackground) {
              // A slow open can finish after Home while no playback existed
              // for the lifecycle observer to pause. Resume this same session
              // only when the application becomes visible again.
              _backgroundPaused = true;
              _health.setPaused(true);
            } else {
              await player.play();
            }
          } else {
            _health.setPaused(true);
          }
          if (!current()) return;
          _opening = false;
          _refresh();
        })
        .catchError((Object _, StackTrace _) {
          if (!current()) return;
          _health.fail();
        });
    _refresh();
  }

  Future<void> _perform(Future<void> Function() action) async {
    _chrome.activity();
    if (_disposed || _player == null || _opening) return;
    try {
      await action();
      if (_disposed) return;
      _controlError = null;
    } catch (_) {
      if (_disposed) return;
      _controlError = 'Cette commande n’a pas pu être appliquée.';
    }
    _refresh();
  }

  Future<void> _togglePlayback() async {
    final player = _player;
    if (player == null) return;
    final pause = player.state.playing;
    _userPaused = pause;
    if (pause) _reconnectTimer?.cancel();
    await _perform(() async {
      if (pause) {
        await player.pause();
      } else {
        await player.play();
      }
      _health.setPaused(pause);
      if (!pause && _health.failed) _scheduleReconnect();
    });
  }

  Future<void> _mediaCommand(MediaPlaybackCommand command) async {
    if (_disposed || _opening || _error != null || _player == null) return;
    _chrome.activity();
    final playing = _player!.state.playing;
    if (command == MediaPlaybackCommand.toggle ||
        (command == MediaPlaybackCommand.play && !playing) ||
        (command == MediaPlaybackCommand.pause && playing)) {
      await _togglePlayback();
    }
  }

  void _skip(int seconds) {
    final player = _player;
    if (player == null || widget.isLive || _opening || _error != null) return;
    final duration = player.state.duration;
    final target =
        (_seeking.target ?? player.state.position) + Duration(seconds: seconds);
    final bounded = Duration(
      milliseconds: target.inMilliseconds
          .clamp(0, duration.inMilliseconds > 0 ? duration.inMilliseconds : 0)
          .toInt(),
    );
    _seeking.request(bounded);
    _showHud('Position ${_clock(bounded)}');
  }

  void _toggleMute() {
    final player = _player;
    if (player == null) return;
    final volume = _adjustments?.volume ?? player.state.volume;
    if (volume > 0) _audibleVolume = volume;
    _setVolume(volume > 0 ? 0 : _audibleVolume);
  }

  void _setVolume(double value) {
    final controls = _adjustments;
    if (controls == null) return;
    if (value > 0) _audibleVolume = value.clamp(0, 100);
    unawaited(
      _perform(() async {
        await controls.setVolume(value);
        if (!_disposed) _showHud('Volume ${controls.volume.round()} %');
      }),
    );
  }

  void _setBrightness(int value) {
    final controls = _adjustments;
    if (controls == null) return;
    unawaited(
      _perform(() async {
        await controls.setBrightness(value);
        if (!_disposed) {
          _showHud(
            _isAndroid
                ? 'Luminosité ${controls.brightness} %'
                : 'Luminosité ${_brightnessLabel(controls.brightness)}',
          );
        }
      }),
    );
  }

  String _brightnessLabel(int value) => value > 0 ? '+$value' : '$value';

  void _showHud(String message) {
    _chrome.activity();
    _hud = message;
    _hudTimer?.cancel();
    _hudTimer = Timer(const Duration(milliseconds: 1100), () {
      if (_disposed) return;
      _hud = null;
      _refresh();
    });
    _refresh();
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (_isAndroid && _touchLocked) return;
    if (event is! PointerScrollEvent ||
        event.scrollDelta.dy == 0 ||
        _player == null ||
        _opening ||
        _error != null) {
      return;
    }
    GestureBinding.instance.pointerSignalResolver.register(event, (_) {
      final current = _adjustments?.volume ?? _player!.state.volume;
      _setVolume(current - event.scrollDelta.dy / 24);
    });
  }

  Future<void> _toggleFullscreen() async {
    if (_fullscreenBusy || _disposed) return;
    _fullscreenBusy = true;
    _chrome.dismissMenus();
    _chrome.activity();
    try {
      if (_fullscreen) {
        await _leaveFullscreen();
      } else {
        if (_isAndroid) {
          await _android.setFullscreen(
            true,
            landscape: widget.landscapeFullscreen,
          );
        } else {
          await _desktop.setFullscreen(true);
        }
        if (_disposed || !mounted) {
          if (_isAndroid) {
            await _android.setFullscreen(
              false,
              landscape: widget.landscapeFullscreen,
            );
          } else {
            await _desktop.setFullscreen(false);
          }
          return;
        }
        _enterFullscreenOverlay();
      }
    } catch (_) {
      if (!_disposed) {
        _controlError = 'Le plein écran n’est pas disponible pour le moment.';
        _refresh();
      }
    } finally {
      _fullscreenBusy = false;
    }
  }

  Future<void> _leaveFullscreen() async {
    _removeFullscreenOverlay();
    if (_isAndroid) {
      await _android.setFullscreen(
        false,
        landscape: widget.landscapeFullscreen,
      );
    } else {
      await _desktop.setFullscreen(false);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_disposed) _focus.requestFocus();
    });
  }

  void _enterFullscreenOverlay() {
    if (_fullscreen || _disposed || !mounted) return;
    final overlay = Overlay.of(context, rootOverlay: true);
    _fullscreen = true;
    widget.onFullscreenChanged?.call(true);
    _fullscreenEntry = OverlayEntry(
      builder: (_) => Positioned.fill(
        child: Navigator(
          key: _fullscreenNavigatorKey,
          onGenerateRoute: (_) => PageRouteBuilder<void>(
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
            pageBuilder: (_, _, _) => Material(
              color: Colors.black,
              child: SafeArea(
                child: StatefulBuilder(
                  builder: (_, update) {
                    _fullscreenRebuild = update;
                    return _buildSurface();
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
    _refresh();
    overlay.insert(_fullscreenEntry!);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_disposed) _fullscreenFocus.requestFocus();
    });
  }

  void _removeFullscreenOverlay() {
    _fullscreenRebuild = null;
    _fullscreenEntry?.remove();
    _fullscreenEntry?.dispose();
    _fullscreenEntry = null;
    _fullscreen = false;
    widget.onFullscreenChanged?.call(false);
    _refresh();
  }

  Future<void> _enterPip() async {
    if (!_isAndroid || !_pipSupported || !widget.pictureInPicture || _opening) {
      return;
    }
    try {
      final entered = await _android.enterPip();
      if (!entered && !_disposed) _showHud('Le mode fenêtré est indisponible.');
    } catch (_) {
      if (!_disposed) _showHud('Le mode fenêtré est indisponible.');
    }
  }

  void _verticalStart(Offset position, Size size) {
    _verticalLeft = position.dx < size.width / 2;
    _verticalDistance = 0;
    _verticalBase = _verticalLeft
        ? (_adjustments?.brightness ?? 50).toDouble()
        : (_adjustments?.volume ?? 70);
  }

  void _verticalUpdate(Offset delta, Size size) {
    if (!_isAndroid ||
        !_gesturesEnabled ||
        _touchLocked ||
        _inPip ||
        size.height <= 0 ||
        delta.dy == 0) {
      return;
    }
    _verticalDistance -= delta.dy;
    final value = (_verticalBase + _verticalDistance / size.height * 100)
        .clamp(0, 100)
        .toDouble();
    if (_verticalLeft && widget.brightnessGestures) {
      _setBrightness(value.round());
    }
    if (!_verticalLeft && widget.volumeGestures) _setVolume(value);
  }

  void _touchScaleStart(ScaleStartDetails details, Size size) {
    _scalingWithTwoFingers |= details.pointerCount != 1;
    _verticalStart(details.localFocalPoint, size);
  }

  void _touchScaleUpdate(ScaleUpdateDetails details, Size size) {
    if (!_gesturesEnabled || _touchLocked || _inPip) return;
    if (details.pointerCount != 1) {
      _scalingWithTwoFingers = true;
      if (!_pinchApplied && (details.scale > 1.12 || details.scale < .88)) {
        _pinchApplied = true;
        _fit = details.scale > 1 ? BoxFit.cover : BoxFit.contain;
        _showHud(_fit == BoxFit.cover ? 'Remplir l’écran' : 'Image entière');
      }
      return;
    }
    // Lifting one finger after a pinch must not change volume or brightness.
    if (_scalingWithTwoFingers) return;
    _verticalUpdate(details.focalPointDelta, size);
  }

  void _doubleTap(Size size) {
    if (_isAndroid) {
      if (_touchLocked ||
          !_gesturesEnabled ||
          !widget.seekGestures ||
          widget.isLive) {
        return;
      }
      final seconds = _doubleTapPosition.dx < size.width / 2 ? -10 : 10;
      _skip(seconds);
      _showHud(seconds < 0 ? '−10 secondes' : '+10 secondes');
    } else {
      unawaited(_toggleFullscreen());
    }
  }

  void _toggleTouchLock() {
    if (!_isAndroid) return;
    _touchLocked = !_touchLocked;
    _chrome.activity();
    _showHud(
      _touchLocked ? 'Commandes verrouillées' : 'Commandes déverrouillées',
    );
    _refresh();
  }

  Future<void> _close() async {
    if (_fullscreen) await _toggleFullscreen();
    if (_disposed || !mounted) return;
    final player = _player;
    if (player != null && !_opening && !widget.isLive) {
      widget.onProgress?.call(player.state.position, player.state.duration);
    }
    widget.onClose?.call();
  }

  void _showTvControls() {
    _chrome.activity();
    _tvPauseFocus.requestFocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_disposed && !_tvChannelsOpen) _tvPauseFocus.requestFocus();
    });
    WidgetsBinding.instance.scheduleFrame();
  }

  void _closeChannels() {
    _tvChannelsOpen = false;
    _chrome.hide();
    _refresh();
    (_fullscreen ? _fullscreenFocus : _focus).requestFocus();
  }

  void _openChannels() {
    if (!_fullscreen ||
        widget.channelChoices.isEmpty ||
        widget.onSelectChannel == null) {
      _showTvControls();
      return;
    }
    _tvChannelsOpen = true;
    _chrome.hide();
    _refresh();
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    final key = event.logicalKey;
    // Do not count Back as activity: doing so would reopen the HUD before
    // dismissing it on every press, preventing the user from leaving playback.
    if (widget.television && key == LogicalKeyboardKey.goBack) {
      if (event is KeyDownEvent) _externalBack();
      return KeyEventResult.handled;
    }
    if (event is KeyUpEvent && key == _seekKey) {
      _seekKey = null;
      _seekRepeats = 0;
      unawaited(_seeking.flush());
      return KeyEventResult.handled;
    }
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (_tvChannelsOpen) return KeyEventResult.ignored;
    final repeat = event is KeyRepeatEvent;
    final select =
        key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter;
    if (widget.television) {
      if (node.hasPrimaryFocus && select && widget.isLive && !repeat) {
        if (!_chrome.visible) {
          _openChannels();
        } else {
          _showTvControls();
        }
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.space || (node.hasPrimaryFocus && select)) {
        _chrome.activity();
        if (!repeat) unawaited(_togglePlayback());
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.contextMenu) {
        if (!repeat) {
          if (_chrome.visible) {
            _toggleInformation();
          } else {
            _showTvControls();
          }
        }
        return KeyEventResult.handled;
      }
      if (!widget.isLive &&
          node.hasPrimaryFocus &&
          (key == LogicalKeyboardKey.arrowDown ||
              key == LogicalKeyboardKey.arrowUp)) {
        _showTvControls();
        return KeyEventResult.handled;
      }
      if (widget.isLive &&
          (key == LogicalKeyboardKey.arrowUp ||
              key == LogicalKeyboardKey.arrowDown ||
              key == LogicalKeyboardKey.channelUp ||
              key == LogicalKeyboardKey.channelDown)) {
        if (!repeat) {
          (key == LogicalKeyboardKey.arrowUp ||
                      key == LogicalKeyboardKey.channelUp
                  ? widget.onNextChannel
                  : widget.onPreviousChannel)
              ?.call();
        }
        return KeyEventResult.handled;
      }
      if (widget.isLive &&
          (key == LogicalKeyboardKey.arrowRight ||
              key == LogicalKeyboardKey.arrowLeft)) {
        if (node.hasPrimaryFocus) {
          _showTvControls();
          return KeyEventResult.handled;
        }
        _chrome.activity();
        return KeyEventResult.ignored;
      }
    }
    final forward =
        key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.mediaFastForward;
    final backward =
        key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.mediaRewind;
    final mediaSeek =
        key == LogicalKeyboardKey.mediaFastForward ||
        key == LogicalKeyboardKey.mediaRewind;
    if (!widget.isLive &&
        (forward || backward) &&
        (!widget.television || node.hasPrimaryFocus || mediaSeek)) {
      _chrome.activity();
      if (_seekKey != key || !repeat) {
        _seekKey = key;
        _seekRepeats = 0;
      }
      if (repeat) _seekRepeats++;
      final step = _seekRepeats >= 18
          ? 60
          : _seekRepeats >= 6
          ? 30
          : 10;
      _skip(forward ? step : -step);
      return KeyEventResult.handled;
    }
    if (repeat) return KeyEventResult.ignored;
    _chrome.activity();
    if (key == LogicalKeyboardKey.escape &&
        (_fullscreen || _desktop.isFullscreen || widget.onClose != null)) {
      if (_fullscreen) {
        unawaited(_toggleFullscreen());
      } else if (_desktop.isFullscreen) {
        unawaited(_desktop.setFullscreen(false));
      } else {
        unawaited(_close());
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.space) {
      unawaited(_togglePlayback());
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyF) {
      unawaited(_toggleFullscreen());
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  void dispose() {
    widget.fullscreenRequests?.removeListener(_externalFullscreen);
    widget.backRequests?.removeListener(_externalBack);
    _disposed = true;
    Future<void>? androidRelease;
    if (_isAndroid) {
      WidgetsBinding.instance.removeObserver(this);
      androidRelease = _releaseAndroid();
    } else {
      if (widget.backendFactory == null) windowManager.removeListener(this);
      _desktop.unregisterPlayer(this);
    }
    if (!_isAndroid || widget.television) {
      DesktopMediaControls.instance.unregister(this);
    }
    _seeking.dispose();
    _chrome.dispose();
    _tvPauseFocus.dispose();
    _hudTimer?.cancel();
    _reconnectTimer?.cancel();
    _backgroundTimer?.cancel();
    _adjustments?.dispose();
    _health.dispose();
    ++_generation;
    _fullscreenEntry?.remove();
    _fullscreenEntry?.dispose();
    _fullscreenEntry = null;
    if (_fullscreen && !_isAndroid) {
      unawaited(_desktop.setFullscreen(false).catchError((Object _) {}));
    }
    _focus.dispose();
    _fullscreenFocus.dispose();
    unawaited(_release(androidRelease));
    super.dispose();
  }

  Future<void> _releaseAndroid() async {
    Future<void> ignoreFailure(Future<void> operation) =>
        operation.catchError((Object _) {});
    await Future.wait([
      ignoreFailure(_android.setKeepScreenOn(false)),
      ignoreFailure(_android.setPlaybackActive(false)),
      ignoreFailure(_android.setPipEnabled(false)),
      ignoreFailure(_android.setBrightness(-1)),
      if (_fullscreen)
        ignoreFailure(
          _android.setFullscreen(false, landscape: widget.landscapeFullscreen),
        ),
    ]);
  }

  Future<void> _release(Future<void>? androidRelease) async {
    try {
      for (final subscription in _subscriptions) {
        await subscription.cancel();
      }
      await _operations;
      await _adjustments?.flush();
    } catch (_) {
      // Resource release must never expose native messages or stream locators.
    } finally {
      try {
        await _player?.dispose();
      } catch (_) {}
      try {
        await androidRelease;
      } catch (_) {}
      widget.onReleased?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final surface = _fullscreen
        ? const ColoredBox(color: Colors.black)
        : _buildSurface();
    if (!_isAndroid || !widget.handleBackInternally) return surface;
    return PopScope(
      canPop:
          !_tvChannelsOpen &&
          !_fullscreen &&
          !_touchLocked &&
          !(widget.television && _chrome.visible),
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_tvChannelsOpen) {
          _closeChannels();
        } else if (_fullscreenNavigatorKey.currentState?.canPop() == true) {
          _fullscreenNavigatorKey.currentState?.pop();
        } else if (widget.television && _chrome.visible) {
          _chrome.hide();
          (_fullscreen ? _fullscreenFocus : _focus).requestFocus();
        } else if (_touchLocked) {
          _toggleTouchLock();
        } else if (_fullscreen) {
          unawaited(_toggleFullscreen());
        }
      },
      child: surface,
    );
  }

  Widget _buildSurface() =>
      LayoutBuilder(builder: (context, bounds) => _buildBoundedSurface(bounds));

  Widget _buildBoundedSurface(BoxConstraints surfaceBounds) {
    final player = _player;
    final controller = _controller;
    final state = player?.state;
    final focus = _fullscreen ? _fullscreenFocus : _focus;
    return Focus(
      focusNode: focus,
      autofocus:
          !widget.television ||
          _fullscreen ||
          (widget.onClose != null && !widget.isLive),
      onKeyEvent: _handleKey,
      child: MouseRegion(
        cursor: _chrome.visible ? MouseCursor.defer : SystemMouseCursors.none,
        onEnter: (_) => _chrome.pointerEnter(),
        onHover: (_) => _chrome.pointerEnter(),
        onExit: (_) => _chrome.pointerExit(),
        child: Listener(
          onPointerDown: (event) {
            if (!_isAndroid) _chrome.activity();
            if (_touchPointers.isEmpty) {
              _scalingWithTwoFingers = false;
              _pinchApplied = false;
            }
            _touchPointers.add(event.pointer);
            if (_touchPointers.length > 1) _scalingWithTwoFingers = true;
          },
          onPointerPanZoomStart: (_) {
            _scalingWithTwoFingers = true;
            _pinchApplied = false;
          },
          onPointerUp: (event) => _touchPointers.remove(event.pointer),
          onPointerCancel: (event) => _touchPointers.remove(event.pointer),
          onPointerMove: (_) {
            if (!_isAndroid) _chrome.activity();
          },
          onPointerSignal: _onPointerSignal,
          child: ColoredBox(
            color: Colors.black,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (_tvMedia3 case final nativeTv?)
                  TvMedia3Surface(key: _videoKey, player: nativeTv, fit: _fit)
                else if (controller != null)
                  LayoutBuilder(
                    builder: (context, bounds) => Video(
                      key: _videoKey,
                      controller: controller,
                      wakelock: !_isAndroid,
                      pauseUponEnteringBackgroundMode: !_isAndroid,
                      resumeUponEnteringForegroundMode: !_isAndroid,
                      controls: NoVideoControls,
                      fit: _fit,
                      subtitleViewConfiguration: SubtitleViewConfiguration(
                        textScaler: TextScaler.noScaling,
                        padding: EdgeInsets.fromLTRB(
                          14,
                          0,
                          14,
                          (_inPip
                                  ? 4.0
                                  : (_isAndroid && !_chrome.visible
                                        ? 18.0
                                        : widget.isLive
                                        ? 84.0
                                        : 130.0))
                              .clamp(0, bounds.maxHeight * .48),
                        ),
                        style: TextStyle(
                          fontFamily: 'Segoe UI',
                          fontSize: _inPip
                              ? 11
                              : bounds.maxWidth < 600
                              ? 14
                              : bounds.maxWidth < 1200
                              ? 22
                              : 26,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          backgroundColor: Colors.black54,
                          shadows: const [
                            Shadow(blurRadius: 3, color: Colors.black),
                          ],
                        ),
                      ),
                    ),
                  ),
                // Fullscreen gestures only cover the picture. Wrapping the
                // controls made each click wait for a possible double tap.
                Positioned.fill(
                  child: LayoutBuilder(
                    builder: (context, bounds) => GestureDetector(
                      key: const ValueKey('player-touch-surface'),
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        focus.requestFocus();
                        if (_isAndroid) _chrome.toggle();
                      },
                      onDoubleTapDown:
                          !_isAndroid ||
                              (_gesturesEnabled &&
                                  widget.seekGestures &&
                                  !widget.isLive &&
                                  !_touchLocked)
                          ? (details) =>
                                _doubleTapPosition = details.localPosition
                          : null,
                      onDoubleTap:
                          !_isAndroid ||
                              (_gesturesEnabled &&
                                  widget.seekGestures &&
                                  !widget.isLive &&
                                  !_touchLocked)
                          ? () => _doubleTap(bounds.biggest)
                          : null,
                      onScaleStart: _gesturesEnabled && !_touchLocked
                          ? (details) =>
                                _touchScaleStart(details, bounds.biggest)
                          : null,
                      onScaleUpdate: _gesturesEnabled && !_touchLocked
                          ? (details) =>
                                _touchScaleUpdate(details, bounds.biggest)
                          : null,
                    ),
                  ),
                ),
                if (_error == null && (_opening || (state?.buffering ?? false)))
                  const Center(
                    child: CircularProgressIndicator(strokeWidth: 3),
                  ),
                if (_error != null && !_inPip && !_touchLocked) _errorPanel(),
                if (!_inPip && !_touchLocked && _error == null && !_opening)
                  Positioned.fill(
                    child: Center(
                      child: _chromeView(
                        'player-center-playback',
                        IconButton.filled(
                          key: const ValueKey('player-center-playback-button'),
                          tooltip: state?.playing == true
                              ? 'Mettre en pause'
                              : 'Reprendre la lecture',
                          onPressed: () {
                            _chrome.activity();
                            unawaited(_togglePlayback());
                          },
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.black54,
                            foregroundColor: Colors.white,
                            fixedSize: const Size(64, 64),
                          ),
                          iconSize: 40,
                          icon: Icon(
                            state?.playing == true
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                          ),
                        ),
                      ),
                    ),
                  ),
                if (_hud != null && _chrome.visible && !_inPip)
                  Positioned(
                    top: 78,
                    left: 0,
                    right: 0,
                    child: IgnorePointer(
                      child: Center(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            child: Text(
                              _hud!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  left: 0,
                  top: 0,
                  right: 0,
                  child: _chromeView('player-header', _header()),
                ),
                if (_isAndroid && _touchLocked && !_inPip)
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _chrome.toggle,
                    ),
                  ),
                if (_isAndroid && _touchLocked && !_inPip && _chrome.visible)
                  Positioned(
                    right: 14,
                    top: 14,
                    child: FilledButton.icon(
                      onPressed: _toggleTouchLock,
                      icon: const Icon(Icons.lock_open_rounded),
                      label: const Text('Déverrouiller'),
                    ),
                  ),
                if (_showInfo && state != null)
                  Positioned(
                    top: 64,
                    left: 16,
                    right: 16,
                    child: _chromeView('player-info', _information(state)),
                  ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _chromeView(
                    'player-controls',
                    LayoutBuilder(
                      builder: (context, bounds) => Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (widget.isLive &&
                              widget.liveGuideBuilder != null &&
                              surfaceBounds.maxHeight >= 140)
                            ColoredBox(
                              color: const Color(0xB3000000),
                              child: SizedBox(
                                width: double.infinity,
                                child: widget.liveGuideBuilder!(
                                  surfaceBounds.maxHeight < 240,
                                ),
                              ),
                            ),
                          _controls(state),
                        ],
                      ),
                    ),
                  ),
                ),
                if (_tvChannelsOpen)
                  Positioned.fill(
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: GestureDetector(
                            onTap: _closeChannels,
                            child: const ColoredBox(color: Colors.black38),
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: SizedBox(
                            width: (MediaQuery.sizeOf(context).width * .48)
                                .clamp(220.0, 440.0),
                            height: double.infinity,
                            child: TvChannelPanel(
                              channels: widget.channelChoices,
                              selectedId: widget.selectedChannelId,
                              onClose: _closeChannels,
                              onSelected: (id) {
                                widget.onSelectChannel?.call(id);
                                _closeChannels();
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void onWindowBlur() => _chrome.focusLost();
  @override
  void onWindowFocus() => _chrome.focusGained();

  Widget _chromeView(String name, Widget child) => ExcludeFocus(
    excluding: widget.television && (!_chrome.visible || _inPip),
    child: ExcludeSemantics(
      excluding: !_chrome.visible || _inPip || _touchLocked,
      child: IgnorePointer(
        ignoring: !_chrome.visible || _inPip || _touchLocked,
        child: AnimatedOpacity(
          key: ValueKey(name),
          opacity: _chrome.visible && !_inPip && !_touchLocked ? 1 : 0,
          duration: const Duration(milliseconds: 120),
          child: child,
        ),
      ),
    ),
  );

  Widget _header() => LayoutBuilder(
    builder: (context, bounds) => Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xD9000000), Color(0x00000000)],
        ),
      ),
      child: Row(
        children: [
          if (widget.isLive) ...[
            const Icon(Icons.circle, color: Color(0xFFFF5674), size: 9),
            const SizedBox(width: 7),
            if (!_isAndroid || bounds.maxWidth >= 300)
              const Text(
                'DIRECT',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                ),
              ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Text(
              widget.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (!_isAndroid) _brightnessControls(),
          if (_isAndroid && !widget.television && bounds.maxWidth >= 260)
            _androidBrightnessMenu(),
          if (_isAndroid && !widget.television)
            _icon(
              Icons.lock_open_rounded,
              'Verrouiller les commandes tactiles',
              _toggleTouchLock,
            ),
          if (widget.television)
            _icon(
              Icons.info_outline_rounded,
              'Informations du flux (Menu)',
              _toggleInformation,
            ),
          if (widget.onClose != null)
            _icon(
              Icons.close_rounded,
              'Fermer le lecteur',
              () => unawaited(_close()),
            ),
        ],
      ),
    ),
  );

  Widget _brightnessControls() {
    final value = _adjustments?.brightness ?? 0;
    final ready = !_opening && _error == null && _adjustments != null;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _icon(
          Icons.brightness_low_rounded,
          'Diminuer la luminosité',
          ready && value > -100 ? () => _setBrightness(value - 5) : null,
        ),
        Tooltip(
          message: 'Réinitialiser la luminosité',
          child: TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Colors.white70,
              padding: const EdgeInsets.symmetric(horizontal: 3),
              minimumSize: const Size(28, 30),
            ),
            onPressed: ready && value != 0 ? () => _setBrightness(0) : null,
            child: Text(
              _brightnessLabel(value),
              style: const TextStyle(fontSize: 10),
            ),
          ),
        ),
        _icon(
          Icons.brightness_high_rounded,
          'Augmenter la luminosité',
          ready && value < 100 ? () => _setBrightness(value + 5) : null,
        ),
      ],
    );
  }

  Widget _errorPanel() => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 45),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: Colors.white70,
            size: 30,
          ),
          const SizedBox(height: 12),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          if (_reconnectTimer?.isActive == true) ...[
            const SizedBox(height: 8),
            Text(
              'Reconnexion ${_reconnectCount + 1}/${widget.reconnectAttempts.clamp(0, 10)}…',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
          if (_player != null) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _retryNow,
              icon: const Icon(Icons.refresh_rounded, size: 17),
              label: const Text('Réessayer'),
            ),
          ],
        ],
      ),
    ),
  );

  Widget _controls(PlayerState? state) {
    if (widget.television) return _tvControls(state);
    final duration = state?.duration ?? Duration.zero;
    final position = _seeking.target ?? state?.position ?? Duration.zero;
    final volume =
        (_adjustments?.volume ?? state?.volume ?? widget.initialVolume)
            .clamp(0, 100)
            .toDouble();
    final ready = !_opening && state != null && _error == null;
    final canSeek = ready && !widget.isLive && duration.inMilliseconds > 0;
    final sliderMax = duration.inMilliseconds > 0
        ? duration.inMilliseconds.toDouble()
        : 1.0;
    final sliderValue = (_scrubPosition ?? position.inMilliseconds.toDouble())
        .clamp(0.0, sliderMax)
        .toDouble();
    final audio =
        state?.tracks.audio
            .where((track) => track.id != 'auto' && track.id != 'no')
            .toList() ??
        <AudioTrack>[];
    final allSubtitles =
        state?.tracks.subtitle
            .where((track) => track.id != 'auto' && track.id != 'no')
            .toList() ??
        <SubtitleTrack>[];
    final subtitles = allSubtitles
        .where((track) => !_isBitmapSubtitle(track))
        .toList();
    final bitmapSubtitles = allSubtitles.any(_isBitmapSubtitle);
    return Container(
      padding: EdgeInsets.fromLTRB(
        8,
        _isAndroid && widget.isLive ? 10 : 28,
        8,
        4,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x00000000), Color(0xE6000000)],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_controlError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                _controlError!,
                style: const TextStyle(color: Color(0xFFFFC18A), fontSize: 12),
              ),
            ),
          if (!widget.isLive)
            Row(
              children: [
                Text(
                  _clock(Duration(milliseconds: sliderValue.toInt())),
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
                Expanded(
                  child: Slider(
                    min: 0,
                    max: sliderMax,
                    value: sliderValue,
                    onChanged: canSeek
                        ? (value) {
                            _scrubPosition = value;
                            _refresh();
                          }
                        : null,
                    onChangeEnd: canSeek
                        ? (value) {
                            _scrubPosition = null;
                            _seeking.request(
                              Duration(milliseconds: value.round()),
                            );
                            unawaited(_seeking.flush());
                          }
                        : null,
                  ),
                ),
                Text(
                  _clock(duration),
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          LayoutBuilder(
            builder: (context, constraints) {
              if (_isAndroid && widget.isLive && constraints.maxWidth < 600) {
                return Row(
                  children: [
                    _icon(
                      state?.playing == true
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      state?.playing == true
                          ? 'Pause (Espace)'
                          : 'Lecture (Espace)',
                      ready ? () => unawaited(_togglePlayback()) : null,
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _icon(
                              volume == 0
                                  ? Icons.volume_off_rounded
                                  : Icons.volume_up_rounded,
                              volume == 0 ? 'Rétablir le son' : 'Couper le son',
                              ready ? _toggleMute : null,
                            ),
                            if (audio.isNotEmpty)
                              _audioMenu(audio, state!, ready),
                            _subtitleMenu(
                              subtitles,
                              state,
                              ready,
                              bitmapAvailable: bitmapSubtitles,
                            ),
                            _compactOptionsMenu(),
                          ],
                        ),
                      ),
                    ),
                    _icon(
                      _fullscreen
                          ? Icons.fullscreen_exit_rounded
                          : Icons.fullscreen_rounded,
                      _fullscreen
                          ? 'Quitter le plein écran (Échap)'
                          : 'Plein écran',
                      () => unawaited(_toggleFullscreen()),
                    ),
                  ],
                );
              }
              return Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 2,
                runSpacing: 2,
                children: [
                  _icon(
                    state?.playing == true
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    state?.playing == true
                        ? 'Pause (Espace)'
                        : 'Lecture (Espace)',
                    ready ? () => unawaited(_togglePlayback()) : null,
                  ),
                  if (_showEpisodeNavigation) ...[
                    _icon(
                      Icons.skip_previous_rounded,
                      'Épisode précédent',
                      widget.onPreviousEpisode,
                    ),
                    _icon(
                      Icons.skip_next_rounded,
                      'Épisode suivant',
                      _nextEpisode,
                    ),
                  ],
                  if (!widget.isLive &&
                      (!_isAndroid || constraints.maxWidth >= 600)) ...[
                    _icon(
                      Icons.replay_10_rounded,
                      'Reculer de 10 secondes',
                      canSeek ? () => _skip(-10) : null,
                    ),
                    _icon(
                      Icons.forward_10_rounded,
                      'Avancer de 10 secondes',
                      canSeek ? () => _skip(10) : null,
                    ),
                  ],
                  _icon(
                    volume == 0
                        ? Icons.volume_off_rounded
                        : Icons.volume_up_rounded,
                    volume == 0 ? 'Rétablir le son' : 'Couper le son',
                    ready ? _toggleMute : null,
                  ),
                  if (constraints.maxWidth >= 600)
                    SizedBox(
                      width: 90,
                      child: Slider(
                        value: volume,
                        min: 0,
                        max: 100,
                        onChanged: ready
                            ? (value) {
                                _setVolume(value);
                              }
                            : null,
                      ),
                    ),
                  if (!widget.isLive) _speedMenu(state, ready),
                  if (audio.isNotEmpty) _audioMenu(audio, state!, ready),
                  _subtitleMenu(
                    subtitles,
                    state,
                    ready,
                    bitmapAvailable: bitmapSubtitles,
                  ),
                  if (constraints.maxWidth >= 600) _aspectMenu(),
                  if (constraints.maxWidth < 600) _compactOptionsMenu(),
                  if (_isAndroid &&
                      _pipSupported &&
                      widget.pictureInPicture &&
                      constraints.maxWidth >= 600)
                    _icon(
                      Icons.picture_in_picture_alt_rounded,
                      'Lecture dans une fenêtre flottante',
                      ready ? () => unawaited(_enterPip()) : null,
                    ),
                  if (constraints.maxWidth >= 600)
                    _icon(
                      Icons.info_outline_rounded,
                      'Informations du flux',
                      () {
                        _showInfo = !_showInfo;
                        _refresh();
                      },
                    ),
                  _icon(
                    _fullscreen
                        ? Icons.fullscreen_exit_rounded
                        : Icons.fullscreen_rounded,
                    _fullscreen
                        ? 'Quitter le plein écran (Échap)'
                        : _isAndroid
                        ? 'Plein écran'
                        : 'Plein écran (double-clic)',
                    () => unawaited(_toggleFullscreen()),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _tvControls(PlayerState? state) {
    final ready = !_opening && state != null && _error == null;
    final duration = state?.duration ?? Duration.zero;
    final position = _seeking.target ?? state?.position ?? Duration.zero;
    final audio =
        state?.tracks.audio
            .where((t) => t.id != 'auto' && t.id != 'no')
            .toList() ??
        <AudioTrack>[];
    final subtitles =
        state?.tracks.subtitle
            .where(
              (t) =>
                  t.id != 'auto' &&
                  t.id != 'no' &&
                  (_tvMedia3 != null || !_isBitmapSubtitle(t)),
            )
            .toList() ??
        <SubtitleTrack>[];
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Color(0xee000000)],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!widget.isLive)
            Row(
              children: [
                Text(_clock(position)),
                Expanded(
                  child: Slider(
                    min: 0,
                    max: duration.inMilliseconds > 0
                        ? duration.inMilliseconds.toDouble()
                        : 1,
                    value: position.inMilliseconds.toDouble().clamp(
                      0,
                      duration.inMilliseconds > 0
                          ? duration.inMilliseconds.toDouble()
                          : 1,
                    ),
                    onChanged: ready && duration.inMilliseconds > 0
                        ? (value) {
                            _chrome.activity();
                            _seeking.request(
                              Duration(milliseconds: value.round()),
                            );
                          }
                        : null,
                    onChangeEnd: ready && duration.inMilliseconds > 0
                        ? (_) => unawaited(_seeking.flush())
                        : null,
                  ),
                ),
                Text(_clock(duration)),
              ],
            ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                if (widget.isLive)
                  _icon(
                    Icons.refresh_rounded,
                    'Réactualiser la chaîne',
                    _opening ? null : _retryNow,
                  ),
                IconButton(
                  focusNode: _tvPauseFocus,
                  tooltip: state?.playing == true ? 'Pause' : 'Lecture',
                  onPressed: ready ? () => unawaited(_togglePlayback()) : null,
                  icon: Icon(
                    state?.playing == true
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                  ),
                ),
                if (_showEpisodeNavigation) ...[
                  _icon(
                    Icons.skip_previous,
                    'Épisode précédent',
                    widget.onPreviousEpisode,
                  ),
                  _icon(Icons.skip_next, 'Épisode suivant', _nextEpisode),
                ],
                if (!widget.isLive) _speedMenu(state, ready),
                if (!widget.isLive && state != null && audio.isNotEmpty)
                  _audioMenu(audio, state, ready),
                if (!widget.isLive) _subtitleMenu(subtitles, state, ready),
                _aspectMenu(),
                _icon(
                  _fullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
                  _fullscreen ? 'Quitter le plein écran' : 'Plein écran',
                  () => unawaited(_toggleFullscreen()),
                ),
                if (!widget.isLive && widget.onClose != null)
                  _icon(
                    Icons.close,
                    'Retour au catalogue',
                    () => unawaited(_close()),
                  ),
              ],
            ),
          ),
          Text(
            widget.isLive
                ? '↑ ↓ Chaînes · ← → Réglages · OK sans commandes : liste des chaînes'
                : 'OK : lecture / pause · Bas : réglages · Maintenir ← → : avance rapide',
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _speedMenu(PlayerState? state, bool enabled) =>
      PopupMenuButton<double>(
        onOpened: _chrome.menuOpened,
        onCanceled: _chrome.menuClosed,
        popUpAnimationStyle: AnimationStyle.noAnimation,
        tooltip: 'Vitesse de lecture',
        enabled: enabled,
        initialValue: state?.rate ?? 1,
        onSelected: (rate) {
          _chrome.menuClosed();
          unawaited(_perform(() => _player!.setRate(rate)));
        },
        itemBuilder: (_) => _rates
            .map(
              (rate) => CheckedPopupMenuItem<double>(
                value: rate,
                checked: ((state?.rate ?? 1) - rate).abs() < .001,
                child: Text(
                  '${_rateLabel(rate)}×${rate == 1 ? ' · Normale' : ''}',
                ),
              ),
            )
            .toList(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          child: Text(
            '${_rateLabel(state?.rate ?? 1)}×',
            style: TextStyle(
              color: enabled ? Colors.white : Colors.white38,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );

  Widget _audioMenu(List<AudioTrack> tracks, PlayerState state, bool enabled) =>
      PopupMenuButton<AudioTrack>(
        onOpened: _chrome.menuOpened,
        onCanceled: _chrome.menuClosed,
        popUpAnimationStyle: AnimationStyle.noAnimation,
        tooltip: 'Langue audio',
        enabled: enabled,
        icon: const Icon(
          Icons.audiotrack_rounded,
          color: Colors.white,
          size: 21,
        ),
        onSelected: (track) {
          _chrome.menuClosed();
          unawaited(_perform(() => _player!.setAudioTrack(track)));
        },
        itemBuilder: (_) => [
          for (final track in [AudioTrack.auto(), ...tracks])
            CheckedPopupMenuItem<AudioTrack>(
              value: track,
              checked: state.track.audio.id == track.id,
              child: Text(
                _trackLabel(track.id, track.title, track.language, 'Audio'),
              ),
            ),
        ],
      );

  Widget _subtitleMenu(
    List<SubtitleTrack> tracks,
    PlayerState? state,
    bool enabled, {
    bool bitmapAvailable = false,
  }) => PopupMenuButton<Object>(
    onOpened: _chrome.menuOpened,
    onCanceled: _chrome.menuClosed,
    popUpAnimationStyle: AnimationStyle.noAnimation,
    tooltip: 'Sous-titres',
    enabled: enabled,
    icon: const Icon(Icons.subtitles_outlined, color: Colors.white, size: 21),
    onSelected: (selection) {
      _chrome.menuClosed();
      if (selection == _SubtitleAction.file) {
        _loadSubtitleFile();
      } else if (selection is SubtitleTrack) {
        unawaited(_perform(() => _player!.setSubtitleTrack(selection)));
      }
    },
    itemBuilder: (_) => [
      if (bitmapAvailable)
        const PopupMenuItem<Object>(
          enabled: false,
          child: Text('Pistes images DVB/PGS non prises en charge'),
        ),
      if (tracks.isEmpty)
        PopupMenuItem<Object>(
          enabled: false,
          child: Text(
            bitmapAvailable
                ? 'Aucune piste texte intégrée détectée'
                : 'Aucune piste intégrée détectée',
          ),
        ),
      for (final track in [SubtitleTrack.no(), SubtitleTrack.auto(), ...tracks])
        CheckedPopupMenuItem<Object>(
          value: track,
          checked: state?.track.subtitle.id == track.id,
          child: Text(
            _trackLabel(track.id, track.title, track.language, 'Sous-titres'),
          ),
        ),
      const PopupMenuDivider(),
      const PopupMenuItem<Object>(
        value: _SubtitleAction.file,
        child: Text('Charger un fichier de sous-titres…'),
      ),
    ],
  );

  bool _isBitmapSubtitle(SubtitleTrack track) => const {
    'dvd_subtitle',
    'dvb_subtitle',
    'hdmv_pgs_subtitle',
    'xsub',
    'dvdsub',
    'dvbsub',
    'pgssub',
    'vobsub',
    'pgs',
  }.contains(track.codec?.toLowerCase());

  Future<void> _loadSubtitleFile() async {
    final generation = _generation;
    try {
      final file = await openFile(
        acceptedTypeGroups: const [
          XTypeGroup(
            label: 'Sous-titres texte',
            extensions: ['srt', 'vtt', 'ass', 'ssa'],
          ),
        ],
      );
      if (file == null || _disposed || generation != _generation) return;
      final external = _isAndroid
          ? SubtitleTrack.data(await file.readAsString(), title: file.name)
          : SubtitleTrack.uri(Uri.file(file.path).toString(), title: file.name);
      if (_disposed || generation != _generation) return;
      await _perform(() => _player!.setSubtitleTrack(external));
    } catch (_) {
      if (!_disposed) {
        _controlError = 'Ce fichier de sous-titres n’a pas pu être chargé.';
        _refresh();
      }
    }
  }

  String _trackLabel(
    String id,
    String? title,
    String? language,
    String fallback,
  ) {
    if (id == 'auto') return 'Automatique';
    if (id == 'no') return 'Désactivés';
    final parts = <String>[
      if (language != null && language.isNotEmpty) language,
      if (title != null && title.isNotEmpty) title,
    ];
    return parts.isEmpty ? '$fallback · piste $id' : parts.join(' · ');
  }

  Widget _aspectMenu() => PopupMenuButton<BoxFit>(
    onOpened: _chrome.menuOpened,
    onCanceled: _chrome.menuClosed,
    popUpAnimationStyle: AnimationStyle.noAnimation,
    tooltip: 'Format de l’image',
    initialValue: _fit,
    icon: const Icon(Icons.aspect_ratio_rounded, color: Colors.white, size: 21),
    onSelected: (fit) {
      _chrome.menuClosed();
      _fit = fit;
      _refresh();
    },
    itemBuilder: (_) => [
      for (final entry in const {
        BoxFit.contain: 'Original · image entière',
        BoxFit.cover: 'Remplir · recadrage',
        BoxFit.fill: 'Étirer',
      }.entries)
        CheckedPopupMenuItem<BoxFit>(
          value: entry.key,
          checked: _fit == entry.key,
          child: Text(entry.value),
        ),
    ],
  );

  Widget _compactOptionsMenu() => PopupMenuButton<String>(
    onOpened: _chrome.menuOpened,
    onCanceled: _chrome.menuClosed,
    tooltip: 'Options du lecteur',
    popUpAnimationStyle: AnimationStyle.noAnimation,
    icon: const Icon(Icons.more_horiz_rounded, color: Colors.white, size: 21),
    onSelected: (value) {
      _chrome.menuClosed();
      if (value == 'touch') {
        _touchGesturesOverride = !_gesturesEnabled;
      } else if (value == 'brightness-up') {
        _setBrightness((_adjustments?.brightness ?? 50) + 10);
      } else if (value == 'brightness-down') {
        _setBrightness((_adjustments?.brightness ?? 50) - 10);
      } else if (value == 'pip') {
        unawaited(_enterPip());
      } else if (value == 'rewind') {
        _skip(-10);
      } else if (value == 'forward') {
        _skip(10);
      } else if (value == 'info') {
        _showInfo = !_showInfo;
      } else {
        _fit = {
          'contain': BoxFit.contain,
          'cover': BoxFit.cover,
          'fill': BoxFit.fill,
        }[value]!;
      }
      _refresh();
    },
    itemBuilder: (_) => [
      const PopupMenuItem(value: 'contain', child: Text('Image entière')),
      const PopupMenuItem(value: 'cover', child: Text('Remplir le cadre')),
      const PopupMenuItem(value: 'fill', child: Text('Étirer l’image')),
      const PopupMenuDivider(),
      const PopupMenuItem(value: 'info', child: Text('Informations du flux')),
      if (_isAndroid) ...[
        const PopupMenuItem(
          value: 'brightness-up',
          child: Text('Luminosité +'),
        ),
        const PopupMenuItem(
          value: 'brightness-down',
          child: Text('Luminosité −'),
        ),
      ],
      if (_isAndroid)
        CheckedPopupMenuItem(
          value: 'touch',
          checked: _gesturesEnabled,
          child: const Text('Gestes tactiles'),
        ),
      if (_isAndroid && !widget.isLive) ...[
        const PopupMenuItem(
          value: 'rewind',
          child: Text('Reculer de 10 secondes'),
        ),
        const PopupMenuItem(
          value: 'forward',
          child: Text('Avancer de 10 secondes'),
        ),
      ],
      if (_isAndroid && _pipSupported && widget.pictureInPicture)
        const PopupMenuItem(
          value: 'pip',
          child: Text('Lecture dans une fenêtre flottante'),
        ),
    ],
  );

  Widget _androidBrightnessMenu() => PopupMenuButton<int>(
    tooltip: 'Luminosité de l’écran',
    onOpened: _chrome.menuOpened,
    onCanceled: _chrome.menuClosed,
    popUpAnimationStyle: AnimationStyle.noAnimation,
    icon: const Icon(Icons.brightness_6_rounded, color: Colors.white, size: 21),
    onSelected: (value) {
      _chrome.menuClosed();
      if (value < 0) {
        _ignoreAndroid(() async {
          await _android.setBrightness(-1);
          final current = await _android.getBrightness();
          if (!_disposed) {
            _adjustments?.syncBrightness((current.clamp(.02, 1) * 100).round());
          }
        }());
      } else {
        _setBrightness(value);
      }
    },
    itemBuilder: (_) => [
      const PopupMenuItem(value: -1, child: Text('Réglage du téléphone')),
      for (final percent in [10, 25, 50, 75, 100])
        PopupMenuItem(value: percent, child: Text('$percent %')),
    ],
  );

  void _toggleInformation() {
    _showInfo = !_showInfo;
    _chrome.activity();
    _refresh();
  }

  Widget _information(PlayerState state) {
    final nativeTv = _tvMedia3;
    if (nativeTv != null) {
      return ValueListenableBuilder<TvPlaybackDiagnostics>(
        valueListenable: nativeTv.diagnostics,
        builder: (context, diagnostics, _) =>
            _informationBody(state, diagnostics),
      );
    }
    return _informationBody(state);
  }

  Widget _informationBody(
    PlayerState state, [
    TvPlaybackDiagnostics? diagnostics,
  ]) {
    final video = state.videoParams;
    final width = video.w ?? state.width;
    final height = video.h ?? state.height;
    final audio = state.track.audio;
    final lines = <String>[
      if (diagnostics != null) 'Lecteur : Media3 ${diagnostics.engineVersion}',
      if ((width ?? 0) > 0 && (height ?? 0) > 0)
        'Définition : $width × $height',
      if (diagnostics?.videoCodec case final codec?) 'Vidéo : $codec',
      if (diagnostics?.videoDecoder case final decoder?)
        'Décodeur vidéo : $decoder',
      if (video.pixelformat != null) 'Format vidéo : ${video.pixelformat}',
      if (video.hwPixelformat != null)
        'Format matériel : ${video.hwPixelformat}',
      if (video.primaries != null) 'Couleurs : ${video.primaries}',
      if (video.gamma != null) 'Transfert : ${video.gamma}',
      if (diagnostics?.audioCodec ?? audio.codec case final codec?)
        'Audio : $codec',
      if (diagnostics?.audioDecoder case final decoder?)
        'Décodeur audio : $decoder',
      if (diagnostics != null)
        'Première image : ${diagnostics.firstFrame ? 'reçue' : 'en attente'}',
      if (!widget.isLive) 'Vitesse : ${_rateLabel(state.rate)}×',
    ];
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xE61A1B24),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Text(
          lines.isEmpty
              ? 'Les informations du flux ne sont pas encore disponibles.'
              : lines.join('\n'),
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
            height: 1.6,
          ),
        ),
      ),
    );
  }

  Widget _icon(IconData icon, String tooltip, VoidCallback? onPressed) =>
      IconButton(
        onPressed: onPressed,
        tooltip: tooltip,
        icon: Icon(icon, size: 22),
        color: Colors.white,
        disabledColor: Colors.white30,
        constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
        padding: const EdgeInsets.all(7),
      );

  void _externalFullscreen() {
    if (_tvChannelsOpen) {
      _closeChannels();
      return;
    }
    if (widget.television &&
        _fullscreenNavigatorKey.currentState?.canPop() == true) {
      _fullscreenNavigatorKey.currentState!.pop();
      _chrome.activity();
      return;
    }
    if (mounted && !_disposed) unawaited(_toggleFullscreen());
  }

  void _externalBack() {
    if (!mounted || _disposed) return;
    if (_tvChannelsOpen) {
      _closeChannels();
    } else if (_fullscreenNavigatorKey.currentState?.canPop() == true) {
      _fullscreenNavigatorKey.currentState!.pop();
    } else if (_showInfo || _chrome.visible) {
      _showInfo = false;
      _chrome.hide();
      _refresh();
      (_fullscreen ? _fullscreenFocus : _focus).requestFocus();
    } else if (widget.onClose != null) {
      unawaited(_close());
    } else if (_fullscreen) {
      unawaited(_toggleFullscreen());
    }
  }

  String _rateLabel(double rate) => rate
      .toStringAsFixed(2)
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '')
      .replaceAll('.', ',');

  String _clock(Duration duration) {
    final seconds = duration.inSeconds < 0 ? 0 : duration.inSeconds;
    final hours = seconds ~/ 3600;
    final minutes = (seconds ~/ 60) % 60;
    final rest = seconds % 60;
    return '${hours > 0 ? '$hours:' : ''}'
        '${hours > 0 ? minutes.toString().padLeft(2, '0') : minutes}:'
        '${rest.toString().padLeft(2, '0')}';
  }
}

class _RecoveryState {
  const _RecoveryState(
    this.position,
    this.rate,
    this.audio,
    this.subtitle,
    this.playing,
  );
  final Duration position;
  final double rate;
  final AudioTrack audio;
  final SubtitleTrack subtitle;
  final bool playing;
}
