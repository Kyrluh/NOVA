import 'dart:convert';
import 'dart:io';

abstract interface class LocalStore {
  Future<Map<String, dynamic>> load();
  Future<void> save(Map<String, dynamic> data);
}

/// Small phase-one preference store, independent of the future SQL catalogue.
/// This file contains no source credentials or other sensitive material.
class FileLocalStore implements LocalStore {
  FileLocalStore(this.path);
  final String path;

  @override
  Future<Map<String, dynamic>> load() async {
    final file = File(path);
    final backup = File('$path.bak');
    if (!await file.exists()) {
      if (!await backup.exists()) return {};
      return _decode(await backup.readAsString());
    }
    try {
      return _decode(await file.readAsString());
    } on FormatException {
      if (await backup.exists()) return _decode(await backup.readAsString());
      rethrow;
    }
  }

  Map<String, dynamic> _decode(String content) {
    final decoded = jsonDecode(content);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Le fichier de préférences est invalide.');
    }
    return decoded;
  }

  @override
  Future<void> save(Map<String, dynamic> data) async {
    final file = File(path);
    await file.parent.create(recursive: true);
    final temp = File('$path.tmp');
    final backup = File('$path.bak');
    await temp.writeAsString(jsonEncode(data), flush: true);
    // Windows rename cannot replace an existing target. Keep a valid backup
    // during the narrow interval between moving the old and new versions.
    if (await file.exists()) {
      if (await backup.exists()) await backup.delete();
      await file.rename(backup.path);
    }
    await temp.rename(path);
  }
}

class MemoryLocalStore implements LocalStore {
  MemoryLocalStore([Map<String, dynamic>? initial])
    : data = initial == null ? {} : _copy(initial);

  Map<String, dynamic> data;

  static Map<String, dynamic> _copy(Map<String, dynamic> value) =>
      jsonDecode(jsonEncode(value)) as Map<String, dynamic>;

  @override
  Future<Map<String, dynamic>> load() async => _copy(data);

  @override
  Future<void> save(Map<String, dynamic> data) async {
    this.data = _copy(data);
  }
}
