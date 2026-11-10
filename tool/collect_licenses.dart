import 'dart:convert';
import 'dart:io';

Future<void> main() async {
  final configFile = File('.dart_tool/package_config.json').absolute;
  final config =
      jsonDecode(await configFile.readAsString()) as Map<String, dynamic>;
  final out = StringBuffer(
    'NOVA IPTV — licences des packages résolus dans pubspec.lock\n\n',
  );
  for (final entry in config['packages'] as List<dynamic>) {
    final package = entry as Map<String, dynamic>;
    if (package['name'] == 'nova_iptv') continue;
    final root = configFile.uri.resolve(package['rootUri'] as String);
    for (final filename in [
      'LICENSE',
      'LICENSE.md',
      'LICENSE.txt',
      'COPYING',
    ]) {
      final file = File.fromUri(root.resolve(filename));
      if (!await file.exists()) continue;
      out.writeln('=' * 72);
      out.writeln(package['name']);
      out.writeln('=' * 72);
      out.writeln(await file.readAsString());
      break;
    }
  }
  await Directory('licenses').create();
  await File('licenses/dart-packages.txt').writeAsString(out.toString());
  stdout.writeln('Package licences collected.');
}
