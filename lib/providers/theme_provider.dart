// lib/providers/theme_provider.dart

/// Theme provider to manage application theming.
/// Handles theme state and user theme preferences.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/config/theme_config.dart';
import '../core/constants/colors.dart';
import '../services/firebase_service.dart';
import '../features/auth/models/user_model.dart';

/// Theme provider
class ThemeProvider with ChangeNotifier {
  // Dependencies
  final FirebaseService _firebaseService;

  // Internal state
  ThemeData _currentTheme;
  bool _isDarkMode;
  String? _error;

  /// Constructor
  ThemeProvider({
    FirebaseService? firebaseService,
    bool isDarkMode = false,
  })  : _firebaseService = firebaseService ?? FirebaseService(),
        _currentTheme = ThemeConfig.lightTheme,
        _isDarkMode = isDarkMode {
    _initialize();
  }

  /// Getters
  ThemeData get theme => _currentTheme;
  bool get isDarkMode => _isDarkMode;
  String? get error => _error;

  /// Initialize provider
  Future<void> _initialize() async {
    try {
      await _firebaseService.initialize();
      await _loadTheme();
    } catch (e) {
      _handleError(e);
    }
  }

  /// Load saved theme
  Future<void> _loadTheme() async {
    try {
      _updateTheme(_isDarkMode);
    } catch (e) {
      _handleError(e);
    }
  }

  /// Toggle theme mode
  Future<void> toggleTheme(UserModel? user) async {
    try {
      final newMode = !_isDarkMode;
      _updateTheme(newMode);

      // Save preference if user is logged in
      if (user != null) {
        await _firebaseService.updateUserSettings(
          userId: user.id,
          settings: {'theme': newMode ? 'dark' : 'light'},
        );
      }
    } catch (e) {
      _handleError(e);
    }
  }

  /// Set theme for Pokemon type
  void setPokemonTypeTheme(String type) {
    try {
      _currentTheme = ThemeConfig.getPokemonTypeTheme(type);
      _updateSystemUI(type);
      notifyListeners();
    } catch (e) {
      _handleError(e);
    }
  }

  /// Reset to default theme
  void resetTheme() {
    try {
      _updateTheme(_isDarkMode);
      _updateSystemUI(null);
    } catch (e) {
      _handleError(e);
    }
  }

  /// Sync theme with user preferences
  Future<void> syncWithUserPreferences(UserModel user) async {
    try {
      final settings = await _firebaseService.getUserSettings(user.id);
      final isDark = settings['theme'] == 'dark';

      if (isDark != _isDarkMode) {
        _updateTheme(isDark);
      }
    } catch (e) {
      _handleError(e);
    }
  }

  /// Update theme
  void _updateTheme(bool isDark) {
    _isDarkMode = isDark;
    _currentTheme = isDark ? _createDarkTheme() : ThemeConfig.lightTheme;
    _updateSystemUI(null);
    notifyListeners();
  }

  /// Create dark theme
  ThemeData _createDarkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        primary: AppColors.primaryButton,
        secondary: AppColors.secondaryButton,
        error: AppColors.error,
        surface: const Color(0xFF1E1E1E),
      ),
      scaffoldBackgroundColor: const Color(0xFF121212),
      cardTheme: CardTheme(
        color: const Color(0xFF2A2A2A),
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: const Color(0xFF121212),
        elevation: 0,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: const Color(0xFF1E1E1E),
        selectedItemColor: AppColors.primaryButton,
        unselectedItemColor: Colors.grey,
        elevation: 8,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF2A2A2A),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  /// Update system UI overlay style
  void _updateSystemUI(String? pokemonType) {
    if (pokemonType != null) {
      SystemChrome.setSystemUIOverlayStyle(
        ThemeConfig.getPokemonDetailSystemUiStyle(pokemonType),
      );
    } else {
      SystemChrome.setSystemUIOverlayStyle(
        _isDarkMode
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark.copyWith(
                statusBarColor: Colors.transparent,
              ),
      );
    }
  }

  /// Handle errors
  void _handleError(dynamic error) {
    _error = error.toString();
    notifyListeners();
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
