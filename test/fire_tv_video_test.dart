import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_iptv/player/android_video_environment.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Fire TV uses hardware copy-back while other devices keep their existing decoding', () async {
    const channel = MethodChannel('nova/android');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    for (final scenario in [
      (tv: true, amazon: true, emulator: false, direct: true),
      (tv: false, amazon: true, emulator: false, direct: false),
      (tv: true, amazon: false, emulator: false, direct: false),
      (tv: false, amazon: false, emulator: true, direct: true),
    ]) {
      messenger.setMockMethodCallHandler(
        channel,
        (call) async => switch (call.method) {
          'isEmulator' => scenario.emulator,
          'isAmazonDevice' => scenario.amazon,
          _ => null,
        },
      );
      await AndroidVideoEnvironment.initialize(television: scenario.tv);
      final config = AndroidVideoEnvironment.configuration;
      final fire = scenario.tv && scenario.amazon && !scenario.emulator;
      expect(
        config.vo,
        fire
            ? 'gpu'
            : scenario.direct
            ? 'mediacodec_embed'
            : null,
      );
      expect(
        config.hwdec,
        fire
            ? 'mediacodec-copy'
            : scenario.direct
            ? 'mediacodec'
            : null,
      );
      expect(config.enableHardwareAcceleration, isTrue);
    }
  });
}
