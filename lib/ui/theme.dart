import 'package:flutter/material.dart';

const novaBackground = Color(0xFF0B0D12);
const novaSurface = Color(0xFF13161E);
const novaMuted = Color(0xFF9299AA);

ThemeData novaTheme(int accent) {
  final accentColor = Color(accent);
  final scheme = ColorScheme.fromSeed(
    seedColor: accentColor,
    brightness: Brightness.dark,
    surface: novaSurface,
  ).copyWith(primary: accentColor, onPrimary: Colors.white);
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: const BorderSide(color: Color(0xFF2A2E3C)),
  );
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    fontFamily: 'Segoe UI',
    colorScheme: scheme,
  );
  return base.copyWith(
    scaffoldBackgroundColor: novaBackground,
    canvasColor: novaBackground,
    dividerColor: const Color(0xFF242834),
    textTheme: base.textTheme.copyWith(
      displaySmall: base.textTheme.displaySmall?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -1.4,
      ),
      headlineLarge: base.textTheme.headlineLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -1,
      ),
      headlineMedium: base.textTheme.headlineMedium?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -.7,
      ),
      titleLarge: base.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: -.4,
      ),
      titleMedium: base.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
      ),
      bodyMedium: base.textTheme.bodyMedium?.copyWith(height: 1.5),
      bodySmall: base.textTheme.bodySmall?.copyWith(color: novaMuted),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: novaBackground,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: novaSurface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF181C26),
      hintStyle: const TextStyle(color: novaMuted, fontSize: 14),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(
        borderSide: BorderSide(color: accentColor),
      ),
      prefixIconColor: novaMuted,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 19),
        textStyle: const TextStyle(
          fontFamily: 'Segoe UI',
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFFE9EBF2),
        side: const BorderSide(color: Color(0xFF373C4B)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        textStyle: const TextStyle(
          fontFamily: 'Segoe UI',
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(foregroundColor: const Color(0xFFBCC2D0)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: const Color(0xFF151923),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: novaSurface,
      surfaceTintColor: Colors.transparent,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: const Color(0xFF1B202C),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: novaSurface,
      selectedColor: accentColor.withAlpha(38),
      side: const BorderSide(color: Color(0xFF2A2E3C)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
      labelStyle: const TextStyle(fontFamily: 'Segoe UI', fontSize: 12),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    ),
    sliderTheme: base.sliderTheme.copyWith(
      activeTrackColor: accentColor,
      thumbColor: Colors.white,
      overlayColor: accentColor.withAlpha(30),
      inactiveTrackColor: const Color(0xFF303644),
      trackHeight: 3,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: const Color(0xFF262C3A),
      contentTextStyle: const TextStyle(color: Colors.white),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: const Color(0xFF303646),
        borderRadius: BorderRadius.circular(7),
      ),
      textStyle: const TextStyle(color: Colors.white, fontSize: 12),
      waitDuration: const Duration(milliseconds: 150),
    ),
    scrollbarTheme: ScrollbarThemeData(
      thickness: const WidgetStatePropertyAll(5),
      radius: const Radius.circular(10),
      thumbColor: WidgetStatePropertyAll(Colors.white.withAlpha(42)),
    ),
  );
}
