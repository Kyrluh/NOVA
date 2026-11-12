import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class UpdateException implements Exception {
  const UpdateException(this.message);
  final String message;
  @override
  String toString() => message;
}

class InstalledApp {
  const InstalledApp({
    required this.version,
    required this.windows,
    this.television = false,
    this.arm64 = false,
    this.debug = false,
  });
  final String version;
  final bool windows;
  final bool television;
  final bool arm64;
  final bool debug;
  String get edition => windows
      ? 'Windows x64'
      : television
      ? 'Android TV / Fire TV'
      : arm64
      ? 'Android ARM64'
      : 'Android universel';
}

class AppRelease {
  const AppRelease({
    required this.version,
    required this.filename,
    required this.url,
    required this.bytes,
    required this.digest,
  });
  final String version;
  final String filename;
  final Uri url;
  final int bytes;
  final String? digest;
}

List<int>? _version(String value) {
  final match = RegExp(r'^v?(\d+)\.(\d+)\.(\d+)(?:\+\d+)?$').firstMatch(value);
  return match == null
      ? null
      : [for (var i = 1; i <= 3; i++) int.parse(match[i]!)];
}

int compareAppVersions(String left, String right) {
  final a = _version(left), b = _version(right);
  if (a == null || b == null) {
    throw const UpdateException('Version de l’application non reconnue.');
  }
  for (var i = 0; i < 3; i++) {
    final difference = a[i].compareTo(b[i]);
    if (difference != 0) return difference;
  }
  return 0;
}

/// Exact edition names and repository URLs prevent a TV/phone/source mix-up.
AppRelease? releaseForApp(Map<String, dynamic> json, InstalledApp app) {
  if (json['draft'] == true || json['prerelease'] == true) return null;
  final tag = json['tag_name'];
  if (tag is! String || _version(tag) == null) return null;
  final version = tag.startsWith('v') ? tag.substring(1) : tag;
  final names = app.windows
      ? ['NOVA-IPTV-$version-windows-x64.zip']
      : app.television
      ? ['NOVA-IPTV-TV-$version-universal.apk']
      : [
          if (app.arm64) 'NOVA-IPTV-$version-arm64-v8a.apk',
          'NOVA-IPTV-$version-universal.apk',
        ];
  final assets = json['assets'];
  if (assets is! List) return null;
  for (final name in names) {
    for (final asset in assets.whereType<Map>()) {
      if (asset['name'] != name || asset['state'] != 'uploaded') continue;
      final size = asset['size'];
      final address = asset['browser_download_url'];
      if (size is! int ||
          size <= 0 ||
          size > 512 * 1024 * 1024 ||
          address is! String) {
        continue;
      }
      final url = Uri.tryParse(address);
      if (url == null ||
          url.scheme != 'https' ||
          url.host != 'github.com' ||
          url.hasPort ||
          url.userInfo.isNotEmpty ||
          url.hasQuery ||
          url.hasFragment ||
          url.path != '/Kyrluh/NOVA/releases/download/$tag/$name') {
        continue;
      }
      final rawDigest = asset['digest'];
      final digest =
          rawDigest is String &&
              RegExp(r'^sha256:[a-fA-F0-9]{64}$').hasMatch(rawDigest)
          ? rawDigest.substring(7).toLowerCase()
          : null;
      return AppRelease(
        version: version,
        filename: name,
        url: url,
        bytes: size,
        digest: digest,
      );
    }
  }
  return null;
}

class AppUpdateService {
  AppUpdateService({
    http.Client? client,
    Future<Directory> Function()? cacheDirectory,
  }) : _client = client ?? http.Client(),
       _cacheDirectory = cacheDirectory ?? getTemporaryDirectory;
  static final _api = Uri.https(
    'api.github.com',
    '/repos/Kyrluh/NOVA/releases/latest',
  );
  final http.Client _client;
  final Future<Directory> Function() _cacheDirectory;
  bool _closed = false;
  MethodChannel get _native =>
      MethodChannel(Platform.isAndroid ? 'nova/android' : 'nova/window');

  /// Remove only our own installers whose version is already installed.
  /// Leave newer downloads intact if installation was postponed or cancelled.
  Future<void> cleanInstalledApks() async {
    try {
      final app = await installed();
      if (app.windows) return;
      final folder = Directory(
        '${(await _cacheDirectory()).path}${Platform.pathSeparator}updates',
      );
      if (!await folder.exists()) return;
      final pattern = RegExp(
        app.television
            ? r'^NOVA-IPTV-TV-(\d+\.\d+\.\d+)-universal\.apk$'
            : r'^NOVA-IPTV-(\d+\.\d+\.\d+)-(?:universal|arm64-v8a)\.apk$',
      );
      await for (final entry in folder.list(followLinks: false)) {
        if (entry is! File) continue;
        final match = pattern.firstMatch(entry.uri.pathSegments.last);
        if (match != null && compareAppVersions(match[1]!, app.version) <= 0) {
          await entry.delete();
        }
      }
    } catch (_) {
      // A locked installer or unavailable cache must never block startup.
    }
  }

  Future<InstalledApp> installed() async {
    final data = await _native.invokeMapMethod<String, dynamic>(
      'getUpdateInfo',
    );
    if (data == null) {
      throw const UpdateException('Impossible de lire la version installée.');
    }
    final version = data['version'] as String? ?? '';
    final app = InstalledApp(
      version: version,
      windows: data['platform'] == 'windows',
      television: data['television'] == true,
      arm64: (data['abis'] as List? ?? []).contains('arm64-v8a'),
      debug: data['debug'] == true,
    );
    if (app.debug) {
      throw const UpdateException(
        'Les mises à jour sont disponibles dans les versions Release de NOVA.',
      );
    }
    if (_version(version) == null) {
      throw const UpdateException('Version installée non reconnue.');
    }
    return app;
  }

  Future<Object?> _json(Uri uri) async {
    final response = await _client
        .get(
          uri,
          headers: {
            'Accept': 'application/vnd.github+json',
            'User-Agent': 'NOVA-IPTV-Updater',
          },
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode == 403 || response.statusCode == 429) {
      throw const UpdateException(
        'GitHub limite temporairement les vérifications. Réessayez plus tard.',
      );
    }
    if (response.statusCode != 200 ||
        response.bodyBytes.length > 4 * 1024 * 1024) {
      throw const UpdateException(
        'La vérification GitHub est indisponible. Réessayez plus tard.',
      );
    }
    return jsonDecode(utf8.decode(response.bodyBytes));
  }

  Future<AppRelease?> latest(InstalledApp app) async {
    final newest = await _json(_api);
    if (newest is! Map<String, dynamic>) {
      throw const UpdateException('Réponse GitHub non reconnue.');
    }
    final direct = releaseForApp(newest, app);
    if (direct != null) return direct;
    // A release may update only TV or only Windows: search stable releases for
    // this edition instead of offering an incompatible APK from /latest.
    AppRelease? best;
    for (var page = 1; page <= 3; page++) {
      final result = await _json(
        Uri.https('api.github.com', '/repos/Kyrluh/NOVA/releases', {
          'per_page': '20',
          'page': '$page',
        }),
      );
      if (result is! List) {
        throw const UpdateException('Liste des versions indisponible.');
      }
      for (final entry in result.whereType<Map<String, dynamic>>()) {
        final candidate = releaseForApp(entry, app);
        if (candidate != null &&
            (best == null ||
                compareAppVersions(candidate.version, best.version) > 0)) {
          best = candidate;
        }
      }
      if (best != null || result.length < 20) break;
    }
    return best;
  }

  Future<String> download(
    AppRelease release,
    void Function(int received, int total) progress,
  ) async {
    if (release.digest == null) {
      throw const UpdateException(
        'Empreinte de vérification absente : téléchargement annulé.',
      );
    }
    final folder = Directory(
      '${(await _cacheDirectory()).path}${Platform.pathSeparator}updates',
    );
    await folder.create(recursive: true);
    final target = File(
      '${folder.path}${Platform.pathSeparator}${release.filename}',
    );
    Future<bool> verified() async =>
        await target.exists() &&
        await target.length() == release.bytes &&
        (await sha256.bind(target.openRead()).first).toString() ==
            release.digest;
    if (await verified()) return target.path;
    final partial = File('${target.path}.part');
    IOSink? sink;
    try {
      final response = await _client
          .send(http.Request('GET', release.url))
          .timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) {
        throw const UpdateException('Téléchargement indisponible. Réessayez.');
      }
      sink = partial.openWrite();
      var count = 0;
      var flushed = 0;
      var notified = DateTime.fromMillisecondsSinceEpoch(0);
      await for (final bytes in response.stream.timeout(
        const Duration(seconds: 30),
      )) {
        if (_closed) throw const UpdateException('Téléchargement annulé.');
        count += bytes.length;
        if (count > release.bytes) {
          throw const UpdateException('Taille du fichier incorrecte.');
        }
        sink.add(bytes);
        if (count - flushed >= 1024 * 1024) {
          await sink.flush();
          flushed = count;
        }
        if (DateTime.now().difference(notified) >
            const Duration(milliseconds: 200)) {
          notified = DateTime.now();
          progress(count, release.bytes);
        }
      }
      await sink.close();
      sink = null;
      if (count != release.bytes ||
          (await sha256.bind(partial.openRead()).first).toString() !=
              release.digest) {
        throw const UpdateException(
          'Le fichier téléchargé est incomplet ou incorrect. Réessayez.',
        );
      }
      if (await target.exists()) await target.delete();
      await partial.rename(target.path);
      progress(count, release.bytes);
      return target.path;
    } finally {
      await sink?.close();
      if (await partial.exists()) await partial.delete();
    }
  }

  Future<String> install(String path) async =>
      await _native.invokeMethod<String>('installUpdate', path) ??
      'unavailable';
  Future<void> openPermissionSettings() =>
      _native.invokeMethod<void>('openUpdateSettings');
  Future<void> openWindowsDownload(AppRelease release) =>
      _native.invokeMethod<void>('openUpdateUrl', release.url.toString());
  void close() {
    _closed = true;
    _client.close();
  }
}
