import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class PrefsHelper {
  static PrefsHelper? _instance;
  late final SharedPreferences _prefs;
  bool _initialized = false;

  static Future<PrefsHelper> getInstance() async {
    _instance ??= PrefsHelper._();
    await _instance!._init();
    return _instance!;
  }

  PrefsHelper._();

  Future<void> _init() async {
    if (!_initialized) {
      _prefs = await SharedPreferences.getInstance();
      _initialized = true;
      debugPrint('✅ PrefsHelper initialized');
    }
  }

  SharedPreferences get prefs {
    if (!_initialized) {
      throw StateError('PrefsHelper not initialized');
    }
    return _prefs;
  }
}
