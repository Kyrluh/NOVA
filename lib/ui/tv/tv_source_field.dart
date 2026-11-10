import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Remote navigation stays in Flutter; editing belongs to the Android IME.
class TvSourceField extends StatefulWidget {
  const TvSourceField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.decoration,
    this.validator,
    this.enabled = true,
    this.obscureText = false,
    this.url = false,
    this.maxLength,
  });
  final TextEditingController controller;
  final FocusNode focusNode;
  final InputDecoration decoration;
  final FormFieldValidator<String>? validator;
  final bool enabled;
  final bool obscureText;
  final bool url;
  final int? maxLength;
  @override
  State<TvSourceField> createState() => _TvSourceFieldState();
}

class _TvSourceFieldState extends State<TvSourceField> {
  static const _channel = MethodChannel('nova/android');
  bool _focused = false;
  bool _editing = false;

  Future<void> _edit(FormFieldState<String> field) async {
    if (!widget.enabled || _editing) return;
    _editing = true;
    try {
      final value = await _channel.invokeMethod<String>('editSourceText', {
        'title': widget.decoration.labelText ?? 'Modifier le champ',
        'value': widget.controller.text,
        'url': widget.url,
        'secret': widget.obscureText,
        'maxLength': widget.maxLength ?? (widget.url ? 16384 : 4096),
      });
      if (!mounted) return;
      if (value != null) {
        widget.controller.value = TextEditingValue(
          text: value,
          selection: TextSelection.collapsed(offset: value.length),
        );
        field.didChange(value);
      }
    } on PlatformException {
      if (mounted) _unavailable();
    } on MissingPluginException {
      if (mounted) _unavailable();
    } finally {
      _editing = false;
      if (mounted) widget.focusNode.requestFocus();
    }
  }

  void _unavailable() => ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text(
        'Le clavier système ne s’est pas ouvert. Réessayez avec OK.',
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => FormField<String>(
    initialValue: widget.controller.text,
    enabled: widget.enabled,
    validator: (_) => widget.validator?.call(widget.controller.text),
    builder: (field) => FocusableActionDetector(
      focusNode: widget.focusNode,
      enabled: widget.enabled,
      onShowFocusHighlight: (value) => setState(() => _focused = value),
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.select): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.numpadEnter): ActivateIntent(),
      },
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            _edit(field);
            return null;
          },
        ),
      },
      child: Semantics(
        button: true,
        label: widget.decoration.labelText,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.enabled ? () => _edit(field) : null,
          child: ValueListenableBuilder<TextEditingValue>(
            valueListenable: widget.controller,
            builder: (context, value, _) => InputDecorator(
              isFocused: _focused,
              isEmpty: value.text.isEmpty,
              decoration: widget.decoration.copyWith(
                enabled: widget.enabled,
                errorText: field.errorText,
                suffixIcon: const Icon(Icons.edit_outlined),
                helperText: 'OK pour modifier · flèches pour naviguer',
              ),
              child: Text(
                value.text.isEmpty
                    ? 'Appuyez sur OK pour saisir'
                    : widget.obscureText
                    ? '••••••••'
                    : value.text,
                maxLines: widget.url ? 2 : 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: value.text.isEmpty ? Colors.white54 : null,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
