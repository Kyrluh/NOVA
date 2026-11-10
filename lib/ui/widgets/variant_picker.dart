import 'package:flutter/material.dart';

import '../../domain/models.dart';
import '../../domain/media_variants.dart';
import '../../state/app_controller.dart';

class VariantPicker extends StatelessWidget {
  const VariantPicker({
    super.key,
    required this.controller,
    required this.item,
    required this.onChanged,
    this.enabled = true,
  });
  final AppController controller;
  final MediaItem item;
  final ValueChanged<MediaItem> onChanged;
  final bool enabled;
  @override
  Widget build(BuildContext context) {
    final versions = controller.variantsFor(item);
    if (versions.length < 2) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: DropdownButtonFormField<String>(
        key: ValueKey('variant-${item.id}'),
        initialValue: item.id,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'Version · langue / qualité',
        ),
        items: [
          for (final version in versions)
            DropdownMenuItem(
              value: version.id,
              child: Text(
                variantLabel(version),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
        onChanged: !enabled
            ? null
            : (id) {
                if (id != null) {
                  onChanged(versions.firstWhere((v) => v.id == id));
                }
              },
      ),
    );
  }
}
