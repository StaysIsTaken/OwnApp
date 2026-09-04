import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Ob dieses Gerät im Küchenmodus läuft.
///
/// **Bewusst am Gerät gespeichert, nicht am Konto.** Dasselbe Konto meldet
/// sich am Küchentablet und am Telefon an — der Küchenmodus gehört zum
/// Tablet, nicht zur Person. Läge er im Konto, ginge das Telefon mit in
/// den Küchenmodus, sobald man ihn dort einschaltet.
class TabletProvider extends ChangeNotifier {
  static const String _schluessel = 'tablet_modus';

  bool _an = false;
  bool _geladen = false;

  bool get an => _an;
  bool get geladen => _geladen;

  TabletProvider() {
    laden();
  }

  Future<void> laden() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _an = prefs.getBool(_schluessel) ?? false;
    } catch (_) {
      // Kein Speicher verfügbar: dann eben aus. Der Küchenmodus ist nichts,
      // in dem man versehentlich landen sollte.
      _an = false;
    }
    _geladen = true;
    notifyListeners();
  }

  Future<void> setzen(bool an) async {
    _an = an;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_schluessel, an);
    } catch (_) {
      // Nicht speicherbar: gilt wenigstens bis zum Neustart.
    }
  }
}
