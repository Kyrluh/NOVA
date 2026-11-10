import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:nova_iptv/player/android_session_player.dart';
import 'package:nova_iptv/player/android_video_environment.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('nova/android');

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    await AndroidVideoEnvironment.initialize();
  });

  test('Emulator uses direct MediaCodec Surface output while phones retain automatic hardware selection', () async {
    var emulator = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'isEmulator');
          return emulator;
        });
    await AndroidVideoEnvironment.initialize();
    expect(AndroidVideoEnvironment.configuration.vo, 'mediacodec_embed');
    expect(AndroidVideoEnvironment.configuration.hwdec, 'mediacodec');
    emulator = false;
    await AndroidVideoEnvironment.initialize();
    expect(AndroidVideoEnvironment.configuration.vo, isNull);
    expect(AndroidVideoEnvironment.configuration.hwdec, isNull);
    expect(
      AndroidVideoEnvironment.configuration.enableHardwareAcceleration,
      isTrue,
    );
  });

  test(
    'Optional Android environment detection fails without blocking startup',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            channel,
            (_) async => throw MissingPluginException(),
          );
      await AndroidVideoEnvironment.initialize();
      expect(AndroidVideoEnvironment.isEmulator, isFalse);
      expect(AndroidVideoEnvironment.configuration.hwdec, isNull);
    },
  );

  test('Android live sessions reject all internal seeks and VOD sessions still seek', () async {
    final native = _SeekRecorder();
    final player = AndroidSessionPlayer(isLive: true, platformPlayer: native);
    await player.seek(Duration.zero);
    await player.seek(const Duration(seconds: 50));
    expect(native.seeks, isEmpty);
    player.isLive = false;
    await player.seek(const Duration(seconds: 50));
    expect(native.seeks, [const Duration(seconds: 50)]);
    player.isLive = true;
    await player.seek(const Duration(seconds: 80));
    expect(native.seeks, hasLength(1));
    await player.dispose();
  });
}

class _SeekRecorder extends PlatformPlayer {
  _SeekRecorder() : super(configuration: const PlayerConfiguration());
  final seeks = <Duration>[];
  @override
  Future<void> seek(Duration duration) async {
    seeks.add(duration);
  }
}
