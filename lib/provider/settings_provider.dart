import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  static const String _timeFormatKey = 'use_24h_format';
  static const String _darkModeKey = 'is_dark_mode';
  static const String _selectedAIModelKey = 'selected_ai_model';
  static const String _aiTemperatureKey = 'ai_temperature';
  static const String _aiMaxTokensKey = 'ai_max_tokens';

  bool _use24hFormat = true;
  bool _isDarkMode = true;
  String _selectedAIModel = 'llama2';
  double _aiTemperature = 0.7;
  int _aiMaxTokens = 500;

  bool get use24hFormat => _use24hFormat;
  bool get isDarkMode => _isDarkMode;
  String get selectedAIModel => _selectedAIModel;
  double get aiTemperature => _aiTemperature;
  int get aiMaxTokens => _aiMaxTokens;

  SettingsProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _use24hFormat = prefs.getBool(_timeFormatKey) ?? true;
    _isDarkMode = prefs.getBool(_darkModeKey) ?? true;
    _selectedAIModel = prefs.getString(_selectedAIModelKey) ?? 'llama2';
    _aiTemperature = prefs.getDouble(_aiTemperatureKey) ?? 0.7;
    _aiMaxTokens = prefs.getInt(_aiMaxTokensKey) ?? 500;
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

  Future<void> setSelectedAIModel(String model) async {
    if (_selectedAIModel == model) return;

    _selectedAIModel = model;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_selectedAIModelKey, model);
  }

  Future<void> setAITemperature(double value) async {
    if (_aiTemperature == value) return;

    _aiTemperature = value.clamp(0.0, 1.0);
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_aiTemperatureKey, _aiTemperature);
  }

  Future<void> setAIMaxTokens(int value) async {
    if (_aiMaxTokens == value) return;

    _aiMaxTokens = value.clamp(100, 4096);
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_aiMaxTokensKey, _aiMaxTokens);
  }
}
