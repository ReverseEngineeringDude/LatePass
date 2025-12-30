import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeNotifier with ChangeNotifier {
  ThemeMode _themeMode;
  bool _isBiometricAuthEnabled = false;

  ThemeNotifier(this._themeMode) {
    _loadTheme();
    _loadBiometricAuth();
  }

  ThemeMode get themeMode => _themeMode;
  bool get isBiometricAuthEnabled => _isBiometricAuthEnabled;

  void toggleTheme() {
    _themeMode = _themeMode == ThemeMode.light
        ? ThemeMode.dark
        : ThemeMode.light;
    _saveTheme();
    notifyListeners();
  }

  Future<void> toggleBiometricAuth() async {
    _isBiometricAuthEnabled = !_isBiometricAuthEnabled;
    await _saveBiometricAuth();
    notifyListeners();
  }

  Future<void> _loadTheme() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    _themeMode = (prefs.getBool('isDarkMode') ?? false)
        ? ThemeMode.dark
        : ThemeMode.light;
    notifyListeners();
  }

  Future<void> _saveTheme() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setBool('isDarkMode', _themeMode == ThemeMode.dark);
  }

  Future<void> _loadBiometricAuth() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    _isBiometricAuthEnabled = prefs.getBool('isBiometricAuthEnabled') ?? false;
    notifyListeners();
  }

  Future<void> _saveBiometricAuth() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isBiometricAuthEnabled', _isBiometricAuthEnabled);
  }
}
