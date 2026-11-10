import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nova_iptv/data/secret_store.dart';
import 'package:nova_iptv/data/source_repository.dart';
import 'package:nova_iptv/domain/models.dart';
import 'package:nova_iptv/domain/source_models.dart';
import 'package:path_provider/path_provider.dart';

/// Executes against the installed application's Android Keystore and sqflite
/// plugin. It never imports a real source or opens a media stream.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Android Keystore authenticates protected Unicode fragments', (
    tester,
  ) async {
    const secrets = AndroidKeystoreSecretStore();
    const plaintext = 'NOVA stockage privé de test · accents éè · 👩‍🚀 · 中文';
    final encrypted = await secrets.protect(plaintext);
    expect(encrypted, isNotEmpty);
    expect(await secrets.unprotect(encrypted), plaintext);
    final modified = Uint8List.fromList(encrypted);
    modified[modified.length - 1] ^= 1;
    await expectLater(
      secrets.unprotect(modified),
      throwsA(isA<SecretStoreException>()),
    );
  });

  testWidgets(
    'Android SQLite restores a large protected catalogue without CursorWindow overflow',
    (tester) async {
      final directory = await getTemporaryDirectory();
      final path =
          '${directory.path}${Platform.pathSeparator}nova-storage-validation.sqlite';
      final original = SourceRecord(
        config: const SourceConfig(
          id: 'android-fixture',
          name: 'Validation locale',
          kind: SourceKind.m3uUrl,
          address: 'https://example.test/original-fixture.m3u',
        ),
        catalog: SourceCatalog(
          items: [
            for (var i = 0; i < 2500; i++)
              MediaItem(
                id: 'original-fixture-$i',
                title: 'Film de test 👩‍🚀 $i',
                kind: MediaKind.movie,
                category: 'FR | Validation',
                description: List.filled(
                  40,
                  'Synopsis original accentué 👩‍🚀.',
                ).join(' '),
                year: 2026,
                durationMinutes: 90,
                palette: 0xff8b5cf6,
                subtitle: '',
                art: 0,
                sourceId: 'android-fixture',
              ),
          ],
        ),
        programmes: const [],
        updatedAt: DateTime.utc(2026, 11, 9),
      );
      final first = SQLiteSourceRepository(
        path: path,
        secrets: const AndroidKeystoreSecretStore(),
      );
      await first.write(original);
      await first.close();
      final second = SQLiteSourceRepository(
        path: path,
        secrets: const AndroidKeystoreSecretStore(),
      );
      try {
        final restored = await second.readAll();
        expect(restored, hasLength(1));
        expect(restored.single.catalog.items, hasLength(2500));
        expect(
          restored.single.catalog.items.last.title,
          original.catalog.items.last.title,
        );
        expect(
          restored.single.catalog.items.last.description,
          original.catalog.items.last.description,
        );
        await second.delete('android-fixture');
        expect(await second.readAll(), isEmpty);
      } finally {
        await second.close();
        final file = File(path);
        if (await file.exists()) await file.delete();
      }
    },
  );
}
