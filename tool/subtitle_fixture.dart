// Original deterministic test media, with no downloaded or provider content.
// Minimal Matroska: raw BGR video, silent PCM and two UTF-8 subtitle tracks.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

Future<({File video, File external})> createSubtitleFixture(
  Directory directory,
) async {
  await directory.create(recursive: true);
  final bitmap = ByteData(40)
    ..setUint32(0, 40, Endian.little)
    ..setInt32(4, 64, Endian.little)
    ..setInt32(8, 36, Endian.little)
    ..setUint16(12, 1, Endian.little)
    ..setUint16(14, 24, Endian.little)
    ..setUint32(20, 64 * 36 * 3, Endian.little);
  final tracks = _element(0x1654ae6b, [
    ..._track(
      1,
      1,
      'V_MS/VFW/FOURCC',
      extra: [
        ..._element(0x63a2, bitmap.buffer.asUint8List()),
        ..._unsigned(0x23e383, 250000000),
        ..._element(0xe0, [..._unsigned(0xb0, 64), ..._unsigned(0xba, 36)]),
      ],
    ),
    ..._track(
      2,
      2,
      'A_PCM/INT/LIT',
      extra: [
        ..._element(0xe1, [
          ..._float(0xb5, 16000),
          ..._unsigned(0x9f, 1),
          ..._unsigned(0x6264, 16),
        ]),
      ],
    ),
    ..._track(3, 17, 'S_TEXT/UTF8', language: 'fra', name: 'Français'),
    ..._track(4, 17, 'S_TEXT/UTF8', language: 'eng', name: 'English'),
  ]);
  final clusters = <int>[];
  for (var time = 0; time < 12000; time += 250) {
    final frame = Uint8List(64 * 36 * 3);
    for (var index = 0; index < frame.length; index += 3) {
      frame[index] = (time ~/ 50) % 255;
      frame[index + 1] = 70;
      frame[index + 2] = 120;
    }
    clusters.addAll(
      _element(0x1f43b675, [
        ..._unsigned(0xe7, time),
        ..._element(0xa3, [0x81, 0, 0, 0x80, ...frame]),
        ..._element(0xa3, [0x82, 0, 0, 0x80, ...Uint8List(8000)]),
        if (time == 1000 || time == 6000) ...[
          ..._subtitle(
            3,
            time == 1000
                ? 'Bonjour NOVA, été français.'
                : 'Deuxième réplique française.',
          ),
          ..._subtitle(
            4,
            time == 1000
                ? 'Hello NOVA, English subtitles.'
                : 'Second English cue.',
          ),
        ],
      ]),
    );
  }
  final bytes = [
    ..._element(0x1a45dfa3, [
      ..._unsigned(0x4286, 1),
      ..._unsigned(0x42f7, 1),
      ..._unsigned(0x42f2, 4),
      ..._unsigned(0x42f3, 8),
      ..._text(0x4282, 'matroska'),
      ..._unsigned(0x4287, 4),
      ..._unsigned(0x4285, 2),
    ]),
    ..._element(0x18538067, [
      ..._element(0x1549a966, [
        ..._unsigned(0x2ad7b1, 1000000),
        ..._float(0x4489, 12000),
        ..._text(0x4d80, 'NOVA original test fixture'),
        ..._text(0x5741, 'NOVA original test fixture'),
      ]),
      ...tracks,
      ...clusters,
    ]),
  ];
  final video = File('${directory.path}/original-two-languages.mkv');
  await video.writeAsBytes(bytes);
  final external = File('${directory.path}/original-external.srt');
  await external.writeAsString(
    '1\n00:00:01,000 --> 00:00:04,000\nSous-titre SRT externe : été.\n\n2\n00:00:06,000 --> 00:00:09,000\nDeuxième réplique externe.\n',
  );
  return (video: video, external: external);
}

List<int> _track(
  int number,
  int type,
  String codec, {
  String language = 'und',
  String? name,
  List<int> extra = const [],
}) => _element(0xae, [
  ..._unsigned(0xd7, number),
  ..._unsigned(0x73c5, number),
  ..._unsigned(0x83, type),
  ..._unsigned(0x9c, 0),
  ..._unsigned(0x88, type == 17 ? 0 : 1),
  ..._text(0x86, codec),
  ..._text(0x22b59c, language),
  if (name != null) ..._text(0x536e, name),
  ...extra,
]);

List<int> _subtitle(int track, String text) => _element(0xa0, [
  ..._element(0xa1, [0x80 | track, 0, 0, 0, ...utf8.encode(text)]),
  ..._unsigned(0x9b, 3000),
]);

List<int> _integer(int value) {
  final bytes = <int>[value & 255];
  while ((value >>= 8) > 0) {
    bytes.insert(0, value & 255);
  }
  return bytes;
}

List<int> _size(int size) {
  var count = 1;
  while (size >= (1 << (7 * count)) - 1) {
    count++;
  }
  final bytes = List<int>.filled(count, 0);
  for (var index = count - 1; index >= 0; index--) {
    bytes[index] = size & 255;
    size >>= 8;
  }
  bytes[0] |= 1 << (8 - count);
  return bytes;
}

List<int> _element(int id, List<int> value) => [
  ..._integer(id),
  ..._size(value.length),
  ...value,
];
List<int> _unsigned(int id, int value) => _element(id, _integer(value));
List<int> _text(int id, String value) => _element(id, utf8.encode(value));
List<int> _float(int id, double value) => _element(
  id,
  (ByteData(8)..setFloat64(0, value, Endian.big)).buffer.asUint8List(),
);
