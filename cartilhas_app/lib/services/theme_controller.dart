import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ThemePreference { system, light, dark }

class ThemeController extends ChangeNotifier {
  static const _preferenceKey = 'theme_preference_v1';

  ThemePreference _preference = ThemePreference.system;

  ThemePreference get preference => _preference;

  ThemeMode get themeMode => switch (_preference) {
    ThemePreference.light => ThemeMode.light,
    ThemePreference.dark => ThemeMode.dark,
    ThemePreference.system => ThemeMode.system,
  };

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_preferenceKey);
    _preference = ThemePreference.values.firstWhere(
      (value) => value.name == saved,
      orElse: () => ThemePreference.system,
    );
    notifyListeners();
  }

  Future<void> setPreference(ThemePreference preference) async {
    if (_preference == preference) return;
    _preference = preference;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_preferenceKey, preference.name);
  }
}
