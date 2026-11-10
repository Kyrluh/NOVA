import 'package:flutter/material.dart';

import '../../state/app_controller.dart';

class CatalogColumnsSetting extends StatelessWidget {
  const CatalogColumnsSetting({super.key, required this.controller});
  final AppController controller;
  @override
  Widget build(BuildContext context) => DropdownButtonFormField<int>(
    key: ValueKey('catalog-columns-${controller.settings.catalogColumns}'),
    initialValue: controller.settings.catalogColumns,
    isExpanded: true,
    decoration: const InputDecoration(
      labelText: 'Affiches par ligne · Films et Séries',
      helperText:
          'Auto ou 1 à 12. Le nombre est limité si l’écran est trop étroit.',
      helperMaxLines: 2,
    ),
    items: [
      const DropdownMenuItem(value: 0, child: Text('Automatique')),
      for (var count = 1; count <= 12; count++)
        DropdownMenuItem(
          value: count,
          child: Text(
            '$count ${count == 1 ? 'affiche' : 'affiches'} par ligne',
          ),
        ),
    ],
    onChanged: (value) {
      if (value != null) {
        controller.updateSettings(
          controller.settings.copyWith(catalogColumns: value),
        );
      }
    },
  );
}
