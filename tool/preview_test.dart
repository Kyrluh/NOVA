// Run explicitly with: flutter test tool/preview_test.dart --no-pub
// These offline previews use flutter_test rendering, not an OS executable capture.
// This file lives outside test/ so normal test runs do not rewrite PNG artifacts.
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_iptv/app.dart';
import 'package:nova_iptv/data/local_store.dart';
import 'package:nova_iptv/state/app_controller.dart';
import 'package:nova_iptv/ui/widgets/artwork.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
    // Match the native app's installed font without distributing its font file.
    if (Platform.isWindows) {
      final font = File(r'C:\Windows\Fonts\segoeui.ttf');
      if (await font.exists()) {
        final bytes = await font.readAsBytes();
        final text = FontLoader('Segoe UI')
          ..addFont(Future.value(ByteData.sublistView(bytes)));
        await text.load();
      }
    }
  });

  testWidgets('Generate offline Flutter interface previews', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final controller = AppController(
      store: MemoryLocalStore({
        'settings': {'animations': false},
      }),
    );
    await controller.init();
    addTearDown(controller.dispose);

    const captureKey = ValueKey('preview-capture');
    await tester.pumpWidget(
      RepaintBoundary(
        key: captureKey,
        child: NovaApp(
          controller: controller,
          nativeReady: false,
          manageWindow: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _capture(tester, captureKey, 'docs/preview.png');

    // Expanded sidebar labels precede their duplicate topbar/page headings.
    await tester.tap(find.text('TV en direct').first);
    await tester.pumpAndSettle();
    await _capture(tester, captureKey, 'docs/preview-tv.png');

    await tester.tap(find.text('Paramètres').first);
    await tester.pumpAndSettle();
    await _capture(tester, captureKey, 'docs/preview-settings.png');
    expect(tester.takeException(), isNull);

    // Unmount the app and flush its disposal work before drawing a transparent
    // native icon from exactly the same NovaMark used in the navigation rail.
    const iconKey = ValueKey('native-icon');
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: RepaintBoundary(key: iconKey, child: NovaMark(size: 256)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _writeIcon(tester, iconKey);
  });
}

Future<void> _capture(WidgetTester tester, Key key, String path) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
  await tester.runAsync(() async {
    final bytes = await _png(boundary);
    final output = File(path);
    await output.parent.create(recursive: true);
    await output.writeAsBytes(bytes, flush: true);
  });
}

Future<void> _writeIcon(WidgetTester tester, Key key) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
  await tester.runAsync(() async {
    final png = await _png(boundary);
    // A single 256 × 256 PNG entry in the ICO container (Windows 10/11).
    final header = ByteData(22)
      ..setUint16(0, 0, Endian.little)
      ..setUint16(2, 1, Endian.little)
      ..setUint16(4, 1, Endian.little)
      ..setUint16(10, 1, Endian.little)
      ..setUint16(12, 32, Endian.little)
      ..setUint32(14, png.length, Endian.little)
      ..setUint32(18, 22, Endian.little);
    final icon = BytesBuilder(copy: false)
      ..add(header.buffer.asUint8List())
      ..add(png);
    await File('windows/runner/resources/app_icon.ico')
        .writeAsBytes(icon.takeBytes(), flush: true);
  });
}

Future<Uint8List> _png(RenderRepaintBoundary boundary) async {
  final image = await boundary.toImage(pixelRatio: 1);
  try {
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) throw StateError('PNG encoding failed');
    return bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes);
  } finally {
    image.dispose();
  }
}
