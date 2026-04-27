import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  static const String _timeFormatKey = 'use_24h_format';
  static const String _darkModeKey = 'is_dark_mode';
  
  bool _use24hFormat = true;
  bool _isDarkMode = true; // Default to dark mode as requested earlier

  bool get use24hFormat => _use24hFormat;
  bool get isDarkMode => _isDarkMode;

  SettingsProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _use24hFormat = prefs.getBool(_timeFormatKey) ?? true;
    _isDarkMode = prefs.getBool(_darkModeKey) ?? true;
    notifyListeners();
  }

  Future<void> setUse24hFormat(bool value) async {
    if (_use24hFormat == value) return;
    
    _use24hFormat = value;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_timeFormatKey, value);
  }

  Future<void> setDarkMode(bool value) async {
    if (_isDarkMode == value) return;
    
    _isDarkMode = value;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_darkModeKey, value);
  }
}
