import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

/// Selects rendering once at application startup, never during fold/resize.
/// Android emulator guest EGL can fail to create mpv's GL context. Direct
/// MediaCodec Surface output also avoids GPU/decoder texture interop artifacts
/// on Fire TV. Phones and other TVs retain automatic hardware selection.
class AndroidVideoEnvironment {
  static const _channel = MethodChannel('nova/android');
  static bool _emulator = false;
  static bool _fireTv = false;
  static bool get isEmulator => _emulator;

  static Future<void> initialize({
    bool television = const bool.fromEnvironment('NOVA_TV'),
  }) async {
    try {
      _emulator = await _channel.invokeMethod<bool>('isEmulator') ?? false;
    } catch (_) {
      // A missing optional diagnostic must not prevent playback from starting.
      _emulator = false;
    }
    _fireTv = false;
    if (television) {
      try {
        _fireTv = await _channel.invokeMethod<bool>('isAmazonDevice') ?? false;
      } catch (_) {}
    }
  }

  static VideoControllerConfiguration get configuration => _emulator || _fireTv
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
