import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_iptv/data/local_store.dart';
import 'package:nova_iptv/data/source_repository.dart';
import 'package:nova_iptv/domain/models.dart';
import 'package:nova_iptv/domain/source_models.dart';
import 'package:nova_iptv/sources/iptv_client.dart';
import 'package:nova_iptv/state/app_controller.dart';
import 'package:nova_iptv/state/source_controller.dart';
import 'package:nova_iptv/ui/widgets/live_guide_hud.dart';

void main() {
  testWidgets(
    'Automatic guide switches channel while its shared request loads',
    (tester) async {
      final client = _GuideClient();
      final channels = [
        for (final id in ['one', 'two'])
          MediaItem(
            id: id,
            title: id,
            kind: MediaKind.live,
            sourceId: 'guide',
            tvgId: id,
            mediaUrl: 'https://example.test/$id.ts',
            category: 'Test',
            description: '',
            year: 0,
            durationMinutes: 0,
            palette: 0xff333333,
            subtitle: '',
            art: 0,
          ),
      ];
      final sources = SourceController(
        client: client,
        repository: MemorySourceRepository([
          SourceRecord(
            config: const SourceConfig(
              id: 'guide',
              name: 'Fixture',
              kind: SourceKind.xtream,
              address: 'https://example.test',
              username: 'fixture',
              password: 'fixture',
            ),
            catalog: SourceCatalog(items: channels),
            programmes: const [],
            updatedAt: DateTime.now(),
          ),
        ]),
      );
      final app = AppController(store: MemoryLocalStore(), sources: sources);
      await app.init();
      Widget hud(int index) => MaterialApp(
        home: Scaffold(
          body: LiveGuideHud(controller: app, channel: channels[index]),
        ),
      );
      await tester.pumpWidget(hud(0));
      await tester.pump();
      expect(find.text('Chargement du guide TV…'), findsOneWidget);
      await tester.pumpWidget(hud(1));
      await tester.pump();
      final now = DateTime.now();
      client.result.complete([
        for (final id in ['one', 'two']) ...[
          EpgProgramme(
            channelId: id,
            title: 'Current $id',
            description: '',
            start: now.subtract(const Duration(minutes: 20)),
            end: now.add(const Duration(minutes: 20)),
          ),
          EpgProgramme(
            channelId: id,
            title: 'Next $id',
            description: '',
            start: now.add(const Duration(minutes: 20)),
            end: now.add(const Duration(minutes: 50)),
          ),
        ],
      ]);
      await tester.pumpAndSettle();
      expect(find.textContaining('Current two'), findsOneWidget);
      expect(find.textContaining('Next two'), findsOneWidget);
      expect(find.textContaining('Current one'), findsNothing);
      expect(client.calls, 1);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      app.dispose();
      sources.dispose();
    },
  );
}

class _GuideClient extends IptvClient {
  int calls = 0;
  final result = Completer<List<EpgProgramme>>();
  @override
  Future<List<EpgProgramme>> loadEpg(
    SourceConfig config, {
    CancellationToken? cancel,
  }) {
    calls++;
    return result.future;
  }
}
