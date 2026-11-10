import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nova_iptv/data/demo_catalog.dart';
import 'package:nova_iptv/domain/models.dart';
import 'package:nova_iptv/sources/public_catalog_client.dart';

Map<String, dynamic> publicCatalogFixture(Uri uri) {
  final kind = uri.path.contains('/movie/')
      ? MediaKind.movie
      : MediaKind.series;
  final isNetflix =
      uri.path.endsWith('/nfx.json') || uri.host == 'v3-cinemeta.strem.io';
  final item = kind == MediaKind.movie
      ? demoCatalog.first
      : demoCatalog.firstWhere((i) => i.kind == MediaKind.series);
  return {
    'metas': [
      {
        'id': isNetflix
            ? (kind == MediaKind.movie ? 'tt10000001' : 'tt10000002')
            : 'tt10000003',
        'type': kind.name,
        'name': isNetflix ? item.title : 'Autre création originale',
        'releaseInfo': '${item.year}',
        'description': 'Synopsis original de test.',
      },
    ],
  };
}

PublicCatalogClient fixtureClient({
  Future<http.Response> Function(http.Request)? handler,
}) => PublicCatalogClient(
  client: MockClient(
    handler ?? (request) async => fixtureResponse(request.url),
  ),
);

http.Response fixtureResponse(Uri uri) => http.Response(
  jsonEncode(publicCatalogFixture(uri)),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);
