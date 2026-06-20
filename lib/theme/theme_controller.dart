import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Holds the app's light/dark/system preference and persists it.
class ThemeController {
  static const _key = 'themeMode';
  static final ValueNotifier<ThemeMode> mode =
      ValueNotifier<ThemeMode>(ThemeMode.system);

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    switch (prefs.getString(_key)) {
      case 'dark':
        mode.value = ThemeMode.dark;
        break;
      case 'light':
        mode.value = ThemeMode.light;
        break;
      default:
        mode.value = ThemeMode.system;
    }
  }

  static Future<void> set(ThemeMode m) async {
    mode.value = m;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      m == ThemeMode.dark
          ? 'dark'
          : m == ThemeMode.light
              ? 'light'
              : 'system',
    );
  }

  /// Flip between light and dark based on what's currently showing.
  static void toggle(BuildContext context) {
    final isDark = mode.value == ThemeMode.dark ||
        (mode.value == ThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.dark);
    set(isDark ? ThemeMode.light : ThemeMode.dark);
  }
}
