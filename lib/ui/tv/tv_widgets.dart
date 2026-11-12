import 'package:flutter/material.dart';

import '../theme.dart';

ThemeData novaTvTheme(int accent) {
  final base = novaTheme(accent);
  final color = Color(accent);
  final focusedButton = ButtonStyle(
    minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
    backgroundColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.focused) ? color : null,
    ),
    side: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.focused)
          ? const BorderSide(color: novaHighlight, width: 3)
          : null,
    ),
  );
  return base.copyWith(
    focusColor: color.withValues(alpha: .8),
    inputDecorationTheme: base.inputDecorationTheme.copyWith(
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: novaHighlight, width: 3),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: base.filledButtonTheme.style?.merge(focusedButton),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: base.outlinedButtonTheme.style?.merge(focusedButton),
    ),
    textButtonTheme: TextButtonThemeData(
      style: base.textButtonTheme.style?.merge(focusedButton),
    ),
    iconButtonTheme: IconButtonThemeData(style: focusedButton),
    switchTheme: SwitchThemeData(
      overlayColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.focused)
            ? color.withValues(alpha: .4)
            : null,
      ),
    ),
  );
}

/// Each card is one remote target. Focus never starts a stream by itself.
class TvTile extends StatefulWidget {
  const TvTile({
    super.key,
    required this.child,
    required this.onPressed,
    this.focusNode,
    this.autofocus = false,
    this.selected = false,
    this.label,
  });
  final Widget child;
  final VoidCallback onPressed;
  final FocusNode? focusNode;
  final bool autofocus;
  final bool selected;
  final String? label;
  @override
  State<TvTile> createState() => _TvTileState();
}

class _TvTileState extends State<TvTile> {
  bool _focused = false;
  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Semantics(
      button: true,
      label: widget.label,
      selected: widget.selected,
      child: Material(
        color: _focused
            ? accent.withValues(alpha: .3)
            : widget.selected
            ? accent.withValues(alpha: .15)
            : novaSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: _focused
                ? novaHighlight
                : widget.selected
                ? novaHighlight
                : Colors.transparent,
            width: 3,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          focusNode: widget.focusNode,
          autofocus: widget.autofocus,
          onFocusChange: (value) {
            setState(() => _focused = value);
            if (value) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  Scrollable.ensureVisible(
                    context,
                    duration: const Duration(milliseconds: 90),
                    alignmentPolicy:
                        ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
                  );
                }
              });
            }
          },
          onTap: widget.onPressed,
          child: Padding(padding: const EdgeInsets.all(3), child: widget.child),
        ),
      ),
    );
  }
}

class TvPageFrame extends StatelessWidget {
  const TvPageFrame({
    super.key,
    required this.title,
    required this.child,
    this.autofocusBack = true,
  });
  final String title;
  final Widget child;
  final bool autofocusBack;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  autofocus: autofocusBack,
                  tooltip: 'Retour',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(child: child),
          ],
        ),
      ),
    ),
  );
}
