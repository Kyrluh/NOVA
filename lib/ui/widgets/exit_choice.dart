import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

import '../../state/app_controller.dart';

Future<void> showExitChoice(BuildContext context, AppController app) async {
  final choice = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Que souhaitez-vous faire ?'),
      content: const Text(
        'Réduire conserve la session en mémoire. Android peut toutefois la libérer si la mémoire manque.',
      ),
      actions: [
        TextButton(
          autofocus: true,
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        OutlinedButton(
          onPressed: () => Navigator.pop(context, 'minimize'),
          child: const Text('Réduire'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, 'close'),
          child: const Text('Fermer'),
        ),
      ],
    ),
  );
  if (choice == 'minimize') {
    await app.flush();
    if (Platform.isAndroid) {
      await const MethodChannel('nova/android')
          .invokeMethod<void>('minimizeApp');
    } else if (Platform.isWindows) {
      await windowManager.minimize();
    }
  } else if (choice == 'close') {
    await app.shutdown();
    if (Platform.isAndroid) {
      await SystemNavigator.pop();
    } else if (Platform.isWindows) {
      await windowManager.setPreventClose(false);
      await windowManager.close();
    }
  }
}
