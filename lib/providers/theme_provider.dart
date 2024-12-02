// lib/providers/theme_provider.dart

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/config/theme_config.dart';
import '../core/constants/colors.dart';

class ThemeProvider extends ChangeNotifier {
  static const String _themeKey = 'app_theme';
  bool _isDarkMode = false;
  late SharedPreferences _prefs;
  bool _isInitialized = false;

  // Getters
  bool get isDarkMode => _isDarkMode;
  bool get isInitialized => _isInitialized;
  ThemeData get currentTheme =>
      _isDarkMode ? ThemeConfig.darkTheme : ThemeConfig.lightTheme;
  Color get primaryColor => AppColors.primary;

  ThemeProvider() {
    _loadThemePreference();
  }

  // Initialize theme preference
  Future<void> _loadThemePreference() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      _isDarkMode = _prefs.getBool(_themeKey) ?? false;
      _isInitialized = true;
      notifyListeners();

      if (kDebugMode) {
        print('Theme loaded: ${_isDarkMode ? 'dark' : 'light'}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading theme preference: $e');
      }
      _isDarkMode = false;
      _isInitialized = true;
      notifyListeners();
    }
  }

  // Toggle theme
  Future<void> toggleTheme() async {
    try {
      _isDarkMode = !_isDarkMode;
      await _prefs.setBool(_themeKey, _isDarkMode);
      notifyListeners();

      if (kDebugMode) {
        print('Theme changed to: ${_isDarkMode ? 'dark' : 'light'}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error toggling theme: $e');
      }
      // Revert change if saving fails
      _isDarkMode = !_isDarkMode;
      notifyListeners();
    }
  }

  // Set specific theme
  Future<void> setTheme(bool isDark) async {
    if (_isDarkMode == isDark) return;

    try {
      _isDarkMode = isDark;
      await _prefs.setBool(_themeKey, isDark);
      notifyListeners();

      if (kDebugMode) {
        print('Theme set to: ${isDark ? 'dark' : 'light'}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error setting theme: $e');
      }
      // Revert change if saving fails
      _isDarkMode = !isDark;
      notifyListeners();
    }
  }

  // Reset theme to default (light)
  Future<void> resetTheme() async {
    try {
      _isDarkMode = false;
      await _prefs.setBool(_themeKey, false);
      notifyListeners();

      if (kDebugMode) {
        print('Theme reset to default (light)');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error resetting theme: $e');
      }
    }
  }

  // Update theme without saving (temporary)
  void updateThemeTemporary(bool isDark) {
    if (_isDarkMode != isDark) {
      _isDarkMode = isDark;
      notifyListeners();

      if (kDebugMode) {
        print('Theme temporarily changed to: ${isDark ? 'dark' : 'light'}');
      }
    }
  }

  // Get current theme mode as string
  String getCurrentThemeMode() => _isDarkMode ? 'dark' : 'light';

  // Check if theme is initialized
  bool isThemeLoaded() => _isInitialized;
}
