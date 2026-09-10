import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  static const String _timeFormatKey = 'use_24h_format';
  static const String _darkModeKey = 'is_dark_mode';
  static const String _selectedAIModelKey = 'selected_ai_model';
  static const String _aiTemperatureKey = 'ai_temperature';
  static const String _aiMaxTokensKey = 'ai_max_tokens';
  static const String _weatherCityKey = 'weather_city';

  // Wakeword des Kuechenassistenten. Beides liegt am Geraet und nicht am
  // Konto: gelauscht wird in der Kueche, nicht auf dem Telefon in der
  // Hosentasche. Der AccessKey steht bewusst hier und nicht im
  // flutter_secure_storage — dort liegt das Anmeldepasswort, waehrend dieser
  // Schluessel eher der API-Adresse gleicht: eine Geraeteeinstellung, die man
  // im Zweifel vorlesen kann.
  static const String _wakewordKeyKey = 'wakeword_access_key';
  static const String _wakewordAnKey = 'wakeword_an';

  bool _use24hFormat = true;
  bool _isDarkMode = true;
  String _selectedAIModel = '';
  double _aiTemperature = 0.7;
  int _aiMaxTokens = 500;
  String _weatherCity = '';
  String _wakewordKey = '';
  bool _wakewordAn = true;

  bool get use24hFormat => _use24hFormat;
  bool get isDarkMode => _isDarkMode;
  String get selectedAIModel => _selectedAIModel;
  double get aiTemperature => _aiTemperature;
  int get aiMaxTokens => _aiMaxTokens;
  String get weatherCity => _weatherCity;
  String get wakewordKey => _wakewordKey;
  bool get wakewordAn => _wakewordAn;

  /// Ohne Schlüssel gibt es kein Wakeword — der Schalter allein genügt nicht.
  bool get wakewordMoeglich => _wakewordAn && _wakewordKey.trim().isNotEmpty;

  SettingsProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _use24hFormat = prefs.getBool(_timeFormatKey) ?? true;
    _isDarkMode = prefs.getBool(_darkModeKey) ?? true;
    _selectedAIModel = prefs.getString(_selectedAIModelKey) ?? '';
    _aiTemperature = prefs.getDouble(_aiTemperatureKey) ?? 0.7;
    _aiMaxTokens = prefs.getInt(_aiMaxTokensKey) ?? 500;
    _weatherCity = prefs.getString(_weatherCityKey) ?? '';
    _wakewordKey = prefs.getString(_wakewordKeyKey) ?? '';
    _wakewordAn = prefs.getBool(_wakewordAnKey) ?? true;
    notifyListeners();
  }

  Future<void> setWakewordKey(String value) async {
    final v = value.trim();
    if (_wakewordKey == v) return;
    _wakewordKey = v;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_wakewordKeyKey, v);
  }

  Future<void> setWakewordAn(bool value) async {
    if (_wakewordAn == value) return;
    _wakewordAn = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_wakewordAnKey, value);
  }

  Future<void> setWeatherCity(String value) async {
    final v = value.trim();
    if (_weatherCity == v) return;
    _weatherCity = v;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_weatherCityKey, v);
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
