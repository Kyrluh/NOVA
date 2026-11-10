import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_iptv/domain/source_models.dart';
import 'package:nova_iptv/state/source_controller.dart';
import 'package:nova_iptv/ui/pages/sources_page.dart';
import 'package:nova_iptv/ui/theme.dart';

void main() {
  testWidgets(
    'Kyrlu preset and custom password apply only to default-first Xtream',
    (tester) async {
      final controller = _FakeSources();
      await _start(tester, controller);
      await tester.tap(find.byKey(const Key('add-source')));
      await tester.pumpAndSettle();
      final kind = tester.widget<DropdownButtonFormField<SourceKind>>(
        find.byType(DropdownButtonFormField<SourceKind>),
      );
      expect(kind.initialValue, SourceKind.xtream);
      expect(
        tester
            .widget<DropdownButton<SourceKind>>(
              find.byType(DropdownButton<SourceKind>),
            )
            .items!
            .first
            .value,
        SourceKind.xtream,
      );
      tester
          .widget<DropdownButtonFormField<String>>(
            find.byKey(const Key('source-provider')),
          )
          .onChanged!('kyrlu');
      await tester.pumpAndSettle();
      expect(find.text('MDP prédéfini'), findsOneWidget);
      expect(find.byKey(const Key('source-password')), findsNothing);
      await _enter(tester, 'source-name', 'Kyrlu');
      await _enter(tester, 'source-address', 'https://example.test');
      await _enter(tester, 'source-username', 'fixture-user');
      final testButton = find.widgetWithText(
        OutlinedButton,
        'Tester la connexion',
      );
      await tester.tap(testButton);
      await tester.pumpAndSettle();
      expect(controller.tested.last.password, 'fixture-preset');
      expect(controller.tested.last.provider, 'kyrlu');
      expect(controller.tested.last.usePresetPassword, isTrue);
      final config = SourceConfig.fromDraft('fixture', controller.tested.last);
      expect(
        SourceConfig.fromJson(config.toJson())
            .copyWith(epgUrl: '')
            .draft
            .usePresetPassword,
        isTrue,
      );

      tester
          .widget<DropdownButtonFormField<bool>>(
            find.byType(DropdownButtonFormField<bool>),
          )
          .onChanged!(false);
      await tester.pumpAndSettle();
      await _enter(tester, 'source-password', 'fixture-custom');
      await tester.tap(testButton);
      await tester.pumpAndSettle();
      expect(controller.tested.last.password, 'fixture-custom');
      expect(controller.tested.last.usePresetPassword, isFalse);

      await _selectKind(tester, 'Playlist M3U • URL');
      expect(find.byKey(const Key('source-provider')), findsNothing);
      expect(find.byKey(const Key('source-password')), findsNothing);
      await tester.tap(testButton);
      await tester.pumpAndSettle();
      expect(controller.tested.last.password, isEmpty);
      expect(controller.tested.last.username, isEmpty);
      expect(controller.tested.last.usePresetPassword, isFalse);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'TV remote M3U keyboard next skips hidden credentials and done focuses Add',
    (tester) async {
      final controller = _FakeSources();
      await _start(tester, controller);
      await tester.tap(find.byKey(const Key('add-source')));
      await tester.pumpAndSettle();
      await _selectKind(tester, 'Playlist M3U • URL');
      await _enter(tester, 'source-name', 'TV');
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pumpAndSettle();
      expect(_fieldFocused(tester, 'source-address'), isTrue);
      await tester.enterText(
        find.byKey(const Key('source-address')),
        'https://example.test/list.m3u',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(_fieldFocused(tester, 'source-epg'), isTrue);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('save-source')))
            .focusNode!
            .hasFocus,
        isTrue,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();
      expect(controller.saved.single.name, 'TV');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'TV remote arrows traverse Xtream fields with keyboard closed and keep text intact',
    (tester) async {
      final controller = _FakeSources();
      await _start(tester, controller);
      await tester.tap(find.byKey(const Key('add-source')));
      await tester.pumpAndSettle();
      await _selectKind(tester, 'Xtream Codes');
      await _enter(tester, 'source-name', 'TV Xtream');
      tester.testTextInput.hide();
      for (final field in [
        'source-address',
        'source-username',
        'source-password',
        'source-epg',
      ]) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
        expect(_fieldFocused(tester, field), isTrue);
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      expect(_fieldFocused(tester, 'source-password'), isTrue);
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('source-name')))
            .controller!
            .text,
        'TV Xtream',
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'M3U form validates, tests without saving and imports its guide',
    (tester) async {
      final controller = _FakeSources();
      await _start(tester, controller);
      expect(find.text('Aucune source ajoutée'), findsOneWidget);
      await tester.tap(find.byKey(const Key('add-source')));
      await tester.pumpAndSettle();
      await _selectKind(tester, 'Playlist M3U • URL');
      await tester.tap(find.byKey(const Key('save-source')));
      await tester.pumpAndSettle();
      expect(find.text('Donnez un nom à cette source.'), findsOneWidget);
      expect(
        find.text('Saisissez une adresse HTTP ou HTTPS valide.'),
        findsOneWidget,
      );
      expect(controller.saved, isEmpty);

      await _enter(tester, 'source-name', 'Ma playlist');
      await _enter(
        tester,
        'source-address',
        'https://example.test/private.m3u?token=never-show',
      );
      await _enter(tester, 'source-epg', 'not-a-url');
      await tester.tap(find.byKey(const Key('save-source')));
      await tester.pumpAndSettle();
      expect(controller.saved, isEmpty);
      await _enter(tester, 'source-epg', 'https://example.test/guide.xml');
      await tester.tap(
        find.widgetWithText(OutlinedButton, 'Tester la connexion'),
      );
      await tester.pumpAndSettle();
      expect(controller.tested, hasLength(1));
      expect(
        controller.saved,
        isEmpty,
        reason: 'Testing must not save a source.',
      );
      expect(find.text('Connexion réussie.'), findsOneWidget);
      await tester.tap(find.byKey(const Key('save-source')));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
      expect(controller.saved.single.kind, SourceKind.m3uUrl);
      expect(controller.saved.single.epgUrl, 'https://example.test/guide.xml');
      expect(find.text('Ma playlist'), findsOneWidget);
      expect(
        find.textContaining('never-show'),
        findsNothing,
        reason: 'Source cards must not display private URLs.',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Xtream credentials stay in the form and deletion needs confirmation',
    (tester) async {
      final controller = _FakeSources();
      await _start(tester, controller);
      await tester.tap(find.byKey(const Key('add-source')));
      await tester.pumpAndSettle();
      await _selectKind(tester, 'Xtream Codes');
      await _enter(tester, 'source-name', 'Mon accès Xtream');
      await _enter(tester, 'source-address', 'https://example.test:8080');
      await _enter(tester, 'source-username', 'private-user');
      await _enter(tester, 'source-password', 'private-password');
      final password = find.descendant(
        of: find.byKey(const Key('source-password')),
        matching: find.byType(EditableText),
      );
      expect(tester.widget<EditableText>(password).obscureText, isTrue);
      await tester.tap(find.byTooltip('Afficher le mot de passe'));
      await tester.pumpAndSettle();
      expect(tester.widget<EditableText>(password).obscureText, isFalse);
      await tester.tap(find.byKey(const Key('save-source')));
      await tester.pumpAndSettle();
      expect(controller.saved.single.username, 'private-user');
      expect(controller.saved.single.password, 'private-password');
      expect(find.textContaining('private-user'), findsNothing);
      expect(find.textContaining('private-password'), findsNothing);
      expect(find.textContaining('example.test'), findsNothing);
      await tester.tap(find.widgetWithText(TextButton, 'Supprimer'));
      await tester.pumpAndSettle();
      expect(controller.removed, isEmpty);
      await tester.tap(find.widgetWithText(TextButton, 'Annuler'));
      await tester.pumpAndSettle();
      expect(controller.sources, hasLength(1));
      await tester.tap(find.widgetWithText(TextButton, 'Supprimer'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Supprimer'));
      await tester.pumpAndSettle();
      expect(controller.removed, ['new-source']);
      expect(find.text('Aucune source ajoutée'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Closing a connection test cancels it and never saves the draft',
    (tester) async {
      final controller = _FakeSources()..pendingTest = Completer<String>();
      await _start(tester, controller);
      await tester.tap(find.byKey(const Key('add-source')));
      await tester.pumpAndSettle();
      await _selectKind(tester, 'Playlist M3U • URL');
      await _enter(tester, 'source-name', 'En attente');
      await _enter(tester, 'source-address', 'https://example.test/list.m3u');
      await tester.tap(
        find.widgetWithText(OutlinedButton, 'Tester la connexion'),
      );
      await tester.pump();
      expect(controller.activeToken?.isCancelled, isFalse);
      // System back / Escape also pops the route; cancellation must happen
      // immediately, before the exit animation and widget disposal finish.
      Navigator.of(tester.element(find.byType(Dialog))).pop(false);
      expect(controller.activeToken?.isCancelled, isTrue);
      await tester.pumpAndSettle();
      expect(controller.activeToken?.isCancelled, isTrue);
      controller.pendingTest!.complete('Old result');
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
      expect(find.text('Old result'), findsNothing);
      expect(controller.saved, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'M3U file uses a local path and does not keep hidden Xtream fields',
    (tester) async {
      final controller = _FakeSources();
      await _start(tester, controller);
      await tester.tap(find.byKey(const Key('add-source')));
      await tester.pumpAndSettle();
      await _selectKind(tester, 'Xtream Codes');
      await _enter(tester, 'source-username', 'hidden-user');
      await _enter(tester, 'source-password', 'hidden-password');
      await _selectKind(tester, 'Playlist M3U • Fichier local');
      await _enter(tester, 'source-name', 'Ma playlist locale');
      await _enter(tester, 'source-address', r'C:\Media\my-list.m3u');
      await tester.tap(find.byKey(const Key('save-source')));
      await tester.pumpAndSettle();
      expect(controller.saved.single.kind, SourceKind.m3uFile);
      expect(controller.saved.single.address, r'C:\Media\my-list.m3u');
      expect(controller.saved.single.username, isEmpty);
      expect(controller.saved.single.password, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
}

bool _fieldFocused(WidgetTester tester, String key) => tester
    .widget<EditableText>(
      find.descendant(
        of: find.byKey(Key(key)),
        matching: find.byType(EditableText),
      ),
    )
    .focusNode
    .hasFocus;

Future<void> _start(WidgetTester tester, _FakeSources controller) async {
  tester.view.physicalSize = const Size(1000, 680);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    MaterialApp(
      theme: novaTheme(0xff8b5cf6),
      home: Scaffold(
        appBar: AppBar(title: const Text('Sources IPTV')),
        body: SourcesPage(controller: controller),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _enter(WidgetTester tester, String key, String value) async {
  final field = find.byKey(Key(key));
  await tester.ensureVisible(field);
  await tester.pumpAndSettle();
  await tester.enterText(field, value);
  await tester.pumpAndSettle();
}

Future<void> _selectKind(WidgetTester tester, String name) async {
  final field = find.byType(DropdownButtonFormField<SourceKind>);
  await tester.ensureVisible(field);
  await tester.pumpAndSettle();
  await tester.tap(field);
  await tester.pumpAndSettle();
  await tester.tap(find.text(name).last);
  await tester.pumpAndSettle();
}

class _FakeSources extends ChangeNotifier implements SourceController {
  final _sources = <SourceSummary>[];
  final _drafts = <String, SourceDraft>{};
  final saved = <SourceDraft>[];
  final tested = <SourceDraft>[];
  final removed = <String>[];
  Completer<String>? pendingTest;
  CancellationToken? activeToken;

  @override
  List<SourceSummary> get sources => List.unmodifiable(_sources);
  @override
  bool get isInitializing => false;
  @override
  Set<String> get busyIds => {};
  @override
  String? get error => null;
  @override
  List<String> get warnings => const [];
  @override
  SourceDraft? draftFor(String id) => _drafts[id];

  @override
  Future<void> add(SourceDraft draft, {CancellationToken? cancel}) async {
    saved.add(draft);
    _drafts['new-source'] = draft;
    _sources.add(
      SourceSummary(
        id: 'new-source',
        name: draft.name,
        kind: draft.kind,
        itemCount: 5,
        updatedAt: DateTime.utc(2026, 11, 9, 12),
      ),
    );
    notifyListeners();
  }

  @override
  Future<String> test(SourceDraft draft, {CancellationToken? cancel}) async {
    tested.add(draft);
    activeToken = cancel;
    final pending = pendingTest;
    if (pending != null) return pending.future;
    return 'Connexion réussie.';
  }

  @override
  Future<void> remove(String id) async {
    removed.add(id);
    _sources.removeWhere((source) => source.id == id);
    _drafts.remove(id);
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
