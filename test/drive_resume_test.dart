import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nova_iptv/data/local_store.dart';
import 'package:nova_iptv/data/secret_store.dart';
import 'package:nova_iptv/domain/models.dart';
import 'package:nova_iptv/sync/drive_resume.dart';

const _scope = 'https://www.googleapis.com/auth/drive.appdata';
const _clientId = 'fixture-client.apps.googleusercontent.com';
const _secret = 'fixture-secret';

void main() {
  test('Desktop OAuth rejects wrong state, exchanges via PKCE and stores only a protected envelope', () async {
    String? challenge;
    String? redirect;
    final store = MemoryLocalStore();
    final httpClient = MockClient((request) async {
      expect(request.url.toString(), 'https://oauth2.googleapis.com/token');
      expect(request.followRedirects, isFalse);
      final fields = request.bodyFields;
      expect(fields['redirect_uri'], redirect);
      expect(fields['code'], 'valid-fixture-code');
      expect(
        base64Url
            .encode(sha256.convert(utf8.encode(fields['code_verifier']!)).bytes)
            .replaceAll('=', ''),
        challenge,
      );
      return http.Response(
        jsonEncode({
          'access_token': 'short-lived-fixture',
          'refresh_token': 'refresh-fixture',
          'expires_in': 3600,
          'scope': _scope,
          'token_type': 'Bearer',
        }),
        200,
      );
    });
    final drive = DriveResumeSync(
      store: store,
      secrets: _TestSecretStore(),
      television: false,
      client: httpClient,
      openBrowser: (uri) async {
        expect(uri.host, 'accounts.google.com');
        expect(uri.queryParameters['scope'], _scope);
        expect(uri.queryParameters['code_challenge_method'], 'S256');
        expect(uri.queryParameters.containsKey('client_secret'), isFalse);
        challenge = uri.queryParameters['code_challenge'];
        redirect = uri.queryParameters['redirect_uri'];
        final local = Uri.parse(redirect!);
        expect(local.host, '127.0.0.1');
        final browser = HttpClient();
        try {
          final invalid = await (await browser.getUrl(
            local.replace(
              queryParameters: {'state': 'wrong', 'code': 'invalid'},
            ),
          )).close();
          expect(invalid.statusCode, 400);
          await invalid.drain<void>();
          final valid = await (await browser.getUrl(
            local.replace(
              queryParameters: {
                'state': uri.queryParameters['state'],
                'code': 'valid-fixture-code',
              },
            ),
          )).close();
          expect(valid.statusCode, 200);
          await valid.drain<void>();
        } finally {
          browser.close(force: true);
        }
      },
    );
    addTearDown(drive.dispose);
    await drive.connect(_clientId, _secret);
    expect(drive.connected, isTrue, reason: drive.problem);
    expect(store.data.keys, ['encrypted']);
    expect(jsonEncode(store.data), isNot(contains('refresh-fixture')));
    final code = newDriveProfileCode();
    await drive.bind('profile-a', code);
    await drive.bind('profile-b', code);
    expect(drive.codeFor('profile-a'), code);
    expect(drive.codeFor('profile-b'), isNull);
    await drive.disconnect();
    expect(store.data, isEmpty);
    expect(drive.connected, isFalse);
  });

  test('Sync merges device files and uploads only pseudonymous progress to appDataFolder', () async {
    final secrets = _TestSecretStore();
    final profile = newDriveProfileCode();
    final identity = driveMediaKey(profile, ['provider', 'movie', '123']);
    final position = WatchProgress(
      positionSeconds: 75,
      durationSeconds: 1800,
      lastWatched: DateTime.utc(2026, 11, 15),
    );
    final old = WatchProgress(
      positionSeconds: 18,
      durationSeconds: 1800,
      lastWatched: DateTime.utc(2026, 11, 14),
    );
    final scope = driveMediaKey(profile, ['profile']);
    final store = MemoryLocalStore({
      'encrypted': base64Encode(
        await secrets.protect(
          jsonEncode({
            'device': newDriveProfileCode(),
            'clientId': _clientId,
            'clientSecret': _secret,
            'refresh': 'refresh-fixture',
            'profiles': {'local-profile': profile},
          }),
        ),
      ),
    });
    var uploads = 0;
    final client = MockClient((request) async {
      if (request.url.host == 'oauth2.googleapis.com') {
        expect(request.bodyFields['grant_type'], 'refresh_token');
        return http.Response(
          jsonEncode({
            'access_token': 'current-fixture',
            'expires_in': 3600,
            'token_type': 'Bearer',
          }),
          200,
        );
      }
      expect(request.url.host, 'www.googleapis.com');
      expect(request.headers['authorization'], 'Bearer current-fixture');
      if (request.url.path == '/drive/v3/files') {
        expect(request.url.queryParameters['spaces'], 'appDataFolder');
        return http.Response(
          jsonEncode({
            'files': [
              {'name': 'nova-resume-v1-$scope-other.json', 'id': 'remote'},
              {'name': 'nova-resume-v1-$scope-older.json', 'id': 'old'},
              {'name': 'unrelated.json', 'id': 'unrelated'},
            ],
          }),
          200,
        );
      }
      if (request.url.path == '/drive/v3/files/remote' ||
          request.url.path == '/drive/v3/files/old') {
        final entry = request.url.path.endsWith('old') ? old : position;
        return http.Response(
          jsonEncode({
            'version': 1,
            'entries': {identity: entry.toJson()},
          }),
          200,
        );
      }
      expect(request.url.path, '/upload/drive/v3/files');
      expect(request.method, 'POST');
      expect(request.body, contains('"parents":["appDataFolder"]'));
      expect(request.body, contains('"positionSeconds":75'));
      expect(request.body, isNot(contains('refresh-fixture')));
      expect(request.body, isNot(contains('local-profile')));
      expect(request.body, isNot(contains('provider')));
      expect(request.body, isNot(contains(profile)));
      uploads++;
      return http.Response('{"id":"created"}', 200);
    });
    final drive = DriveResumeSync(
      store: store,
      secrets: secrets,
      television: true,
      client: client,
      openBrowser: (_) async => fail('No browser should open'),
    );
    addTearDown(drive.dispose);
    await drive.init();
    await drive.sync('local-profile', (code, entries) async {
      expect(code, profile);
      expect(entries.keys, [identity]);
      expect(entries[identity]!.progress.positionSeconds, 75);
      return entries;
    });
    expect(drive.problem, isNull);
    expect(uploads, 1);
  });
}

class _TestSecretStore implements SecretStore {
  @override
  Future<Uint8List> protect(String value) async =>
      Uint8List.fromList(utf8.encode(value));

  @override
  Future<String> unprotect(Uint8List value) async => utf8.decode(value);
}
