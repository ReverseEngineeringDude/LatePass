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

  void toggleTheme() {
    _themeMode =
        _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    _saveTheme();
    notifyListeners();
  }

  Future<void> toggleBiometricAuth() async {
    _isBiometricAuthEnabled = !_isBiometricAuthEnabled;
    await _saveBiometricAuth();
    notifyListeners();
  }

  Future<void> _saveTheme() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setBool('isDarkMode', _themeMode == ThemeMode.dark);
  }

  Future<void> _saveBiometricAuth() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isBiometricAuthEnabled', _isBiometricAuthEnabled);
  }
}
