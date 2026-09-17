import 'package:flutter/material.dart';
import 'package:productivity/dataclasses/einstellungen.dart';
import 'package:productivity/dataservice/einstellungs_abgleich.dart';
import 'package:productivity/dataservice/einstellungs_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Einstellungen — teils am Konto, teils am Gerät.
///
/// **Am Konto** hängen 24-Stunden-Anzeige, Wetterort und die drei
/// KI-Werte. Sie gelten für die Person, nicht für das Gerät in ihrer
/// Hand, und sie kommen seit `user_settings` vom Server.
///
/// **Am Gerät** bleiben Weckwort, Schwelle und Hell-/Dunkelmodus:
/// gelauscht wird in der Küche und nicht auf dem Telefon in der
/// Hosentasche, und das Tablet an der Wand will tagsüber hell, während
/// das Telefon dunkel bleibt. Eine Person, zwei Antworten.
///
/// Die SharedPreferences bleiben für beides zuständig — für das eine als
/// Wohnort, für das andere als **Zwischenspeicher**. Ohne den stünde die
/// App nach dem Start ohne Einstellungen da, bis der Server antwortet;
/// mit ihm zeigt sie sofort den letzten bekannten Stand und zieht nach.
class SettingsProvider extends ChangeNotifier {
  static const String _timeFormatKey = 'use_24h_format';
  static const String _darkModeKey = 'is_dark_mode';
  static const String _selectedAIModelKey = 'selected_ai_model';
  static const String _aiTemperatureKey = 'ai_temperature';
  static const String _aiMaxTokensKey = 'ai_max_tokens';
  static const String _weatherCityKey = 'weather_city';

  // Wakeword des Kuechenassistenten. Liegt am Geraet und nicht am Konto:
  // gelauscht wird in der Kueche, nicht auf dem Telefon in der Hosentasche.
  //
  // Die Schwelle ist einstellbar, weil sie sich nur vor Ort finden laesst.
  // Wie empfindlich ein Weckwort sein darf, haengt am Raum, am Mikrofon und
  // daran, ob nebenbei der Fernseher laeuft — das kann keine Vorgabe im Code
  // wissen, und dafuer soll niemand die App neu bauen muessen.
  static const String _wakewordAnKey = 'wakeword_an';
  static const String _wakewordSchwelleKey = 'wakeword_schwelle';

  /// Ob dieses Gerät seine Einstellungen schon ans Konto übergeben hat.
  /// Siehe [Einstellungsabgleich.uebergabe] — ohne diesen Merker liefe
  /// die Übergabe bei jeder Anmeldung erneut und schöbe alte
  /// Gerätestände wieder hoch.
  static const String _uebertragenKey = 'einstellungen_uebertragen';

  bool _use24hFormat = true;
  bool _isDarkMode = true;
  String _selectedAIModel = '';
  double _aiTemperature = 0.7;
  int _aiMaxTokens = 500;
  String _weatherCity = '';
  bool _wakewordAn = true;
  double _wakewordSchwelle = 0.25;

  bool get use24hFormat => _use24hFormat;
  bool get isDarkMode => _isDarkMode;
  String get selectedAIModel => _selectedAIModel;
  double get aiTemperature => _aiTemperature;
  int get aiMaxTokens => _aiMaxTokens;
  String get weatherCity => _weatherCity;
  bool get wakewordAn => _wakewordAn;

  /// `keywordsThreshold` des Erkenners. Klein heißt empfindlich.
  double get wakewordSchwelle => _wakewordSchwelle;

  /// Grenzen des Reglers. Über 0,5 spricht Jarvis praktisch nie an, unter
  /// 0,05 dauernd — beides ist keine sinnvolle Einstellung mehr.
  static const double schwelleMin = 0.05;
  static const double schwelleMax = 0.50;

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
    _wakewordAn = prefs.getBool(_wakewordAnKey) ?? true;
    _wakewordSchwelle =
        prefs.getDouble(_wakewordSchwelleKey)?.clamp(schwelleMin, schwelleMax) ??
            0.25;
    notifyListeners();
  }

  Future<void> setWakewordSchwelle(double value) async {
    final v = value.clamp(schwelleMin, schwelleMax);
    if (_wakewordSchwelle == v) return;
    _wakewordSchwelle = v;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_wakewordSchwelleKey, v);
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
    await _zumKonto({'weather_city': v});
  }

  Future<void> setUse24hFormat(bool value) async {
    if (_use24hFormat == value) return;
    
    _use24hFormat = value;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_timeFormatKey, value);
    await _zumKonto({'use_24h': value});
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
    await _zumKonto({'ai_model': model});
  }

  Future<void> setAITemperature(double value) async {
    if (_aiTemperature == value) return;

    _aiTemperature = value.clamp(0.0, 1.0);
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_aiTemperatureKey, _aiTemperature);
    await _zumKonto({'ai_temperature': _aiTemperature});
  }

  Future<void> setAIMaxTokens(int value) async {
    if (_aiMaxTokens == value) return;

    _aiMaxTokens = value.clamp(100, 4096);
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_aiMaxTokensKey, _aiMaxTokens);
    await _zumKonto({'ai_max_tokens': _aiMaxTokens});
  }

  // ── Der Weg zum Konto ──────────────────────────────────────────────

  /// Schickt eine Änderung an den Server — und macht kein Drama daraus.
  ///
  /// Der Wert steht schon lokal und ist schon angezeigt; scheitert das
  /// Hochschicken (kein Netz, abgemeldet, altes Backend), soll die
  /// Einstellung trotzdem gelten. Beim nächsten Anmelden holt
  /// [vomKonto] den Stand des Servers, und dann gewinnt der — das ist
  /// die Regel, und ein verschluckter Fehler hier ändert sie nicht.
  Future<void> _zumKonto(Map<String, dynamic> daten) async {
    try {
      await EinstellungsService.aendern(daten);
    } catch (_) {
      // absichtlich verschluckt, s. o.
    }
  }

  /// Holt die Einstellungen des angemeldeten Kontos und übernimmt sie.
  ///
  /// Wird beim Anmelden gerufen, zusammen mit Rechten und Haushalt — es
  /// gilt pro Konto, also hängt es am selben Zeitpunkt.
  ///
  /// Beim **ersten** Mal auf diesem Gerät geht es vorher andersherum:
  /// was der Server noch nicht weiß, lernt er von hier. Danach nie
  /// wieder; die Regel steht in [Einstellungsabgleich.uebergabe].
  Future<void> vomKonto() async {
    Einstellungen konto;
    try {
      konto = await EinstellungsService.lesen();
    } catch (_) {
      // Kein Netz oder ein Backend ohne diesen Endpunkt: dann gilt
      // weiter, was im Zwischenspeicher steht. Das ist kein Fehlerfall,
      // den der Nutzer sehen müsste — er merkt nichts, weil alles
      // dasteht.
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final uebergabe = Einstellungsabgleich.uebergabe(
      schonUebertragen: prefs.getBool(_uebertragenKey) ?? false,
      vomServer: konto,
      geraetUse24h: _use24hFormat,
      geraetWetterOrt: _weatherCity,
      geraetKiModell: _selectedAIModel,
      geraetKiTemperatur: _aiTemperature,
      geraetKiMaxTokens: _aiMaxTokens,
    );

    if (uebergabe.isNotEmpty) {
      try {
        konto = await EinstellungsService.aendern(uebergabe);
      } catch (_) {
        // Beim nächsten Anmelden nochmal — der Merker bleibt ungesetzt.
        return;
      }
    }
    await prefs.setBool(_uebertragenKey, true);

    _use24hFormat = konto.use24h;
    _weatherCity = konto.wetterOrt ?? '';
    _selectedAIModel = konto.kiModell ?? '';
    _aiTemperature = konto.kiTemperatur ?? _aiTemperature;
    _aiMaxTokens = konto.kiMaxTokens ?? _aiMaxTokens;

    // In den Zwischenspeicher, damit der nächste Start sofort den
    // richtigen Stand zeigt, statt erst auf den Server zu warten.
    await prefs.setBool(_timeFormatKey, _use24hFormat);
    await prefs.setString(_weatherCityKey, _weatherCity);
    await prefs.setString(_selectedAIModelKey, _selectedAIModel);
    await prefs.setDouble(_aiTemperatureKey, _aiTemperature);
    await prefs.setInt(_aiMaxTokensKey, _aiMaxTokens);

    notifyListeners();
  }
}
