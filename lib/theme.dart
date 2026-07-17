import 'package:flutter/material.dart';

/// Palette SOPAT — reprise des variables CSS du back-office web
/// (src/app/globals.css) pour une identité visuelle cohérente.
abstract class SopatColors {
  static const green = Color(0xFF1C3D2E); // --green
  static const greenDark = Color(0xFF0F2419); // --green-dark
  static const ivory = Color(0xFFF5F0E8); // --ivory
  static const bg = Color(0xFFD4E4DA); // --admin-bg
  static const surface = Color(0xFFF4F8F5); // --admin-surface
  static const border = Color(0xFFC2D5C9); // --admin-border
  static const text = Color(0xFF1A2E24); // --admin-text
  static const textMuted = Color(0xFF4A6A5A); // --admin-text-muted
  static const accent = Color(0xFF2F6F4F); // --admin-accent
  static const amber = Color(0xFFB8870A); // --admin-amber
  static const emerald = Color(0xFF1C7A48); // --admin-emerald
  static const red = Color(0xFFB03A2E);
}

ThemeData sopatTheme() {
  const colorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: SopatColors.green,
    onPrimary: SopatColors.ivory,
    secondary: SopatColors.accent,
    onSecondary: Colors.white,
    error: SopatColors.red,
    onError: Colors.white,
    surface: SopatColors.surface,
    onSurface: SopatColors.text,
    surfaceContainerHighest: SopatColors.bg,
    outline: SopatColors.textMuted,
    outlineVariant: SopatColors.border,
  );

  final base = ThemeData(colorScheme: colorScheme, useMaterial3: true);

  return base.copyWith(
    scaffoldBackgroundColor: SopatColors.bg,
    appBarTheme: const AppBarTheme(
      backgroundColor: SopatColors.green,
      foregroundColor: SopatColors.ivory,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: SopatColors.ivory,
        fontSize: 17,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
      ),
    ),
    cardTheme: const CardThemeData(
      color: SopatColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        side: BorderSide(color: SopatColors.border),
      ),
      margin: EdgeInsets.zero,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: SopatColors.green,
        foregroundColor: SopatColors.ivory,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: SopatColors.green,
        side: const BorderSide(color: SopatColors.green, width: 1.2),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: SopatColors.surface,
      labelStyle: const TextStyle(color: SopatColors.textMuted),
      hintStyle: TextStyle(color: SopatColors.textMuted.withValues(alpha: 0.6)),
      prefixIconColor: SopatColors.textMuted,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: SopatColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: SopatColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: SopatColors.accent, width: 1.6),
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? SopatColors.green
            : Colors.transparent,
      ),
      side: const BorderSide(color: SopatColors.textMuted, width: 1.5),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: SopatColors.greenDark,
      contentTextStyle: TextStyle(color: SopatColors.ivory),
      behavior: SnackBarBehavior.floating,
    ),
    dividerTheme: const DividerThemeData(color: SopatColors.border),
    progressIndicatorTheme:
        const ProgressIndicatorThemeData(color: SopatColors.accent),
  );
}
