import 'package:flutter/material.dart';
import 'package:productivity/dataclasses/haushalt.dart';
import 'package:productivity/dataservice/haushalt_service.dart';

/// Der eigene Haushalt — app-weit, weil ihn mehr als eine Seite braucht.
///
/// Er liegt aus demselben Grund in einem Provider wie `TimerProvider` und
/// `TabletSeitenProvider`: das **Menü** muss wissen, ob es den Abschnitt
/// überhaupt zeigt, und an privaten Zustand einer Seite kommt es nicht
/// heran.
///
/// **`null` ist der Normalfall, kein Fehler.** Wer in keinem Haushalt ist,
/// soll von dem ganzen Bereich nichts merken — deshalb wird hier auch
/// nichts protokolliert und nichts gemeldet, wenn keiner da ist.
class HaushaltProvider extends ChangeNotifier {
  Haushalt? _haushalt;
  List<Einladung> _einladungen = const [];
  bool _geladen = false;

  Haushalt? get haushalt => _haushalt;
  List<Einladung> get einladungen => _einladungen;
  bool get geladen => _geladen;

  bool get imHaushalt => _haushalt != null;

  /// Die eigene Zeile im Haushalt — für die Finanz-Sichtbarkeit.
  Mitglied? mitglied(String userId) => _haushalt?.mitglied(userId);

  /// Holt Haushalt und offene Einladungen.
  ///
  /// **Die Einladung kommt beim Öffnen der App an, nicht als Meldung.**
  /// Ein WebSocket-Anstoß wie `planner_changed` wäre möglich, hilft aber
  /// nur bei offener App — und eine Einladung eilt selten so, dass sich
  /// dafür ein zweiter Weg lohnt.
  ///
  /// Schlägt etwas fehl, bleibt es still: ein älteres Backend kennt
  /// `/haushalt` nicht, und daraus eine Fehlermeldung zu machen hieße,
  /// jemandem von einem Bereich zu erzählen, den er nicht benutzt.
  Future<void> laden() async {
    try {
      final haushalt = await HaushaltService.meiner();
      List<Einladung> einladungen = const [];
      try {
        einladungen = await HaushaltService.meineEinladungen();
      } catch (_) {
        einladungen = const [];
      }
      _haushalt = haushalt;
      _einladungen = einladungen;
    } catch (_) {
      _haushalt = null;
      _einladungen = const [];
    }
    _geladen = true;
    notifyListeners();
  }

  /// Von außen setzen — für Tests und nach einer Änderung auf der Seite,
  /// damit das Menü sich sofort berichtigt, ohne erst nachzuladen.
  void uebernehmen(Haushalt? haushalt,
      {List<Einladung> einladungen = const []}) {
    _haushalt = haushalt;
    _einladungen = einladungen;
    _geladen = true;
    notifyListeners();
  }

  void leeren() {
    _haushalt = null;
    _einladungen = const [];
    _geladen = false;
    notifyListeners();
  }
}
