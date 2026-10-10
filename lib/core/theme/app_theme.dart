import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get light => _build(_lightScheme);
  static ThemeData get dark => _build(_darkScheme);

  static final ColorScheme _lightScheme = ColorScheme.fromSeed(
    seedColor: AppColors.green,
    brightness: Brightness.light,
  ).copyWith(
    primary: AppColors.green,
    onPrimary: Colors.white,
    primaryContainer: AppColors.greenLight,
    onPrimaryContainer: AppColors.greenDark,
    secondary: AppColors.gold,
    onSecondary: AppColors.charcoal,
    secondaryContainer: AppColors.goldLight,
    onSecondaryContainer: AppColors.charcoal,
    tertiary: AppColors.info,
    onTertiary: Colors.white,
    error: AppColors.error,
    onError: Colors.white,
    errorContainer: AppColors.errorBg,
    onErrorContainer: AppColors.error,
    surface: AppColors.surface,
    onSurface: AppColors.charcoal,
    onSurfaceVariant: AppColors.charcoalMuted,
    outline: AppColors.border,
    outlineVariant: AppColors.border,
  );

  static final ColorScheme _darkScheme = ColorScheme.fromSeed(
    seedColor: AppColors.green,
    brightness: Brightness.dark,
  ).copyWith(
    primary: const Color(0xFF4FAE78),
    onPrimary: const Color(0xFF00341C),
    primaryContainer: AppColors.greenDark,
    onPrimaryContainer: AppColors.greenLight,
    secondary: AppColors.gold,
    onSecondary: const Color(0xFF3A2A00),
    secondaryContainer: const Color(0xFF4A3A12),
    onSecondaryContainer: AppColors.goldLight,
    tertiary: const Color(0xFF7FA8D6),
    onTertiary: const Color(0xFF00294F),
    error: const Color(0xFFE6A19B),
    onError: const Color(0xFF601410),
    errorContainer: const Color(0xFF7A1F19),
    onErrorContainer: AppColors.errorBg,
    surface: AppColors.surfaceDark,
    onSurface: Colors.white,
    onSurfaceVariant: const Color(0xFFB7C0BA),
    outline: AppColors.borderDark,
    outlineVariant: AppColors.borderDark,
  );

  static ThemeData _build(ColorScheme scheme) {
    final isDark = scheme.brightness == Brightness.dark;
    final background = isDark ? AppColors.backgroundDark : AppColors.background;
    final surface = isDark ? AppColors.surfaceDark : AppColors.surface;
    final surfaceMuted = isDark ? AppColors.surfaceMutedDark : AppColors.surfaceMuted;
    final outline = isDark ? AppColors.borderDark : AppColors.border;

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      // Keyboard users: make the focused control obvious.
      focusColor: scheme.primary.withValues(alpha: 0.22),
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 19,
          fontWeight: FontWeight.w700,
        ),
      ),
      textTheme: const TextTheme(
        headlineSmall: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.2),
        titleLarge: TextStyle(fontWeight: FontWeight.w700),
        titleMedium: TextStyle(fontWeight: FontWeight.w700),
        titleSmall: TextStyle(fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(height: 1.35),
        bodyMedium: TextStyle(height: 1.35),
        labelLarge: TextStyle(fontWeight: FontWeight.w600),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: outline),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          disabledBackgroundColor: scheme.primary.withValues(alpha: 0.4),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.primary,
          side: BorderSide(color: outline),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceMuted,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: scheme.error, width: 1.4),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: scheme.primaryContainer,
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: surface,
        indicatorColor: scheme.primaryContainer,
        selectedLabelTextStyle: TextStyle(color: scheme.primary, fontWeight: FontWeight.w700),
        unselectedLabelTextStyle: TextStyle(color: scheme.onSurfaceVariant),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? null : Colors.grey.shade400,
        ),
      ),
      dividerTheme: DividerThemeData(color: outline),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.charcoal,
        contentTextStyle: const TextStyle(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
