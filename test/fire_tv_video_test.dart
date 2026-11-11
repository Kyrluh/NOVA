import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_iptv/player/android_video_environment.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Direct output targets Fire TV and emulators while phones and other TVs retain automatic decoding', () async {
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
      expect(config.vo, scenario.direct ? 'mediacodec_embed' : null);
      expect(config.hwdec, scenario.direct ? 'mediacodec' : null);
      expect(config.enableHardwareAcceleration, isTrue);
    }
  });
}
