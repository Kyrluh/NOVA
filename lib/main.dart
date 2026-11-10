import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:path_provider/path_provider.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'data/local_store.dart';
import 'data/source_repository.dart';
import 'data/secret_store.dart';
import 'sources/iptv_client.dart';
import 'state/app_controller.dart';
import 'state/source_controller.dart';
import 'state/internet_catalog_controller.dart';
import 'player/android_video_environment.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isAndroid) await AndroidVideoEnvironment.initialize();
  if (Platform.isWindows) {
    await windowManager.ensureInitialized();
    await windowManager.waitUntilReadyToShow(
      const WindowOptions(
        size: Size(1440, 900),
        minimumSize: Size(1000, 680),
        center: true,
        title: 'NOVA IPTV',
        backgroundColor: Color(0xFF0B0D12),
      ),
      () async {
        await windowManager.show();
        await windowManager.focus();
      },
    );
  }
  var nativeReady = true;
  try {
    MediaKit.ensureInitialized();
  } catch (_) {
    nativeReady = false;
  }
  LocalStore store;
  SourceRepository repository;
  LocalStore internetStore;
  try {
    final folder = await getApplicationSupportDirectory();
    store = FileLocalStore(
      '${folder.path}${Platform.pathSeparator}preferences.json',
    );
    internetStore = FileLocalStore(
      '${folder.path}${Platform.pathSeparator}internet-catalogs.json',
    );
    repository = SQLiteSourceRepository(
      path: '${folder.path}${Platform.pathSeparator}sources.sqlite',
      secrets: Platform.isAndroid
          ? const AndroidKeystoreSecretStore()
          : const DpapiSecretStore(),
    );
  } catch (_) {
    store = _UnavailableStore();
    repository = _UnavailableSourceRepository();
    internetStore = _UnavailableStore();
  }
  final controller = AppController(
    refreshSourcesOnStartup: true,
    store: store,
    internetCatalog: InternetCatalogController(store: internetStore),
    sources: SourceController(repository: repository, client: IptvClient()),
  );
  runApp(
    NovaApp(
      controller: controller,
      nativeReady: nativeReady,
      manageWindow: Platform.isWindows,
    ),
  );
  unawaited(controller.init());
}

class _UnavailableSourceRepository extends SourceRepository {
  @override
  Future<List<SourceRecord>> readAll() async =>
      throw const SourceRepositoryException(
        'Le stockage des sources est indisponible.',
      );
  @override
  Future<void> write(SourceRecord record) async =>
      throw const SourceRepositoryException(
        'Le stockage des sources est indisponible.',
      );
  @override
  Future<void> delete(String id) async => throw const SourceRepositoryException(
    'Le stockage des sources est indisponible.',
  );
  @override
  Future<void> close() async {}
}

class _UnavailableStore implements LocalStore {
  @override
  Future<Map<String, dynamic>> load() async =>
      throw const FileSystemException('Local storage unavailable');
  @override
  Future<void> save(Map<String, dynamic> data) async =>
      throw const FileSystemException('Local storage unavailable');
}
