import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme.dart';

class ThemeProvider extends ChangeNotifier {
  static const String _themeKey = 'selected_theme';
  static const String themeDark = 'dark';
  static const String themeDeepBlue = 'deep_blue';

  ThemeData _currentTheme = AppTheme.darkTheme;
  String _currentThemeKey = themeDark;
  bool _isFirstLaunch = true;
  bool _isInitialized = false;

  ThemeData get currentTheme => _currentTheme;
  String get currentThemeKey => _currentThemeKey;
  bool get isFirstLaunch => _isFirstLaunch;
  bool get isInitialized => _isInitialized;

  LinearGradient get currentGradient {
    return _currentThemeKey == themeDeepBlue
        ? AppTheme.deepBlueGradient
        : AppTheme.darkGradient;
  }

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTheme = prefs.getString(_themeKey);

    if (savedTheme != null) {
      _isFirstLaunch = false;
      _currentThemeKey = savedTheme;
      _currentTheme = _getThemeFromKey(savedTheme);
    } else {
      _isFirstLaunch = true;
    }

    _isInitialized = true;
    notifyListeners();
  }

  Future<void> setTheme(String themeKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, themeKey);

    _currentThemeKey = themeKey;
    _currentTheme = _getThemeFromKey(themeKey);
    _isFirstLaunch = false;
    notifyListeners();
  }

  ThemeData _getThemeFromKey(String key) {
    switch (key) {
      case themeDeepBlue:
        return AppTheme.deepBlueTheme;
      case themeDark:
      default:
        return AppTheme.darkTheme;
    }
  }
}
