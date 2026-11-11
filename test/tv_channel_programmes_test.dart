import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_iptv/player/tv_channel_panel.dart';

const channels = [
  TvChannelOption(id: 'a1', title: 'TF1 HD', category: 'France'),
  TvChannelOption(id: 'a2', title: 'France 2 HD', category: 'France'),
  TvChannelOption(id: 'b1', title: 'Documentaires', category: 'Découverte'),
];

void main() {
  testWidgets('Programme updates keep the browsed channel and do not tune it', (
    tester,
  ) async {
    final updates = ValueNotifier<int>(0);
    addTearDown(updates.dispose);
    final programmes = <String, String>{'a1': 'Le journal', 'a2': 'Un film'};
    String? tuned;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 380,
            child: TvChannelPanel(
              channels: channels,
              selectedId: 'a1',
              programmeFor: (id) => programmes[id],
              guideChanges: updates,
              onSelected: (id) => tuned = id,
              onClose: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final title = tester.getRect(find.text('TF1 HD'));
    final guide = tester.getRect(find.text('Le journal'));
    expect(guide.top, greaterThanOrEqualTo(title.bottom));
    expect(
      tester.widget<Text>(find.text('Le journal')).style!.fontSize,
      lessThan(tester.widget<Text>(find.text('TF1 HD')).style!.fontSize!),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    programmes['a2'] = 'Le programme suivant';
    updates.value++;
    await tester.pumpAndSettle();
    expect(find.text('Le programme suivant'), findsOneWidget);
    expect(tuned, isNull);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    expect(tuned, 'a2');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Category programmes are requested before selecting a channel', (
    tester,
  ) async {
    final requested = <String>[];
    String? tuned;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TvChannelPanel(
            channels: channels,
            selectedId: 'a1',
            programmeFor: (id) => id == 'b1' ? 'La forêt' : null,
            onGuideRequested: requested.add,
            onSelected: (id) => tuned = id,
            onClose: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Programme indisponible'), findsNWidgets(2));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(requested, contains('b1'));
    expect(find.text('La forêt'), findsOneWidget);
    expect(tuned, isNull);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(tuned, 'b1');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Long titles and enlarged text retain scrolling and source order', (
    tester,
  ) async {
    String? tuned;
    final many = [
      for (var i = 0; i < 30; i++)
        TvChannelOption(
          id: '$i',
          title: 'Chaîne $i avec un très long nom de fournisseur',
          category: 'France',
        ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(800, 600),
            textScaler: TextScaler.linear(2),
          ),
          child: Scaffold(
            body: SizedBox(
              width: 360,
              child: TvChannelPanel(
                channels: many,
                selectedId: '0',
                programmeFor: (id) =>
                    'Programme actuel de la chaîne $id avec une très longue description',
                onSelected: (id) => tuned = id,
                onClose: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (var i = 0; i < 12; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
    }
    expect(
      find.byKey(const ValueKey('panel-programme-12')).hitTestable(),
      findsOneWidget,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    expect(tuned, '12');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
