import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart' as mobile_sqlite;

import '../domain/models.dart';
import '../domain/source_models.dart';
import 'secret_store.dart';

String _encodeRecord(SourceRecord record) => jsonEncode(record.toJson());
SourceRecord _decodeRecord(String value) =>
    SourceRecord.fromJson(jsonDecode(value) as Map<String, dynamic>);

class SourceRecord {
  const SourceRecord({
    required this.config,
    required this.catalog,
    required this.programmes,
    required this.updatedAt,
  });
  final SourceConfig config;
  final SourceCatalog catalog;
  final List<EpgProgramme> programmes;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => {
    'version': 1,
    'config': config.toJson(),
    'items': catalog.items.map((item) => item.toJson()).toList(),
    'suggestedEpgUrl': catalog.suggestedEpgUrl,
    'warnings': catalog.warnings,
    'failedKinds': catalog.failedKinds.map((kind) => kind.name).toList(),
    'programmes': programmes.map((programme) => programme.toJson()).toList(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  };

  factory SourceRecord.fromJson(Map<String, dynamic> json) {
    if (json['version'] != 1) {
      throw const FormatException('Invalid source version');
    }
    return SourceRecord(
      config: SourceConfig.fromJson(json['config'] as Map<String, dynamic>),
      catalog: SourceCatalog(
        items: (json['items'] as List)
            .map((item) => MediaItem.fromJson(item as Map<String, dynamic>))
            .toList(),
        suggestedEpgUrl: json['suggestedEpgUrl'] as String?,
        warnings:
            (json['warnings'] as List?)?.whereType<String>().toList() ??
            const [],
        failedKinds: MediaKind.values
            .where(
              (kind) => (json['failedKinds'] as List? ?? const []).contains(
                kind.name,
              ),
            )
            .toSet(),
      ),
      programmes:
          (json['programmes'] as List?)
              ?.map(
                (item) => EpgProgramme.fromJson(item as Map<String, dynamic>),
              )
              .toList() ??
          const [],
      updatedAt: DateTime.parse(json['updatedAt'] as String).toUtc(),
    );
  }

  @override
  String toString() => 'SourceRecord(${config.id})';
}

class SourceRepositoryException implements Exception {
  const SourceRepositoryException(this.message);
  final String message;
  @override
  String toString() => message;
}

abstract class SourceRepository {
  List<String> get warnings => const [];
  Future<List<SourceRecord>> readAll();
  Future<void> write(SourceRecord record);
  Future<void> delete(String id);
  Future<void> close();
}

/// Only an opaque source ID and encrypted payloads reach SQLite. Android uses
/// bounded fragments to stay below CursorWindow limits; desktop keeps v1. This
/// includes journals and WAL files: provider URLs and credentials are encrypted
/// before the first SQL operation and never used as query arguments.
class SQLiteSourceRepository extends SourceRepository {
  SQLiteSourceRepository({
    required this.path,
    required this.secrets,
    DatabaseFactory? factory,
    bool? fragmentedPayloads,
    // Keep the public injection name independent of the private field.
    // ignore: prefer_initializing_formals
  }) : _factory = factory,
       _fragmented =
           fragmentedPayloads ?? (Platform.isAndroid || Platform.isIOS) {
    if (!Platform.isAndroid && !Platform.isIOS) sqfliteFfiInit();
  }
  final String path;
  final SecretStore secrets;
  final DatabaseFactory? _factory;
  final bool _fragmented;
  Future<Database>? _opening;
  Future<void> _tail = Future<void>.value();
  bool _closed = false;
  final _warnings = <String>[];
  static const _fragmentCharacters = 48 * 1024;
  static final _chunkedMarker = Uint8List.fromList([78, 86, 67, 2]);
  @override
  List<String> get warnings => List.unmodifiable(_warnings);

  Future<Database> _database() => _opening ??=
      (_factory ??
              (Platform.isAndroid || Platform.isIOS
                  ? mobile_sqlite.databaseFactory
                  : databaseFactoryFfi))
          .openDatabase(
            path,
            options: OpenDatabaseOptions(
              // Keep the Windows on-disk format readable by earlier binaries.
              version: _fragmented ? 2 : 1,
              onConfigure: (db) async {
                await db.execute('PRAGMA secure_delete = ON');
              },
              onCreate: (db, version) async {
                await db.execute(
                  'CREATE TABLE sources (id TEXT PRIMARY KEY NOT NULL, payload BLOB NOT NULL)',
                );
                if (_fragmented) await _createChunks(db);
              },
              onUpgrade: (db, oldVersion, newVersion) async {
                if (oldVersion < 2) await _createChunks(db);
              },
            ),
          );

  static Future<void> _createChunks(DatabaseExecutor db) => db.execute(
    'CREATE TABLE source_chunks (id TEXT NOT NULL, part INTEGER NOT NULL, '
    'payload BLOB NOT NULL, PRIMARY KEY (id, part))',
  );

  static Iterable<String> _fragments(String value) sync* {
    var start = 0;
    while (start < value.length) {
      var end = (start + _fragmentCharacters).clamp(0, value.length);
      // Never cut a UTF-16 surrogate pair before native UTF-8 conversion.
      if (end < value.length &&
          value.codeUnitAt(end - 1) >= 0xd800 &&
          value.codeUnitAt(end - 1) <= 0xdbff) {
        end--;
      }
      yield value.substring(start, end);
      start = end;
    }
  }

  /// Android never needs a second complete JSON catalogue in memory just to
  /// save it. Encode one item at a time and encrypt bounded fragments directly.
  static Iterable<String> _recordPieces(SourceRecord record) sync* {
    yield '{"version":1,"config":${jsonEncode(record.config.toJson())},"items":[';
    var first = true;
    for (final item in record.catalog.items) {
      if (!first) yield ',';
      first = false;
      yield jsonEncode(item.toJson());
    }
    yield '],"suggestedEpgUrl":${jsonEncode(record.catalog.suggestedEpgUrl)},'
        '"warnings":${jsonEncode(record.catalog.warnings)},'
        '"failedKinds":${jsonEncode(record.catalog.failedKinds.map((kind) => kind.name).toList())},"programmes":[';
    first = true;
    for (final programme in record.programmes) {
      if (!first) yield ',';
      first = false;
      yield jsonEncode(programme.toJson());
    }
    yield '],"updatedAt":${jsonEncode(record.updatedAt.toUtc().toIso8601String())}}';
  }

  static Iterable<String> _recordFragments(SourceRecord record) sync* {
    var buffer = StringBuffer();
    for (final piece in _recordPieces(record)) {
      for (final fragment in _fragments(piece)) {
        if (buffer.isNotEmpty &&
            buffer.length + fragment.length > _fragmentCharacters) {
          yield buffer.toString();
          buffer = StringBuffer();
        }
        buffer.write(fragment);
      }
    }
    if (buffer.isNotEmpty) yield buffer.toString();
  }

  Future<String> _readPayload(Database db, String id) async {
    if (!_fragmented) return _readLegacyPayload(db, id);
    final countRows = await db.rawQuery(
      'SELECT COUNT(*) AS amount FROM source_chunks WHERE id = ?',
      [id],
    );
    final count = countRows.single['amount'] as int;
    if (count == 0) {
      // Version-one Windows databases remain readable, without rewriting their
      // protected records until the next explicit catalogue update.
      return _readLegacyPayload(db, id);
    }
    final plaintext = StringBuffer();
    for (var part = 0; part < count; part++) {
      final rows = await db.query(
        'source_chunks',
        columns: ['payload'],
        where: 'id = ? AND part = ?',
        whereArgs: [id, part],
        limit: 1,
      );
      if (rows.length != 1 || rows.single['payload'] is! Uint8List) {
        throw const FormatException();
      }
      plaintext.write(
        await secrets.unprotect(rows.single['payload'] as Uint8List),
      );
    }
    return plaintext.toString();
  }

  Future<String> _readLegacyPayload(Database db, String id) async {
    final rows = await db.query(
      'sources',
      columns: ['payload'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    final value = rows.single['payload'];
    if (value is! Uint8List) throw const FormatException();
    return secrets.unprotect(value);
  }

  Future<T> _serial<T>(Future<T> Function() work) {
    if (_closed) {
      return Future.error(
        const SourceRepositoryException('Le stockage des sources est fermé.'),
      );
    }
    final result = _tail.then((_) => work());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  @override
  Future<List<SourceRecord>> readAll() => _serial(() async {
    _warnings.clear();
    try {
      final db = await _database();
      final rows = await db.query(
        'sources',
        columns: ['id'],
        orderBy: 'rowid ASC',
      );
      final records = <SourceRecord>[];
      for (final row in rows) {
        try {
          final plaintext = await _readPayload(db, row['id'] as String);
          final record = await compute(_decodeRecord, plaintext);
          if (record.config.id != row['id']) throw const FormatException();
          records.add(record);
        } catch (_) {
          _warnings.add(
            'Une source enregistrée ne peut pas être déverrouillée. Les autres sources restent disponibles ; réimportez la source concernée.',
          );
        }
      }
      return records;
    } catch (_) {
      throw const SourceRepositoryException(
        'Impossible de lire le cache local des sources. Vérifiez les droits d’écriture et l’espace disponible.',
      );
    }
  });

  @override
  Future<void> write(SourceRecord record) => _serial(() async {
    try {
      if (!_fragmented) {
        final plaintext = await compute(_encodeRecord, record);
        final payload = await secrets.protect(plaintext);
        await (await _database()).insert('sources', {
          'id': record.config.id,
          'payload': payload,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
        return;
      }
      await (await _database()).transaction((transaction) async {
        await transaction.delete(
          'source_chunks',
          where: 'id = ?',
          whereArgs: [record.config.id],
        );
        await transaction.insert('sources', {
          'id': record.config.id,
          'payload': _chunkedMarker,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
        var part = 0;
        for (final fragment in _recordFragments(record)) {
          final payload = await secrets.protect(fragment);
          await transaction.insert('source_chunks', {
            'id': record.config.id,
            'part': part++,
            'payload': payload,
          });
        }
      });
    } catch (_) {
      throw const SourceRepositoryException(
        'La sauvegarde protégée de la source a échoué. Vérifiez les droits d’écriture et l’espace disponible.',
      );
    }
  });

  @override
  Future<void> delete(String id) => _serial(() async {
    try {
      await (await _database()).transaction((transaction) async {
        if (_fragmented) {
          await transaction.delete(
            'source_chunks',
            where: 'id = ?',
            whereArgs: [id],
          );
        }
        await transaction.delete('sources', where: 'id = ?', whereArgs: [id]);
      });
    } catch (_) {
      throw const SourceRepositoryException(
        'La source n’a pas pu être supprimée du stockage local.',
      );
    }
  });

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _tail;
    if (_opening != null) await (await _opening!).close();
  }
}

/// In-memory repository for isolated tests and ephemeral previews only.
class MemorySourceRepository extends SourceRepository {
  MemorySourceRepository([List<SourceRecord> initial = const []]) {
    for (final record in initial) {
      _records[record.config.id] = record;
    }
  }
  final Map<String, SourceRecord> _records = {};
  @override
  Future<List<SourceRecord>> readAll() async => _records.values.toList();
  @override
  Future<void> write(SourceRecord record) async {
    _records[record.config.id] = record;
  }

  @override
  Future<void> delete(String id) async {
    _records.remove(id);
  }

  @override
  Future<void> close() async {}
}
