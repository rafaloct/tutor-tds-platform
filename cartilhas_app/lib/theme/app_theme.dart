import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTheme {
  const AppTheme._();

  static const primary = Color(0xFF093AF4);
  static const secondary = Color(0xFFFF341B);
  static const accent = Color(0xFFF6D846);
  static const success = Color(0xFF18D010);
  static const ink = Color(0xFF262626);
  static const muted = Color(0xFF6B6B6B);

  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final generated = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: brightness,
    );

    final isDark = brightness == Brightness.dark;
    final scheme = generated.copyWith(
      primary: primary,
      onPrimary: Colors.white,
      primaryContainer: isDark
          ? const Color(0xFF142B89)
          : const Color(0xFFE9EDFF),
      onPrimaryContainer: isDark ? Colors.white : const Color(0xFF071650),
      secondary: secondary,
      onSecondary: Colors.white,
      secondaryContainer: isDark
          ? const Color(0xFF681408)
          : const Color(0xFFFFE9E5),
      onSecondaryContainer: isDark ? Colors.white : const Color(0xFF641105),
      tertiary: accent,
      onTertiary: ink,
      tertiaryContainer: isDark
          ? const Color(0xFF544700)
          : const Color(0xFFFFF5C2),
      onTertiaryContainer: isDark ? Colors.white : const Color(0xFF352D00),
      error: secondary,
      surface: isDark ? const Color(0xFF171719) : Colors.white,
      onSurface: isDark ? const Color(0xFFF4F4F4) : ink,
      outline: isDark ? const Color(0xFF929292) : muted,
      outlineVariant: isDark
          ? const Color(0xFF414144)
          : const Color(0xFFE1E3EA),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: 'Poppins',
      scaffoldBackgroundColor: isDark
          ? const Color(0xFF101012)
          : const Color(0xFFF7F8FC),
      appBarTheme: const AppBarTheme(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: isDark ? const Color(0xFF1C1C1F) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isDark ? const Color(0xFF414144) : const Color(0xFFE1E3EA),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          textStyle: const TextStyle(fontWeight: FontWeight.w500),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(48, 48),
          textStyle: const TextStyle(fontWeight: FontWeight.w500),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          textStyle: const TextStyle(fontWeight: FontWeight.w500),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF1C1C1F) : const Color(0xFFF8F9FC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        indicatorColor: primary.withValues(alpha: 0.16),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            return states.contains(WidgetState.selected)
                ? scheme.primaryContainer
                : null;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            return states.contains(WidgetState.selected)
                ? scheme.onPrimaryContainer
                : scheme.onSurface;
          }),
        ),
      ),
      materialTapTargetSize: MaterialTapTargetSize.padded,
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
