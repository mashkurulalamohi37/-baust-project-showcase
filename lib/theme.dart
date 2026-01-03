import 'package:flutter/material.dart';

ThemeData buildLightTheme() {
  // Indigo + cyan accent with a soft surface for a modern academic feel
  const Color seed = Color(0xFF4F46E5);
  final ColorScheme scheme = ColorScheme.fromSeed(
    seedColor: seed,
    brightness: Brightness.light,
    primary: const Color(0xFF4F46E5),
    secondary: const Color(0xFF06B6D4),
    tertiary: const Color(0xFFEC4899),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: const Color(0xFFF6F7FB),
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      elevation: 1,
      centerTitle: true,
      titleTextStyle: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 2,
      color: scheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.symmetric(vertical: 6),
      shadowColor: scheme.primary.withOpacity(0.12),
    ),
    inputDecorationTheme: InputDecorationTheme(
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
        borderSide: BorderSide(color: scheme.primary, width: 1.4),
      ),
      filled: true,
      fillColor: scheme.surfaceVariant.withOpacity(0.6),
      labelStyle: TextStyle(color: scheme.onSurfaceVariant),
      hintStyle: TextStyle(color: scheme.onSurfaceVariant.withOpacity(0.7)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
        elevation: 0,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
      ),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      labelPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      selectedColor: scheme.primaryContainer,
    ),
    visualDensity: VisualDensity.adaptivePlatformDensity,
  );
}

ThemeData buildDarkTheme() {
  // Same palette tuned for dark surfaces
  const Color seed = Color(0xFF4F46E5);
  final ColorScheme scheme = ColorScheme.fromSeed(
    seedColor: seed,
    brightness: Brightness.dark,
    primary: const Color(0xFF818CF8),
    secondary: const Color(0xFF22D3EE),
    tertiary: const Color(0xFFF472B6),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: const Color(0xFF0E121A),
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      elevation: 1,
      centerTitle: true,
      titleTextStyle: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 1,
      color: const Color(0xFF1C202B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.symmetric(vertical: 6),
      shadowColor: scheme.primary.withOpacity(0.18),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.outlineVariant.withOpacity(0.6)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.outlineVariant.withOpacity(0.6)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.primary, width: 1.4),
      ),
      filled: true,
      fillColor: const Color(0xFF222836),
      labelStyle: TextStyle(color: scheme.onSurface),
      hintStyle: TextStyle(color: scheme.onSurface.withOpacity(0.72)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
        elevation: 0,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
      ),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      labelPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      selectedColor: scheme.primaryContainer,
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: scheme.primary,
      unselectedLabelColor: scheme.onSurfaceVariant,
      indicatorColor: scheme.primary,
    ),
    visualDensity: VisualDensity.adaptivePlatformDensity,
  );
}


