import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nova_iptv/data/local_store.dart';
import 'package:nova_iptv/domain/models.dart';
import 'package:nova_iptv/domain/platform_catalog.dart';
import 'package:nova_iptv/state/internet_catalog_controller.dart';

void main() {
  test(
    'Live keyless public metadata endpoints, no IPTV source opened',
    () async {
      final api = InternetCatalogController(
        store: FileLocalStore('.tools/public-catalog-smoke-cache.json'),
      );
      addTearDown(api.dispose);
      await api.init();
      await api.refresh();
      final summary = {
        'checkedAtUtc': DateTime.now().toUtc().toIso8601String(),
        'message': api.message,
        'trendingMovies': api.trending(MediaKind.movie).length,
        'trendingSeries': api.trending(MediaKind.series).length,
        'platformSelections': {
          for (final platform in CatalogPlatform.values)
            platform.name: api.selection(platform).length,
        },
      };
      await File('.tools/public-catalog-smoke-results.json')
          .writeAsString(const JsonEncoder.withIndent('  ').convert(summary));
      // Report counts only. No provider accounts, source URLs or playback.
      // ignore: avoid_print
      print(jsonEncode(summary));
      expect(api.running, isFalse);
      expect(api.trending(MediaKind.movie), isNotEmpty);
      expect(api.trending(MediaKind.series), isNotEmpty);
      expect(
        CatalogPlatform.values.any((p) => api.selection(p).isNotEmpty),
        isTrue,
      );
    },
    timeout: const Timeout(Duration(seconds: 90)),
  );
}
