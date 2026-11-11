import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nova_iptv/updates/app_updates.dart';
import 'package:nova_iptv/ui/pages/app_updates_page.dart';

const phone = InstalledApp(version: '0.10.1', windows: false, arm64: true);
const tv = InstalledApp(
  version: '0.10.1',
  windows: false,
  television: true,
  arm64: true,
);
const windows = InstalledApp(version: '0.10.1+33', windows: true);

Map<String, dynamic> release(String version, List<String> suffixes) => {
  'tag_name': 'v$version',
  'draft': false,
  'prerelease': false,
  'assets': [
    for (final suffix in suffixes)
      {
        'name': 'NOVA-IPTV-$suffix',
        'state': 'uploaded',
        'size': 100,
        'browser_download_url':
            'https://github.com/Kyrluh/NOVA/releases/download/v$version/NOVA-IPTV-$suffix',
        'digest': 'sha256:${'a' * 64}',
      },
  ],
};

void main() {
  test('Select exact edition, ARM64 preference and universal fallback', () {
    final data = release('0.11.0', [
      '0.11.0-source.zip',
      '0.11.0-universal.apk',
      'TV-0.11.0-universal.apk',
      '0.11.0-arm64-v8a.apk',
      '0.11.0-windows-x64.zip',
    ]);
    expect(
      releaseForApp(data, tv)!.filename,
      'NOVA-IPTV-TV-0.11.0-universal.apk',
    );
    expect(
      releaseForApp(data, phone)!.filename,
      'NOVA-IPTV-0.11.0-arm64-v8a.apk',
    );
    expect(
      releaseForApp(data, windows)!.filename,
      'NOVA-IPTV-0.11.0-windows-x64.zip',
    );
    expect(
      releaseForApp(
        data,
        const InstalledApp(version: '0.10.1', windows: false),
      )!.filename,
      'NOVA-IPTV-0.11.0-universal.apk',
    );
    expect(
      releaseForApp(release('0.11.0', ['TV-0.11.0-universal.apk']), phone),
      isNull,
    );
    expect(compareAppVersions('0.10.0', '0.9.12'), greaterThan(0));
    expect(compareAppVersions('0.10.2+34', 'v0.10.2'), 0);
    final malicious = release('0.11.0', ['0.11.0-arm64-v8a.apk']);
    (malicious['assets'] as List).first['browser_download_url'] =
        'https://example.test/NOVA-IPTV-0.11.0-arm64-v8a.apk';
    expect(releaseForApp(malicious, phone), isNull);
  });

  test(
    'TV-only latest release falls back to newest stable phone release',
    () async {
      final latest = release('0.12.0', ['TV-0.12.0-universal.apk']);
      final beta = release('0.20.0', ['0.20.0-arm64-v8a.apk'])
        ..['prerelease'] = true;
      final client = MockClient(
        (request) async => http.Response(
          jsonEncode(
            request.url.path.endsWith('/latest')
                ? latest
                : [
                    latest,
                    beta,
                    release('0.10.9', ['0.10.9-universal.apk']),
                    release('0.11.2', ['0.11.2-arm64-v8a.apk']),
                  ],
          ),
          200,
        ),
      );
      final service = AppUpdateService(client: client);
      addTearDown(service.close);
      expect((await service.latest(phone))!.version, '0.11.2');
      expect((await service.latest(tv))!.version, '0.12.0');
    },
  );

  test('GitHub rate limit has a retryable message', () async {
    final service = AppUpdateService(
      client: MockClient((_) async => http.Response('', 403)),
    );
    addTearDown(service.close);
    await expectLater(
      service.latest(phone),
      throwsA(
        isA<UpdateException>().having(
          (e) => e.message,
          'message',
          contains('temporairement'),
        ),
      ),
    );
  });

  test('Download verifies integrity, reuses verified cache and rejects corrupt bytes', () async {
    final folder = await Directory.systemTemp.createTemp('nova-update-test-');
    addTearDown(() => folder.delete(recursive: true));
    final bytes = utf8.encode('fixture APK');
    var requests = 0;
    final service = AppUpdateService(
      cacheDirectory: () async => folder,
      client: MockClient((_) async {
        requests++;
        return http.Response.bytes(bytes, 200);
      }),
    );
    addTearDown(service.close);
    final good = AppRelease(
      version: '0.11.0',
      filename: 'NOVA-IPTV-0.11.0-universal.apk',
      url: Uri.parse(
        'https://github.com/Kyrluh/NOVA/releases/download/v0.11.0/NOVA-IPTV-0.11.0-universal.apk',
      ),
      bytes: bytes.length,
      digest: sha256.convert(bytes).toString(),
    );
    final path = await service.download(good, (_, _) {});
    expect(await File(path).readAsBytes(), bytes);
    expect(await service.download(good, (_, _) {}), path);
    expect(requests, 1);
    final bad = AppRelease(
      version: '0.11.1',
      filename: 'NOVA-IPTV-0.11.1-universal.apk',
      url: good.url,
      bytes: bytes.length,
      digest: 'b' * 64,
    );
    await expectLater(
      service.download(bad, (_, _) {}),
      throwsA(isA<UpdateException>()),
    );
    expect(
      await File('${folder.path}/updates/${bad.filename}').exists(),
      isFalse,
    );
    expect(
      await File('${folder.path}/updates/${bad.filename}.part').exists(),
      isFalse,
    );
  });

  testWidgets(
    'TV update flow requires a check then installs the selected TV APK',
    (tester) async {
      final service = _UiService();
      addTearDown(service.close);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppUpdatesPanel(television: true, service: service),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(service.checks, 0);
      expect(find.textContaining('Android TV / Fire TV'), findsOneWidget);
      await tester.tap(find.text('Vérifier les mises à jour'));
      await tester.pumpAndSettle();
      expect(find.text('La version 0.11.0 est disponible.'), findsOneWidget);
      final button = find.text('Télécharger et installer la mise à jour');
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(
        service.installedPath,
        contains('NOVA-IPTV-TV-0.11.0-universal.apk'),
      );
      expect(find.textContaining('installateur Android'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Android permission round trip reuses the verified APK', (
    tester,
  ) async {
    final service = _UiService()..requirePermission = true;
    addTearDown(service.close);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: AppUpdatesPanel(service: service)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vérifier les mises à jour'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.text('Télécharger et installer la mise à jour'),
    );
    await tester.tap(find.text('Télécharger et installer la mise à jour'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Autoriser l’installation'));
    await tester.tap(find.text('Autoriser l’installation'));
    await tester.pumpAndSettle();
    expect(service.settingsOpened, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    service.requirePermission = false;
    await tester.ensureVisible(find.text('Installer la mise à jour'));
    await tester.tap(find.text('Installer la mise à jour'));
    await tester.pumpAndSettle();
    expect(service.downloads, 1);
    expect(service.installs, 2);
    expect(find.textContaining('installateur Android'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}

class _UiService extends AppUpdateService {
  int checks = 0;
  int downloads = 0;
  int installs = 0;
  int settingsOpened = 0;
  bool requirePermission = false;
  String? installedPath;
  @override
  Future<InstalledApp> installed() async => tv;
  @override
  Future<AppRelease?> latest(InstalledApp app) async {
    checks++;
    return releaseForApp(release('0.11.0', ['TV-0.11.0-universal.apk']), app);
  }

  @override
  Future<String> download(
    AppRelease release,
    void Function(int, int) progress,
  ) async {
    downloads++;
    progress(100, 100);
    return '/cache/updates/${release.filename}';
  }

  @override
  Future<String> install(String path) async {
    installs++;
    installedPath = path;
    return requirePermission ? 'permission' : 'installer';
  }

  @override
  Future<void> openPermissionSettings() async {
    settingsOpened++;
  }
}
