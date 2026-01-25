import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeNotifier with ChangeNotifier {
  ThemeMode _themeMode;
  bool _isBiometricAuthEnabled;

  ThemeNotifier._(this._themeMode, this._isBiometricAuthEnabled);

  static Future<ThemeNotifier> create() async {
    final prefs = await SharedPreferences.getInstance();
    final isDarkMode = prefs.getBool('isDarkMode') ?? false;
    final isBiometricAuthEnabled = prefs.getBool('isBiometricAuthEnabled') ?? false;
    return ThemeNotifier._(isDarkMode ? ThemeMode.dark : ThemeMode.light, isBiometricAuthEnabled);
  }

  ThemeMode get themeMode => _themeMode;
  bool get isBiometricAuthEnabled => _isBiometricAuthEnabled;

  Future<void> toggleTheme() async {
    _themeMode =
        _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
    await _saveTheme();
  }

  Future<void> toggleBiometricAuth() async {
    _isBiometricAuthEnabled = !_isBiometricAuthEnabled;
    notifyListeners(); // Notify immediately for UI feedback
    await _saveBiometricAuth(); // Save efficiently
  }

  Future<void> _saveTheme() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', _themeMode == ThemeMode.dark);
  }

  Future<void> _saveBiometricAuth() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isBiometricAuthEnabled', _isBiometricAuthEnabled);
  }
}
