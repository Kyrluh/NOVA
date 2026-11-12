import 'package:flutter/material.dart';

import '../../state/source_controller.dart';

class SourceReloadButton extends StatelessWidget {
  const SourceReloadButton({super.key, required this.controller});
  final SourceController controller;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => OutlinedButton.icon(
      key: const ValueKey('reload-sources'),
      onPressed:
          controller.busyIds.isNotEmpty || !controller.hasConfiguredSources
          ? null
          : () async {
              var message = 'Sources rechargées.';
              try {
                await controller.reloadSources();
              } catch (_) {
                message = 'Certaines sources n’ont pas pu être actualisées. Leur cache est conservé.';
              }
              if (context.mounted) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(message)));
              }
            },
      icon: const Icon(Icons.refresh),
      label: Text(
        controller.catalogLoading
            ? 'Rechargement en cours…'
            : 'Recharger manuellement les sources',
      ),
    ),
  );
}
