import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_iptv/data/local_store.dart';
import 'package:nova_iptv/domain/models.dart';
import 'package:nova_iptv/state/app_controller.dart';
import 'package:nova_iptv/ui/pages/catalog_page.dart';

void main() {
  testWidgets(
    'Resume removal undo restores the item and a second notice expires automatically',
    (tester) async {
      final app = AppController(store: MemoryLocalStore());
      await app.init();
      final item = app.itemById('film-orbite')!;
      app.recordProgress(
        item.id,
        WatchProgress(
          positionSeconds: 100,
          durationSeconds: 5000,
          lastWatched: DateTime.utc(2026),
        ),
      );
      await app.flush();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 190,
                height: 320,
                child: MediaPoster(controller: app, item: item, onTap: () {}),
              ),
            ),
          ),
        ),
      );
      Future<void> remove() async {
        await tester.tap(
          find.byType(MediaPoster),
          buttons: kSecondaryMouseButton,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Supprimer de Continuer à regarder'));
        await tester.pumpAndSettle();
      }

      await remove();
      expect(app.canResume(item), isFalse);
      expect(tester.widget<SnackBar>(find.byType(SnackBar)).persist, isFalse);
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();
      expect(app.canResume(item), isTrue);
      await remove();
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing);
      expect(app.canResume(item), isFalse);
      await tester.pumpWidget(const SizedBox());
      app.dispose();
    },
  );
}
