import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettingsProvider extends ChangeNotifier {
  static const _themeKey = 'app_theme_mode';
  static const _localeKey = 'app_locale';

  ThemeMode _themeMode = ThemeMode.light;
  Locale _locale = const Locale('ar');

  ThemeMode get themeMode => _themeMode;
  Locale get locale => _locale;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTheme = prefs.getString(_themeKey);
    final savedLocale = prefs.getString(_localeKey);

    if (savedTheme == 'dark') {
      _themeMode = ThemeMode.dark;
    } else {
      _themeMode = ThemeMode.light;
    }

    if (savedLocale != null && savedLocale.isNotEmpty) {
      _locale = Locale(savedLocale);
    }

    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, mode == ThemeMode.dark ? 'dark' : 'light');
    notifyListeners();
  }

  Future<void> setLocale(Locale locale) async {
    _locale = locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localeKey, locale.languageCode);
    notifyListeners();
  }
}
