import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_iptv/data/secret_store.dart';
import 'package:nova_iptv/data/source_repository.dart';
import 'package:nova_iptv/domain/models.dart';
import 'package:nova_iptv/domain/source_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Android detail updates encrypt only one item and survive restart and refresh', () async {
    final folder = await Directory.systemTemp.createTemp('nova-details-');
    addTearDown(() => folder.delete(recursive: true));
    final path = '${folder.path}/cache.sqlite';
    final secrets = _TestSecrets();
    var repo = SQLiteSourceRepository(
      path: path,
      secrets: secrets,
      factory: databaseFactoryFfiNoIsolate,
      fragmentedPayloads: true,
    );
    final original = _record('delta', 1000);
    await repo.write(original);
    final fullWrites = secrets.calls;
    secrets.calls = 0;
    final detail = original.catalog.items.first.copyWith(
      description: 'Synopsis privé 👩‍🚀',
      detailsLoaded: true,
    );
    await repo.writeDetails(_detailRecord(original, detail), detail);
    expect(fullWrites, greaterThan(20));
    expect(
      secrets.calls,
      1,
      reason: 'Opening one synopsis must not encrypt the whole catalogue',
    );
    await repo.close();
    repo = SQLiteSourceRepository(
      path: path,
      secrets: secrets,
      factory: databaseFactoryFfiNoIsolate,
      fragmentedPayloads: true,
    );
    final restored = (await repo.readAll()).single;
    expect(restored.catalog.items, hasLength(1000));
    expect(restored.catalog.items.first.description, detail.description);
    expect(restored.catalog.items.first.detailsLoaded, isTrue);
    expect(
      restored.catalog.items.last.toJson(),
      original.catalog.items.last.toJson(),
    );
    await repo.write(original);
    expect(
      (await repo.readAll()).single.catalog.items.first.description,
      original.catalog.items.first.description,
    );
    await repo.writeDetails(_detailRecord(original, detail), detail);
    await repo.delete(original.config.id);
    expect(await repo.readAll(), isEmpty);
    await repo.close();
  });
  test(
    'Android detail fragments roll back atomically and preserve Unicode',
    () async {
      final folder = await Directory.systemTemp.createTemp(
        'nova-detail-rollback-',
      );
      addTearDown(() => folder.delete(recursive: true));
      final secrets = _TestSecrets();
      final repo = SQLiteSourceRepository(
        path: '${folder.path}/cache.sqlite',
        secrets: secrets,
        factory: databaseFactoryFfiNoIsolate,
        fragmentedPayloads: true,
      );
      final base = _record('delta', 1);
      await repo.write(base);
      final detail = base.catalog.items.first.copyWith(
        description: List.filled(20000, 'Été 👩‍🚀 中文').join(),
        detailsLoaded: true,
      );
      await repo.writeDetails(_detailRecord(base, detail), detail);
      expect(
        (await repo.readAll()).single.catalog.items.first.description,
        detail.description,
      );
      expect(secrets.longestPlaintext, lessThanOrEqualTo(48 * 1024));
      secrets.calls = 0;
      secrets.failAt = 2;
      final broken = detail.copyWith(
        description: detail.description.replaceAll('Été', 'Fin'),
      );
      await expectLater(
        repo.writeDetails(_detailRecord(base, broken), broken),
        throwsA(isA<SourceRepositoryException>()),
      );
      expect(
        (await repo.readAll()).single.catalog.items.first.description,
        detail.description,
      );
      await repo.close();
    },
  );

  test(
    'Desktop keeps version-one payloads readable by earlier Windows binaries',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'nova-desktop-v1-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final path = '${directory.path}${Platform.pathSeparator}cache.sqlite';
      final secrets = _TestSecrets();
      final repository = SQLiteSourceRepository(
        path: path,
        secrets: secrets,
        factory: databaseFactoryFfiNoIsolate,
      );
      await repository.write(_record('desktop', 1));
      await repository.close();
      final legacy = await databaseFactoryFfiNoIsolate.openDatabase(
        path,
        options: OpenDatabaseOptions(version: 1),
      );
      final raw =
          (await legacy.query('sources')).single['payload'] as Uint8List;
      expect(
        (jsonDecode(await secrets.unprotect(raw)) as Map)['config']['id'],
        'desktop',
      );
      expect(
        await legacy.rawQuery(
          "SELECT name FROM sqlite_master WHERE name = 'source_chunks'",
        ),
        isEmpty,
      );
      await legacy.close();
    },
    skip: Platform.isAndroid || Platform.isIOS,
  );

  test('Android playback preferences preserve compatible defaults and validate reconnect bounds', () {
    final defaults = AppSettings.fromJson({});
    expect(defaults.touchGestures, isTrue);
    expect(defaults.brightnessGestures, isTrue);
    expect(defaults.volumeGestures, isTrue);
    expect(defaults.seekGestures, isTrue);
    expect(defaults.pictureInPicture, isTrue);
    expect(defaults.landscapeFullscreen, isTrue);
    final configured = defaults.copyWith(
      touchGestures: false,
      brightnessGestures: false,
      volumeGestures: false,
      seekGestures: false,
      reconnectEnabled: false,
      reconnectAttempts: 100,
      reconnectDelaySeconds: -3,
      pictureInPicture: false,
      landscapeFullscreen: false,
    );
    final restored = AppSettings.fromJson(configured.toJson());
    expect(restored.reconnectAttempts, 10);
    expect(restored.reconnectDelaySeconds, 1);
    expect(restored.touchGestures, isFalse);
    expect(restored.brightnessGestures, isFalse);
    expect(restored.volumeGestures, isFalse);
    expect(restored.seekGestures, isFalse);
    expect(restored.reconnectEnabled, isFalse);
    expect(restored.pictureInPicture, isFalse);
    expect(restored.landscapeFullscreen, isFalse);
    expect(
      AppSettings.fromJson({'reconnectAttempts': 'ten'}).reconnectAttempts,
      3,
    );
  });

  test(
    'Android SecretStore sends typed fragments and sanitizes native errors',
    () async {
      const channel = MethodChannel('nova/android');
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            if (call.method == 'protect') {
              return Uint8List.fromList([
                1,
                ...utf8.encode(call.arguments as String),
              ]);
            }
            return utf8.decode((call.arguments as Uint8List).skip(1).toList());
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      const store = AndroidKeystoreSecretStore();
      final protected = await store.protect('Texte privé 👩‍🚀');
      expect(await store.unprotect(protected), 'Texte privé 👩‍🚀');
      expect(calls.map((c) => c.method), ['protect', 'unprotect']);
      expect(calls.last.arguments, isA<Uint8List>());
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) async {
            throw PlatformException(
              code: 'invalid',
              message: 'private-password',
            );
          });
      await expectLater(
        store.protect('private-password'),
        throwsA(
          isA<SecretStoreException>().having(
            (e) => e.message,
            'safe native error',
            isNot(contains('private-password')),
          ),
        ),
      );
    },
  );

  test('Legacy version-one encrypted records migrate without rewriting their payload', () async {
    sqfliteFfiInit();
    final directory = await Directory.systemTemp.createTemp(
      'nova-legacy-cache-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final path = '${directory.path}${Platform.pathSeparator}cache.sqlite';
    final secrets = _TestSecrets();
    final original = _record('legacy', 1);
    final payload = await secrets.protect(jsonEncode(original.toJson()));
    final legacy = await databaseFactoryFfiNoIsolate.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) => db.execute(
          'CREATE TABLE sources (id TEXT PRIMARY KEY NOT NULL, payload BLOB NOT NULL)',
        ),
      ),
    );
    await legacy.insert('sources', {
      'id': original.config.id,
      'payload': payload,
    });
    await legacy.close();
    final repository = SQLiteSourceRepository(
      path: path,
      secrets: secrets,
      factory: databaseFactoryFfiNoIsolate,
      fragmentedPayloads: true,
    );
    expect(
      (await repository.readAll()).single.catalog.items.single.title,
      original.catalog.items.single.title,
    );
    final raw = await databaseFactoryFfiNoIsolate.openDatabase(
      path,
      options: OpenDatabaseOptions(singleInstance: false),
    );
    expect((await raw.query('source_chunks')), isEmpty);
    expect((await raw.query('sources')).single['payload'], payload);
    await raw.close();
    await repository.write(original);
    expect((await repository.readAll()).single.config.id, 'legacy');
    await repository.close();
  });

  test('Large catalogues use bounded encrypted fragments and preserve Unicode on restore', () async {
    final directory = await Directory.systemTemp.createTemp(
      'nova-mobile-fragments-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final path = '${directory.path}${Platform.pathSeparator}cache.sqlite';
    final original = _record('large', 2500);
    final secrets = _TestSecrets();
    final repository = SQLiteSourceRepository(
      path: path,
      secrets: secrets,
      factory: databaseFactoryFfiNoIsolate,
      fragmentedPayloads: true,
    );
    await repository.write(original);
    final raw = await databaseFactoryFfiNoIsolate.openDatabase(
      path,
      options: OpenDatabaseOptions(singleInstance: false),
    );
    final sizes = await raw.rawQuery(
      'SELECT COUNT(*) AS amount, MAX(length(payload)) AS maximum FROM source_chunks',
    );
    expect(sizes.single['amount'] as int, greaterThan(20));
    expect(sizes.single['maximum'] as int, lessThan(200 * 1024));
    final restored = (await repository.readAll()).single;
    expect(restored.toJson(), original.toJson());
    expect(restored.catalog.items, hasLength(2500));
    expect(
      restored.catalog.items.last.description,
      original.catalog.items.last.description,
    );
    expect(
      restored.catalog.items.last.title,
      original.catalog.items.last.title,
    );
    expect(secrets.longestPlaintext, lessThanOrEqualTo(48 * 1024));
    await repository.delete('large');
    expect(await raw.query('source_chunks'), isEmpty);
    await raw.close();
    await repository.close();
  });

  test(
    'A failed middle fragment rolls back to the previous catalogue',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'nova-fragment-rollback-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final secrets = _TestSecrets();
      final repository = SQLiteSourceRepository(
        path: '${directory.path}${Platform.pathSeparator}cache.sqlite',
        secrets: secrets,
        factory: databaseFactoryFfiNoIsolate,
        fragmentedPayloads: true,
      );
      await repository.write(_record('stable', 1));
      secrets.calls = 0;
      secrets.failAt = 3;
      await expectLater(
        repository.write(_record('stable', 200)),
        throwsA(isA<SourceRepositoryException>()),
      );
      expect((await repository.readAll()).single.catalog.items, hasLength(1));
      await repository.close();
    },
  );
}

SourceRecord _detailRecord(SourceRecord original, MediaItem detail) =>
    SourceRecord(
      config: original.config,
      catalog: SourceCatalog(
        items: [detail, ...original.catalog.items.skip(1)],
      ),
      programmes: original.programmes,
      updatedAt: original.updatedAt,
    );

SourceRecord _record(String id, int amount) => SourceRecord(
  config: SourceConfig(
    id: id,
    name: 'Source de test',
    kind: SourceKind.m3uUrl,
    address: 'https://example.test/private-token',
  ),
  catalog: SourceCatalog(
    items: [
      for (var i = 0; i < amount; i++)
        MediaItem(
          id: '$id-$i',
          title: 'Émission 👩‍🚀 中文 $i',
          kind: MediaKind.movie,
          category: 'FR | Films',
          description: List.filled(36, 'Texte accentué 👩‍🚀 中文').join(' '),
          year: 2026,
          durationMinutes: 100,
          palette: 0xff8b5cf6,
          subtitle: '',
          art: 0,
          sourceId: id,
          mediaUrl: 'https://example.test/private-token/$i.mp4',
        ),
    ],
  ),
  programmes: const [],
  updatedAt: DateTime.utc(2026, 11, 9),
);

class _TestSecrets implements SecretStore {
  int longestPlaintext = 0;
  int calls = 0;
  int? failAt;
  @override
  Future<Uint8List> protect(String value) async {
    calls++;
    if (calls == failAt) throw StateError('Test failure');
    longestPlaintext = value.length > longestPlaintext
        ? value.length
        : longestPlaintext;
    return Uint8List.fromList([
      78,
      86,
      ...utf8.encode(value).map((b) => b ^ 0x83),
    ]);
  }

  @override
  Future<String> unprotect(Uint8List value) async =>
      utf8.decode(value.skip(2).map((b) => b ^ 0x83).toList());
}
