import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

/// Selects rendering once at application startup, never during fold/resize.
/// Android emulator guest EGL can fail to create mpv's GL context. Direct
/// MediaCodec Surface output avoids that pipeline on emulators only; physical
/// devices retain media_kit's automatic hardware-decoder selection.
class AndroidVideoEnvironment {
  static const _channel = MethodChannel('nova/android');
  static bool _emulator = false;
  static bool get isEmulator => _emulator;

  static Future<void> initialize() async {
    try {
      _emulator = await _channel.invokeMethod<bool>('isEmulator') ?? false;
    } catch (_) {
      // A missing optional diagnostic must not prevent playback from starting.
      _emulator = false;
    }
  }

  static VideoControllerConfiguration get configuration => _emulator
      ? const VideoControllerConfiguration(
          vo: 'mediacodec_embed',
          hwdec: 'mediacodec',
          enableHardwareAcceleration: true,
        )
      : const VideoControllerConfiguration(enableHardwareAcceleration: true);
}

VideoController createNovaVideoController(Player player) => VideoController(
  player,
  configuration: AndroidVideoEnvironment.configuration,
);
