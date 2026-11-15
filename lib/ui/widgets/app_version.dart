import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';

class AppVersion extends StatefulWidget {
  const AppVersion({super.key});
  @override
  State<AppVersion> createState() => _AppVersionState();
}

class _AppVersionState extends State<AppVersion> {
  late final Future<String> _version = _read();
  Future<String> _read() async {
    try {
      final data = await MethodChannel(
        Platform.isAndroid ? 'nova/android' : 'nova/window',
      ).invokeMapMethod<String, dynamic>('getUpdateInfo');
      final version = data?['version'];
      return version is String && version.isNotEmpty ? 'v$version' : '';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<String>(
    future: _version,
    builder: (_, snapshot) => Text(
      snapshot.data ?? '',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontSize: 10, height: 1.2, color: novaMuted),
    ),
  );
}
