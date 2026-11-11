import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_iptv/ui/widgets/search_field.dart';
import 'package:nova_iptv/player/seek_coordinator.dart';

void main() {
  testWidgets(
    'TV search opens only on OK and arrows leave it after native back or validation',
    (tester) async {
      final controller = TextEditingController();
      final calls = <MethodCall>[];
      const channel = MethodChannel('nova/android');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        calls.add(call);
        return calls.length == 1 ? 'Mon titre' : null;
      });
      addTearDown(() {
        controller.dispose();
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        );
      });
      var query = '';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                TextButton(onPressed: () {}, child: const Text('Avant')),
                NovaSearchField(
                  television: true,
                  autofocus: true,
                  controller: controller,
                  decoration: const InputDecoration(labelText: 'Recherche'),
                  onChanged: (value) => query = value,
                ),
                TextButton(onPressed: () {}, child: const Text('Après')),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(calls, isEmpty);
      expect(find.byType(EditableText), findsNothing);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(Focus.of(tester.element(find.text('Après'))).hasFocus, isTrue);
      expect(calls, isEmpty);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();
      expect(calls.single.method, 'editSourceText');
      expect((calls.single.arguments as Map)['search'], isTrue);
      expect(query, 'Mon titre');
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();
      expect(query, 'Mon titre');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(Focus.of(tester.element(find.text('Après'))).hasFocus, isTrue);
      expect(calls, hasLength(2));
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'Seek requests keep only latest target while native seek is busy and reset cancels pending work',
    (tester) async {
      final calls = <Duration>[];
      final first = Completer<void>();
      final queue = SeekCoordinator(
        seek: (value) async {
          calls.add(value);
          if (calls.length == 1) await first.future;
        },
        changed: () {},
      );
      addTearDown(queue.dispose);
      queue.request(const Duration(seconds: 10));
      final operation = queue.flush();
      queue.request(const Duration(seconds: 20));
      queue.request(const Duration(seconds: 60));
      expect(calls, [const Duration(seconds: 10)]);
      first.complete();
      await operation;
      await tester.pump();
      expect(calls, [const Duration(seconds: 10), const Duration(seconds: 60)]);
      queue.request(const Duration(seconds: 90));
      queue.reset();
      await tester.pump(const Duration(seconds: 1));
      expect(calls, hasLength(2));
      expect(queue.target, isNull);
    },
  );
}
