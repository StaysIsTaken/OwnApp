import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:productivity/dataservice/local_notification_manager.dart';
import 'package:productivity/dataservice/journal_reminder_service.dart';

class SettingsProvider extends ChangeNotifier {
  static const String _timeFormatKey = 'use_24h_format';
  static const String _darkModeKey = 'is_dark_mode';
  static const String _selectedAIModelKey = 'selected_ai_model';
  static const String _aiTemperatureKey = 'ai_temperature';
  static const String _aiMaxTokensKey = 'ai_max_tokens';
  static const String _weatherCityKey = 'weather_city';

  bool _use24hFormat = true;
  bool _isDarkMode = true;
  String _selectedAIModel = '';
  double _aiTemperature = 0.7;
  int _aiMaxTokens = 500;
  String _weatherCity = '';
  bool _journalReminderEnabled = false;
  int _journalReminderHour = 20;
  int _journalReminderMinute = 0;

  bool get use24hFormat => _use24hFormat;
  bool get isDarkMode => _isDarkMode;
  String get selectedAIModel => _selectedAIModel;
  double get aiTemperature => _aiTemperature;
  int get aiMaxTokens => _aiMaxTokens;
  String get weatherCity => _weatherCity;
  bool get journalReminderEnabled => _journalReminderEnabled;
  int get journalReminderHour => _journalReminderHour;
  int get journalReminderMinute => _journalReminderMinute;

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
    _journalReminderEnabled =
        prefs.getBool(LocalNotificationManager.prefJournalReminderEnabled) ?? false;
    _journalReminderHour =
        prefs.getInt(LocalNotificationManager.prefJournalReminderHour) ?? 20;
    _journalReminderMinute =
        prefs.getInt(LocalNotificationManager.prefJournalReminderMinute) ?? 0;
    notifyListeners();
  }

  Future<void> setWeatherCity(String value) async {
    final v = value.trim();
    if (_weatherCity == v) return;
    _weatherCity = v;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_weatherCityKey, v);
  }

  /// Übernimmt den serverseitigen Stand OHNE erneut ans Backend zu schreiben.
  Future<void> hydrateJournalReminder(bool enabled, int hour, int minute) async {
    _journalReminderEnabled = enabled;
    _journalReminderHour = hour;
    _journalReminderMinute = minute;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(LocalNotificationManager.prefJournalReminderEnabled, enabled);
    await prefs.setInt(LocalNotificationManager.prefJournalReminderHour, hour);
    await prefs.setInt(LocalNotificationManager.prefJournalReminderMinute, minute);
  }

  Future<void> setJournalReminderEnabled(bool value) async {
    _journalReminderEnabled = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(LocalNotificationManager.prefJournalReminderEnabled, value);
    // Serverseitig speichern -> Backend löst zur Uhrzeit aus (n8n/ntfy).
    await JournalReminderService.save(
        enabled: value, hour: _journalReminderHour, minute: _journalReminderMinute);
  }

  Future<void> setJournalReminderTime(int hour, int minute) async {
    _journalReminderHour = hour;
    _journalReminderMinute = minute;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(LocalNotificationManager.prefJournalReminderHour, hour);
    await prefs.setInt(LocalNotificationManager.prefJournalReminderMinute, minute);
    await JournalReminderService.save(
        enabled: _journalReminderEnabled, hour: hour, minute: minute);
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
