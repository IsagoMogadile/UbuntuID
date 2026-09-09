import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _prefsKey = 'ubuntuid_theme_mode';

/// Persisted light/dark/system preference. Defaults to `system` (matches
/// `MaterialApp.router`'s previous unset behaviour) so nobody's first
/// launch changes look without them asking -- `AppTheme.dark` deliberately
/// keeps the same green/gold brand identity as light mode (see
/// `app_theme.dart`), just re-balanced for a dark surface, not a different
/// palette, since this represents a South African government system and
/// shouldn't look like a different product at night.
class ThemeModeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    _load();
    return ThemeMode.system;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsKey);
    final mode = switch (saved) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    if (mode != state) state = mode;
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, mode.name);
  }
}

final themeModeControllerProvider = NotifierProvider<ThemeModeController, ThemeMode>(ThemeModeController.new);
