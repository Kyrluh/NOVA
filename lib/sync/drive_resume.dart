import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../data/local_store.dart';
import '../data/secret_store.dart';
import '../domain/models.dart';

const _scope = 'https://www.googleapis.com/auth/drive.appdata';
const _limit = 512 * 1024;
final _hex = RegExp(r'^[a-f0-9]{32}$');
final _digest = RegExp(r'^[a-f0-9]{64}$');
final _random = Random.secure();

String newDriveProfileCode() => List.generate(
  16,
  (_) => _random.nextInt(256).toRadixString(16).padLeft(2, '0'),
).join();

bool isDriveProfileCode(String code) => _hex.hasMatch(code);

String driveMediaKey(String code, List<String> parts) => Hmac(
  sha256,
  utf8.encode(code),
).convert(utf8.encode(jsonEncode(parts))).toString();

class DriveResumeEntry {
  const DriveResumeEntry(this.progress, {this.seriesKey});
  final WatchProgress progress;
  final String? seriesKey;

  Map<String, dynamic> toJson() => {
    ...progress.toJson(),
    if (seriesKey != null) 'series': seriesKey,
  };

  static DriveResumeEntry? fromJson(Object? value, DateTime now) {
    if (value is! Map) return null;
    final progress = WatchProgress.fromJson(value);
    final series = value['series'];
    if (progress == null ||
        progress.lastWatched.isAfter(now.add(const Duration(minutes: 5))) ||
        progress.positionSeconds > 7 * 86400 ||
        progress.durationSeconds > 7 * 86400 ||
        (series != null && (series is! String || !_digest.hasMatch(series)))) {
      return null;
    }
    return DriveResumeEntry(progress, seriesKey: series as String?);
  }
}

class DriveSyncException implements Exception {
  const DriveSyncException(this.message);
  final String message;
}

/// Only our app's private folder is requested. The desktop loopback listener
/// binds a random local port, validates state, and exchanges the code with PKCE.
class DriveResumeSync extends ChangeNotifier {
  // Public constructor names avoid exposing the private storage fields.
  // ignore: prefer_initializing_formals
  DriveResumeSync({
    required LocalStore store,
    required SecretStore secrets,
    required this.television,
    required this.openBrowser,
    this.androidAuthorize,
    http.Client? client,
  }) : _store = store,
       _secrets = secrets,
       _http = client ?? http.Client();

  final LocalStore _store;
  final SecretStore _secrets;
  final bool television;
  final Future<void> Function(Uri) openBrowser;
  final Future<String?> Function(bool interactive)? androidAuthorize;
  bool get mobile => androidAuthorize != null;
  String? _androidAccount;
  final http.Client _http;
  final Map<String, String> _profiles = {};
  String _device = newDriveProfileCode();
  String? _clientId;
  String? _clientSecret;
  String? _refresh;
  String? _access;
  DateTime? _expires;
  Future<void>? _initialization;
  bool _disposed = false;
  bool _busy = false;
  int _authorization = 0;
  bool _authorizing = false;
  (Uri, String)? deviceConsent;
  String? problem;
  DateTime? lastSync;

  bool get connected => mobile ? _androidAccount != null : _refresh != null;
  bool get busy => _busy;
  String? codeFor(String profile) => _profiles[profile];

  Future<void> init() => _initialization ??= _load();

  Future<void> _load() async {
    try {
      final envelope = await _store.load();
      final blob = envelope['encrypted'];
      if (blob is! String) return;
      final data =
          jsonDecode(await _secrets.unprotect(base64Decode(blob))) as Map;
      final device = data['device'];
      if (device is String && _hex.hasMatch(device)) _device = device;
      _clientId = data['clientId'] as String?;
      _clientSecret = data['clientSecret'] as String?;
      _refresh = data['refresh'] as String?;
      _androidAccount = data['androidAccount'] as String?;
      final profiles = data['profiles'];
      if (profiles is Map) {
        for (final entry in profiles.entries.take(20)) {
          if (entry.key is String &&
              entry.value is String &&
              isDriveProfileCode(entry.value as String)) {
            _profiles[entry.key as String] = entry.value as String;
          }
        }
      }
    } catch (_) {
      problem = 'Les réglages Drive protégés ne peuvent pas être ouverts.';
    }
    _notify();
  }

  Future<void> _save() async {
    final encrypted = await _secrets.protect(
      jsonEncode({
        'device': _device,
        'clientId': _clientId,
        'clientSecret': _clientSecret,
        'refresh': _refresh,
        'androidAccount': _androidAccount,
        'profiles': _profiles,
      }),
    );
    await _store.save({'encrypted': base64Encode(encrypted)});
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> _operation(Future<void> Function() work) async {
    if (_busy || _disposed) return;
    _busy = true;
    problem = null;
    _notify();
    try {
      await work();
    } on DriveSyncException catch (error) {
      problem = error.message;
    } catch (_) {
      problem =
          'Google Drive est indisponible. La progression locale est conservée.';
    } finally {
      _busy = false;
      _notify();
    }
  }

  Future<void> connectMobile() => _operation(() async {
    if (!mobile || connected) return;
    final token = await _mobileToken(true);
    _androidAccount = await _driveAccount(token);
    try {
      await _save();
    } catch (_) {
      _androidAccount = null;
      rethrow;
    }
    _access = token;
    _expires = DateTime.now().add(const Duration(minutes: 20));
  });

  Future<String> _mobileToken(bool interactive) async {
    try {
      final token = await androidAuthorize!(interactive);
      if (token != null && token.isNotEmpty) return token;
    } catch (_) {
      // Keep native authorization details and tokens out of the UI.
    }
    throw const DriveSyncException(
      'Autorisation Drive indisponible. Vérifiez le client OAuth Android, puis reconnectez Drive.',
    );
  }

  Future<String> _driveAccount(String token) async {
    final data = _object(
      await _drive(
        token,
        'GET',
        '/drive/v3/about',
        query: {'fields': 'user(permissionId)'},
      ),
    );
    final user = data['user'];
    final id = user is Map ? user['permissionId'] : null;
    if (id is! String || id.isEmpty || id.length > 128) {
      throw const DriveSyncException(
        'Impossible de vérifier le compte Google.',
      );
    }
    return id;
  }

  Future<void> connect(String clientId, String clientSecret) =>
      _operation(() async {
        if (connected) return;
        if (!RegExp(r'^[a-zA-Z0-9_-]{8,150}\.apps\.googleusercontent\.com$')
                .hasMatch(clientId) ||
            !RegExp(r'^[a-zA-Z0-9_-]{8,150}$').hasMatch(clientSecret)) {
          throw const DriveSyncException(
            'Vérifiez les identifiants du client OAuth Google.',
          );
        }
        final attempt = ++_authorization;
        _authorizing = true;
        try {
          final tokens = television
              ? await _authorizeDevice(clientId, clientSecret, attempt)
              : await _authorizeDesktop(clientId, clientSecret);
          if (_disposed || attempt != _authorization) return;
          final refresh = tokens['refresh_token'];
          if (refresh is! String || refresh.isEmpty) {
            throw const DriveSyncException(
              'Google n’a pas accordé l’accès hors connexion.',
            );
          }
          _setToken(tokens);
          _clientId = clientId;
          _clientSecret = clientSecret;
          _refresh = refresh;
          try {
            await _save();
          } catch (_) {
            _clientId = _clientSecret = _refresh = _access = null;
            rethrow;
          }
        } finally {
          _authorizing = false;
          deviceConsent = null;
        }
      });

  HttpServer? _loopback;
  Completer<String>? _desktopCode;

  void cancelConnect() {
    if (!_authorizing) return;
    _authorization++;
    final callback = _desktopCode;
    if (callback != null && !callback.isCompleted) callback.complete('');
    deviceConsent = null;
    _notify();
  }

  Future<void> bind(String profile, String code) => _operation(() async {
    if (!connected || !isDriveProfileCode(code)) {
      throw const DriveSyncException(
        'Saisissez le code de profil de 32 caractères.',
      );
    }
    if (_profiles.entries.any(
      (entry) => entry.key != profile && entry.value == code,
    )) {
      throw const DriveSyncException(
        'Ce code est déjà associé à un autre profil local.',
      );
    }
    final previous = _profiles[profile];
    _profiles[profile] = code;
    try {
      await _save();
      lastSync = null;
    } catch (_) {
      if (previous == null) {
        _profiles.remove(profile);
      } else {
        _profiles[profile] = previous;
      }
      rethrow;
    }
  });

  Future<void> disconnect() => _operation(() async {
    // Clear both copies of the local encrypted store. Other linked devices
    // keep their own sessions and Drive retains the resume files.
    await _store.save({});
    await _store.save({});
    _clientId = _clientSecret = _refresh = _access = null;
    _androidAccount = null;
    _profiles.clear();
    lastSync = null;
  });

  Future<Map<String, dynamic>> _authorizeDesktop(
    String id,
    String secret,
  ) async {
    final verifier = newDriveProfileCode() + newDriveProfileCode();
    final challenge = base64Url
        .encode(sha256.convert(utf8.encode(verifier)).bytes)
        .replaceAll('=', '');
    final state = newDriveProfileCode();
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _loopback = server;
    final result = Completer<String>();
    _desktopCode = result;
    final redirect = 'http://127.0.0.1:${server.port}/google-drive';
    server.listen((request) async {
      final query = request.uri.queryParameters;
      if (request.method != 'GET' ||
          request.uri.path != '/google-drive' ||
          query['state'] != state ||
          result.isCompleted) {
        request.response.statusCode = 400;
        await request.response.close();
        return;
      }
      final code = query['code'] ?? '';
      request.response.headers
        ..contentType = ContentType.text
        ..set('Cache-Control', 'no-store')
        ..set('Referrer-Policy', 'no-referrer');
      request.response.write(
        code.isEmpty
            ? 'Autorisation annulée. Vous pouvez retourner dans NOVA.'
            : 'Autorisation reçue. Vous pouvez retourner dans NOVA.',
      );
      await request.response.close();
      if (!result.isCompleted) result.complete(code);
    });
    try {
      if (result.isCompleted || _disposed) return {};
      await openBrowser(
        Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
          'client_id': id,
          'redirect_uri': redirect,
          'response_type': 'code',
          'scope': _scope,
          'access_type': 'offline',
          'prompt': 'consent select_account',
          'state': state,
          'code_challenge': challenge,
          'code_challenge_method': 'S256',
        }),
      );
      final code = await result.future.timeout(const Duration(minutes: 3));
      if (code.isEmpty) {
        throw const DriveSyncException('Connexion Google annulée.');
      }
      return await _token({
        'client_id': id,
        'client_secret': secret,
        'code': code,
        'code_verifier': verifier,
        'redirect_uri': redirect,
        'grant_type': 'authorization_code',
      });
    } finally {
      _desktopCode = null;
      _loopback = null;
      await server.close(force: true);
    }
  }

  Future<Map<String, dynamic>> _authorizeDevice(
    String id,
    String secret,
    int attempt,
  ) async {
    final response = await _form('/device/code', {
      'client_id': id,
      'scope': _scope,
    });
    final data = _object(response.$2);
    final url = Uri.tryParse(
      '${data['verification_url'] ?? data['verification_uri'] ?? ''}',
    );
    final code = data['user_code'];
    final deviceCode = data['device_code'];
    if (response.$1 != 200 ||
        url == null ||
        url.scheme != 'https' ||
        !const {
          'www.google.com',
          'google.com',
          'accounts.google.com',
        }.contains(url.host) ||
        url.userInfo.isNotEmpty ||
        code is! String ||
        !RegExp(r'^[a-zA-Z0-9-]{4,20}$').hasMatch(code) ||
        deviceCode is! String) {
      throw const DriveSyncException(
        'Google ne peut pas fournir de code pour ce client TV.',
      );
    }
    if (attempt != _authorization || _disposed) return {};
    deviceConsent = (url, code);
    _notify();
    var interval = (data['interval'] is int ? data['interval'] as int : 5)
        .clamp(5, 60);
    final seconds =
        (data['expires_in'] is int ? data['expires_in'] as int : 600).clamp(
          1,
          900,
        );
    final expires = DateTime.now().add(Duration(seconds: seconds));
    while (DateTime.now().isBefore(expires)) {
      await Future<void>.delayed(Duration(seconds: interval));
      if (_disposed || attempt != _authorization) return {};
      if (!DateTime.now().isBefore(expires)) break;
      final reply = await _form('/token', {
        'client_id': id,
        'client_secret': secret,
        'device_code': deviceCode,
        'grant_type': 'urn:ietf:params:oauth:grant-type:device_code',
      });
      final token = _object(reply.$2);
      if (reply.$1 == 200) return token;
      if (token['error'] == 'slow_down') {
        interval += 5;
      } else if (token['error'] != 'authorization_pending') {
        break;
      }
    }
    throw const DriveSyncException(
      'Code Google expiré ou autorisation refusée.',
    );
  }

  Future<(int, String)> _form(String path, Map<String, String> fields) {
    final request = http.Request(
      'POST',
      Uri.https('oauth2.googleapis.com', path),
    )..bodyFields = fields;
    return _send(request);
  }

  Future<Map<String, dynamic>> _token(Map<String, String> fields) async {
    final result = await _form('/token', fields);
    final data = _object(result.$2);
    if (result.$1 == 200) return data;
    if (data['error'] == 'invalid_grant') {
      throw const DriveSyncException(
        'Autorisation Google expirée. Déconnectez Drive puis reconnectez-le.',
      );
    }
    throw const DriveSyncException(
      'Google a refusé l’autorisation. Vérifiez votre client OAuth et les comptes autorisés.',
    );
  }

  void _setToken(Map<String, dynamic> data, {bool refreshing = false}) {
    final access = data['access_token'];
    final expires = data['expires_in'];
    if (access is! String ||
        access.isEmpty ||
        expires is! int ||
        (data['scope'] != _scope && !(refreshing && data['scope'] == null)) ||
        data['token_type'].toString().toLowerCase() != 'bearer') {
      throw const DriveSyncException(
        'Google n’a pas confirmé l’accès limité au dossier NOVA.',
      );
    }
    _access = access;
    _expires = DateTime.now().add(Duration(seconds: expires - 30));
  }

  Future<String> _bearer() async {
    if (_access != null && _expires?.isAfter(DateTime.now()) == true) {
      return _access!;
    }
    if (mobile) {
      final token = await _mobileToken(false);
      if (await _driveAccount(token) != _androidAccount) {
        throw const DriveSyncException(
          'Le compte Google a changé. Reconnectez Drive pour choisir le compte.',
        );
      }
      _access = token;
      _expires = DateTime.now().add(const Duration(minutes: 20));
      return token;
    }
    final response = await _token({
      'client_id': _clientId!,
      'client_secret': _clientSecret!,
      'refresh_token': _refresh!,
      'grant_type': 'refresh_token',
    });
    _setToken(response, refreshing: true);
    return _access!;
  }

  Future<(int, String)> _send(http.Request request) async {
    request.followRedirects = false;
    final response = await _http
        .send(request)
        .timeout(const Duration(seconds: 12));
    final content = BytesBuilder(copy: false);
    await for (final chunk in response.stream.timeout(
      const Duration(seconds: 12),
    )) {
      if (content.length + chunk.length > _limit) throw const FormatException();
      content.add(chunk);
    }
    return (response.statusCode, utf8.decode(content.takeBytes()));
  }

  Map<String, dynamic> _object(String text) =>
      jsonDecode(text) as Map<String, dynamic>;

  Future<String> _drive(
    String bearer,
    String method,
    String path, {
    Map<String, String>? query,
    String? body,
    String? type,
  }) async {
    final request = http.Request(
      method,
      Uri.https('www.googleapis.com', path, query),
    )..headers['Authorization'] = 'Bearer $bearer';
    if (body != null) {
      request.headers['Content-Type'] =
          type ?? 'application/json; charset=utf-8';
      request.bodyBytes = utf8.encode(body);
    }
    final result = await _send(request);
    if (result.$1 == 401) _access = null;
    if (result.$1 < 200 || result.$1 >= 300) {
      throw const DriveSyncException(
        'Le dossier NOVA dans Drive est indisponible.',
      );
    }
    return result.$2;
  }

  Future<void> sync(
    String profile,
    Future<Map<String, DriveResumeEntry>?> Function(
      String code,
      Map<String, DriveResumeEntry> remote,
    )
    merge,
  ) => _operation(() async {
    final code = _profiles[profile];
    if (!connected || code == null) return;
    final prefix = 'nova-resume-v1-${driveMediaKey(code, ['profile'])}-';
    final ownName = '$prefix$_device.json';
    final bearer = await _bearer();
    final listed = _object(
      await _drive(
        bearer,
        'GET',
        '/drive/v3/files',
        query: {
          'spaces': 'appDataFolder',
          'q': "trashed = false and name contains '$prefix'",
          'fields': 'nextPageToken,files(id,name,modifiedTime)',
          'orderBy': 'modifiedTime desc',
          'pageSize': '100',
        },
      ),
    );
    final remote = <String, DriveResumeEntry>{};
    String? ownId;
    String? ownBody;
    final now = DateTime.now();
    for (final file in (listed['files'] as List? ?? []).take(24)) {
      if (_disposed || file is! Map) break;
      final name = file['name'];
      final id = file['id'];
      if (name is! String ||
          !name.startsWith(prefix) ||
          id is! String ||
          !RegExp(r'^[a-zA-Z0-9_-]{1,180}$').hasMatch(id)) {
        continue;
      }
      final text = await _drive(
        bearer,
        'GET',
        '/drive/v3/files/$id',
        query: {'alt': 'media'},
      );
      if (name == ownName && ownId == null) {
        ownId = id;
        ownBody = text;
      }
      try {
        final entries = _object(text);
        if (entries['version'] != 1 || entries['entries'] is! Map) continue;
        for (final entry in (entries['entries'] as Map).entries.take(600)) {
          final key = entry.key;
          if (key is! String || !_digest.hasMatch(key)) continue;
          final value = DriveResumeEntry.fromJson(entry.value, now);
          if (value == null) continue;
          final previous = remote[key];
          if (previous == null ||
              value.progress.lastWatched.isAfter(
                previous.progress.lastWatched,
              )) {
            remote[key] = value;
          }
        }
      } on FormatException {
        continue;
      } on TypeError {
        continue;
      }
    }
    if (_disposed) return;
    final local = await merge(code, remote);
    if (_disposed || local == null) return;
    final entries = local.entries.toList()
      ..sort((a, b) {
        final time = b.value.progress.lastWatched.compareTo(
          a.value.progress.lastWatched,
        );
        return time == 0 ? a.key.compareTo(b.key) : time;
      });
    if (entries.isNotEmpty) {
      final body = jsonEncode({
        'version': 1,
        'entries': {
          for (final entry in entries.take(600))
            entry.key: entry.value.toJson(),
        },
      });
      if (ownId == null) {
        final boundary = 'nova-${newDriveProfileCode()}';
        final metadata = jsonEncode({
          'name': ownName,
          'parents': ['appDataFolder'],
        });
        await _drive(
          bearer,
          'POST',
          '/upload/drive/v3/files',
          query: {'uploadType': 'multipart', 'fields': 'id'},
          type: 'multipart/related; boundary=$boundary',
          body:
              '--$boundary\r\nContent-Type: application/json; charset=UTF-8\r\n\r\n'
              '$metadata\r\n--$boundary\r\nContent-Type: application/json\r\n\r\n'
              '$body\r\n--$boundary--\r\n',
        );
      } else if (ownBody != body) {
        await _drive(
          bearer,
          'PATCH',
          '/upload/drive/v3/files/$ownId',
          query: {'uploadType': 'media', 'fields': 'id'},
          body: body,
        );
      }
    }
    lastSync = DateTime.now();
  });

  @override
  void dispose() {
    _disposed = true;
    cancelConnect();
    unawaited(_loopback?.close(force: true));
    _http.close();
    super.dispose();
  }
}
