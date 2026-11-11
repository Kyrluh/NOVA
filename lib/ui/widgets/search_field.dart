import 'package:flutter/material.dart';

import '../tv/tv_source_field.dart';

/// On TV, directional focus never opens an IME or captures navigation keys.
class NovaSearchField extends StatefulWidget {
  const NovaSearchField({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.decoration,
    this.television = false,
    this.autofocus = false,
    this.onSubmitted,
  });
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onSubmitted;
  final InputDecoration decoration;
  final bool television;
  final bool autofocus;
  @override
  State<NovaSearchField> createState() => _NovaSearchFieldState();
}

class _NovaSearchFieldState extends State<NovaSearchField> {
  final _focus = FocusNode(debugLabel: 'TV search');
  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.television
      ? TvSourceField(
          controller: widget.controller,
          focusNode: _focus,
          autofocus: widget.autofocus,
          search: true,
          maxLength: 512,
          decoration: widget.decoration.copyWith(
            labelText:
                widget.decoration.labelText ??
                widget.decoration.hintText ??
                'Rechercher',
          ),
          onChanged: widget.onChanged,
        )
      : TextField(
          controller: widget.controller,
          autofocus: widget.autofocus,
          onChanged: widget.onChanged,
          onSubmitted: widget.onSubmitted,
          textInputAction: TextInputAction.search,
          decoration: widget.decoration,
        );
}
