import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:nova_iptv/player/tv_media3_player.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('nova/tv_player');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<MethodCall> calls;
  setUp(() {
    calls = [];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });
  });
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  Future<void> event(Map<String, Object?> data) async {
    await messenger.handlePlatformMessage(
      channel.name,
      const StandardMethodCodec().encodeMethodCall(MethodCall('event', data)),
      (_) {},
    );
  }

  test(
    'TV native session keeps resume and ignores old channel events',
    () async {
      final native = TvMedia3Player();
      final player = Player(platformPlayer: native);
      await player.open(
        Media(
          'https://example.test/film.mp4',
          start: const Duration(seconds: 42),
        ),
        play: false,
      );
      final first = calls.lastWhere((c) => c.method == 'open').arguments as Map;
      expect(first['startMs'], 42000);
      await event({
        'id': native.id,
        'generation': first['generation'],
        'type': 'state',
        'playing': true,
        'positionMs': 43000,
        'durationMs': 120000,
        'width': 1920,
        'height': 1080,
      });
      expect(player.state.position.inSeconds, 43);
      expect(player.state.width, 1920);
      await player.open(Media('https://example.test/another.mp4'), play: false);
      await event({
        'id': native.id,
        'generation': first['generation'],
        'type': 'state',
        'completed': true,
        'positionMs': 119000,
      });
      expect(player.state.completed, isFalse);
      expect(player.state.position, Duration.zero);
      await player.dispose();
      expect(calls.last.method, 'dispose');
      // Late native callbacks after disposal must not touch closed streams.
      await event({
        'id': native.id,
        'generation': first['generation'],
        'type': 'error',
      });
    },
  );

  test(
    'TV live cannot seek; VOD audio, subtitles and speed keep native commands',
    () async {
      final native = TvMedia3Player(isLive: true);
      final player = Player(platformPlayer: native);
      await player.open(
        Media(
          'https://example.test/live.ts',
          start: const Duration(seconds: 8),
        ),
      );
      expect(
        (calls.firstWhere((c) => c.method == 'open').arguments
            as Map)['startMs'],
        0,
      );
      await player.seek(const Duration(seconds: 10));
      expect(calls.where((c) => c.method == 'seek'), isEmpty);
      native.isLive = false;
      await player.seek(const Duration(seconds: 75));
      await player.setAudioTrack(const AudioTrack('1:0', 'Français', 'fr'));
      await player.setSubtitleTrack(
        SubtitleTrack.data(
          '1\n00:00:00,000 --> 00:00:02,000\nBonjour',
          title: 'French.srt',
        ),
      );
      await player.setRate(1.5);
      expect(
        (calls.firstWhere((c) => c.method == 'seek').arguments
            as Map)['positionMs'],
        75000,
      );
      expect(
        (calls.firstWhere((c) => c.method == 'audio').arguments
            as Map)['idTrack'],
        '1:0',
      );
      expect(
        (calls.firstWhere((c) => c.method == 'externalSubtitle').arguments
            as Map)['title'],
        'French.srt',
      );
      expect((calls.last.arguments as Map)['value'], 1.5);
      final generation =
          (calls.firstWhere((c) => c.method == 'open').arguments
              as Map)['generation'];
      await event({
        'id': native.id,
        'generation': generation,
        'type': 'tracks',
        'subtitles': [
          {'id': 'external', 'title': 'French.srt'},
        ],
      });
      await event({
        'id': native.id,
        'generation': generation,
        'type': 'state',
        'subtitleTrack': 'external',
      });
      final recoverySubtitle = player.state.track.subtitle;
      expect(recoverySubtitle.data, isTrue);
      await player.open(Media('https://example.test/live.ts'), play: false);
      await player.setSubtitleTrack(recoverySubtitle);
      expect(calls.where((c) => c.method == 'externalSubtitle').length, 2);
      await player.dispose();
    },
  );

  test(
    'TV tracks map to existing controls and errors contain no native location',
    () async {
      final native = TvMedia3Player();
      await native.open(Media('https://example.test/video.mkv'), play: false);
      final generation = (calls.last.arguments as Map)['generation'];
      await event({
        'id': native.id,
        'generation': generation,
        'type': 'tracks',
        'audio': [
          {'id': '0:0', 'language': 'fr', 'codec': 'audio/ac3'},
        ],
        'subtitles': [
          {'id': '2:0', 'language': 'fr', 'codec': 'application/pgs'},
        ],
      });
      await event({
        'id': native.id,
        'generation': generation,
        'type': 'state',
        'audioTrack': '0:0',
        'subtitleTrack': '2:0',
      });
      expect(native.state.track.audio.language, 'fr');
      expect(native.state.track.subtitle.codec, 'application/pgs');
      final error = native.stream.error.first;
      await event({
        'id': native.id,
        'generation': generation,
        'type': 'error',
        'code': 'decoder',
        'message': 'https://private.test/account/password',
      });
      expect(await error, isNot(contains('private.test')));
      await native.dispose();
    },
  );

  test(
    'TV diagnostics reset per source and ignore stale or private native fields',
    () async {
      final native = TvMedia3Player();
      await native.open(Media('https://example.test/first.mkv'), play: false);
      final generation = (calls.last.arguments as Map)['generation'];
      await event({
        'id': native.id,
        'generation': generation,
        'type': 'diagnostics',
        'engineVersion': '1.11.1',
        'videoCodec': 'video/hevc',
        'audioCodec': 'audio/ac3',
        'videoDecoder': 'OMX.MTK.VIDEO.DECODER.HEVC',
        'audioDecoder': 'c2.android.ac3.decoder',
        'firstFrame': true,
      });
      expect(native.diagnostics.value.videoCodec, 'video/hevc');
      expect(
        native.diagnostics.value.videoDecoder,
        'OMX.MTK.VIDEO.DECODER.HEVC',
      );
      expect(native.diagnostics.value.firstFrame, isTrue);
      await native.open(Media('https://example.test/second.mkv'), play: false);
      expect(native.diagnostics.value.firstFrame, isFalse);
      expect(native.diagnostics.value.videoDecoder, isNull);
      await event({
        'id': native.id,
        'generation': generation,
        'type': 'diagnostics',
        'firstFrame': true,
      });
      expect(native.diagnostics.value.firstFrame, isFalse);
      final nextGeneration = (calls.last.arguments as Map)['generation'];
      await event({
        'id': native.id,
        'generation': nextGeneration,
        'type': 'diagnostics',
        'videoCodec': 'https://private.test/account/password',
        'videoDecoder': 'decoder error: https://private.test/token',
      });
      expect(native.diagnostics.value.videoCodec, isNull);
      expect(native.diagnostics.value.videoDecoder, isNull);
      await native.dispose();
    },
  );
}
