import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nova_iptv/data/secret_store.dart';
import 'package:nova_iptv/data/source_repository.dart';
import 'package:nova_iptv/domain/models.dart';
import 'package:nova_iptv/domain/source_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  test(
    'Windows DPAPI protects a complete record and rejects modified data',
    () async {
      const store = DpapiSecretStore();
      final plaintext =
          'private-password-${List.filled(2000, 'confidential').join()}';
      final encrypted = await store.protect(plaintext);
      expect(latin1.decode(encrypted), isNot(contains('private-password')));
      expect(await store.unprotect(encrypted), plaintext);
      final modified = Uint8List.fromList(encrypted);
      modified[modified.length ~/ 2] ^= 1;
      await expectLater(store.unprotect(modified), throwsA(anything));
    },
    skip: !Platform.isWindows,
  );

  test(
    'SQLite stores no private URLs or credentials and restores the cache',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'nova-source-db-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final path = '${directory.path}${Platform.pathSeparator}sources.sqlite';
      final secrets = _OpaqueTestStore();
      final repository = SQLiteSourceRepository(
        path: path,
        secrets: secrets,
        factory: databaseFactoryFfiNoIsolate,
      );
      final original = _record();
      await repository.write(original);
      await repository.close();
      final rawDatabase = latin1.decode(await File(path).readAsBytes());
      for (final sensitive in [
        'ultra-secret-user',
        'ultra-secret-password',
        'private.provider.test',
        'private-token',
      ]) {
        expect(rawDatabase, isNot(contains(sensitive)));
      }
      final restored = SQLiteSourceRepository(
        path: path,
        secrets: secrets,
        factory: databaseFactoryFfiNoIsolate,
      );
      final records = await restored.readAll();
      expect(records, hasLength(1));
      expect(records.single.config.password, original.config.password);
      expect(
        records.single.catalog.items.single.mediaUrl,
        original.catalog.items.single.mediaUrl,
      );
      expect(records.single.programmes.single.channelAliases, ['Channel name']);
      expect(records.single.updatedAt, original.updatedAt);
      await restored.delete(original.config.id);
      expect(await restored.readAll(), isEmpty);
      await restored.close();
    },
  );

  test(
    'An unreadable encrypted row does not hide valid cached sources',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'nova-source-corrupt-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final path = '${directory.path}${Platform.pathSeparator}sources.sqlite';
      final repository = SQLiteSourceRepository(
        path: path,
        secrets: _OpaqueTestStore(),
        factory: databaseFactoryFfiNoIsolate,
      );
      await repository.write(_record());
      final raw = await databaseFactoryFfiNoIsolate.openDatabase(
        path,
        options: OpenDatabaseOptions(singleInstance: false),
      );
      await raw.insert('sources', {
        'id': 'bad-row',
        'payload': Uint8List.fromList([0, 1, 2]),
      });
      await raw.close();
      expect(await repository.readAll(), hasLength(1));
      expect(repository.warnings, hasLength(1));
      await repository.close();
    },
  );

  test(
    'A protection failure leaves the previously committed catalogue intact',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'nova-source-failure-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final secrets = _OpaqueTestStore();
      final repository = SQLiteSourceRepository(
        path: '${directory.path}${Platform.pathSeparator}sources.sqlite',
        secrets: secrets,
        factory: databaseFactoryFfiNoIsolate,
      );
      final original = _record();
      await repository.write(original);
      secrets.failProtect = true;
      await expectLater(
        repository.write(_record(title: 'Changed')),
        throwsA(
          isA<SourceRepositoryException>().having(
            (error) => error.message,
            'safe message',
            isNot(contains('leaked-password')),
          ),
        ),
      );
      expect(
        (await repository.readAll()).single.catalog.items.single.title,
        original.catalog.items.single.title,
      );
      await repository.close();
    },
  );
}

SourceRecord _record({String title = 'Cached film'}) => SourceRecord(
  config: const SourceConfig(
    id: 'source-id',
    name: 'Personal source',
    kind: SourceKind.xtream,
    address: 'https://private.provider.test',
    username: 'ultra-secret-user',
    password: 'ultra-secret-password',
    epgUrl: 'https://private.provider.test/xmltv?token=private-token',
  ),
  catalog: SourceCatalog(
    items: [
      MediaItem(
        id: 'source-id:movie:1',
        title: title,
        kind: MediaKind.movie,
        category: 'Films',
        description: 'Private catalogue',
        year: 2026,
        durationMinutes: 90,
        palette: 0xff8b5cf6,
        subtitle: '',
        art: 0,
        sourceId: 'source-id',
        providerId: '1',
        mediaUrl: 'https://private.provider.test/movie/ultra-secret-user/ultra-secret-password/1.mp4',
      ),
    ],
  ),
  programmes: [
    EpgProgramme(
      channelId: 'channel-id',
      title: 'Programme',
      description: 'Description',
      start: DateTime.utc(2026, 11, 9, 10),
      end: DateTime.utc(2026, 11, 9, 11),
      channelAliases: ['Channel name'],
    ),
  ],
  updatedAt: DateTime.utc(2026, 11, 9, 12),
);

// Deliberately not production cryptography: this test double makes it possible
// to inspect whether the repository passes plaintext to SQLite at all.
class _OpaqueTestStore implements SecretStore {
  bool failProtect = false;
  @override
  Future<Uint8List> protect(String value) async {
    if (failProtect) throw StateError('leaked-password');
    return Uint8List.fromList([
      78,
      86,
      ...utf8.encode(value).map((byte) => byte ^ 0xa7),
    ]);
  }

  @override
  Future<String> unprotect(Uint8List value) async {
    if (value.length < 2 || value[0] != 78 || value[1] != 86) {
      throw const FormatException();
    }
    return utf8.decode(value.skip(2).map((byte) => byte ^ 0xa7).toList());
  }
}
