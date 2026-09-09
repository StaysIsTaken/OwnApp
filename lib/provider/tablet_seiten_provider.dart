import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:productivity/dataclasses/dashboard_page.dart';
import 'package:productivity/dataservice/api_error.dart';
import 'package:productivity/dataservice/dashboard_page_service.dart';

/// Die Seiten der Küchenansicht und welche davon gerade sichtbar ist.
///
/// Lag vorher als privater State in [TabletDashboard]. Herausgezogen, weil die
/// Sprachsteuerung von außen umschalten muss („Jarvis, geh zum Kalender") — an
/// privaten Widget-State kommt sie nicht heran.
class TabletSeitenProvider extends ChangeNotifier {
  /// Kürzer als drei Zeichen wird nicht als Teilstring gesucht: eine Seite
  /// namens „Zu" würde sonst in fast jedem gesprochenen Satz vorkommen.
  static const int _minLaengeFuerTeiltreffer = 3;

  List<DashboardSeite> _seiten = [];
  int _aktuell = 0;
  bool _laedt = true;
  String? _fehler;

  List<DashboardSeite> get seiten => _seiten;
  int get aktuell => _aktuell;
  bool get laedt => _laedt;
  String? get fehler => _fehler;

  /// Die sichtbare Seite, oder null solange keine geladen ist.
  DashboardSeite? get seite => _seiten.isEmpty ? null : _seiten[_aktuell];

  Future<void> laden() async {
    _laedt = true;
    _fehler = null;
    notifyListeners();
    try {
      final seiten =
          await DashboardPageService.laden(mode: DashboardSeite.modeTablet);
      _seiten = seiten;
      _aktuell = seiten.isEmpty ? 0 : _aktuell.clamp(0, seiten.length - 1);
      _laedt = false;
    } on DioException catch (e) {
      _laedt = false;
      _fehler = ApiFehler.text(e);
    }
    notifyListeners();
  }

  /// Zählt hoch, wenn sich die Daten hinter den Kacheln geändert haben.
  /// Der Seiteninhalt hängt daran als Key und baut sich dann neu auf — sonst
  /// trüge man per Sprache einen Termin ein und der Kalender daneben zeigte
  /// ihn erst beim nächsten Seitenwechsel.
  int _stand = 0;
  int get stand => _stand;

  void neuLaden() {
    _stand++;
    notifyListeners();
  }

  /// Nur für Tests: Seiten setzen, ohne den Server zu fragen.
  @visibleForTesting
  void setzeSeitenFuerTest(List<DashboardSeite> seiten) {
    _seiten = seiten;
    _aktuell = 0;
    _laedt = false;
    notifyListeners();
  }

  void wechsleZu(int index) {
    if (index < 0 || index >= _seiten.length || index == _aktuell) return;
    _aktuell = index;
    notifyListeners();
  }

  /// Springt auf die letzte Seite — nach dem Anlegen steht man dort, wo man
  /// gerade etwas Neues gemacht hat.
  void zurLetzten() {
    if (_seiten.isEmpty) return;
    _aktuell = _seiten.length - 1;
    notifyListeners();
  }

  void zurErsten() {
    _aktuell = 0;
    notifyListeners();
  }

  /// Sucht die Seite, die zum gesprochenen Namen passt, und wechselt dorthin.
  ///
  /// Rückgabe: der Name der getroffenen Seite (zum Vorlesen), sonst null.
  ///
  /// Bei mehreren Treffern gewinnt der längste Name: wer „Einkaufsliste" sagt,
  /// meint nicht die Seite „Einkauf", auch wenn deren Name ebenfalls vorkommt.
  String? wechsleNach(String gesprochen) {
    final gesucht = _normalisiere(gesprochen);
    if (gesucht.isEmpty) return null;

    int? treffer;
    var besteLaenge = 0;
    for (var i = 0; i < _seiten.length; i++) {
      final name = _normalisiere(_seiten[i].name);
      if (name.isEmpty) continue;
      final passt = name == gesucht ||
          (name.length >= _minLaengeFuerTeiltreffer &&
              (gesucht.contains(name) || name.contains(gesucht)));
      if (passt && name.length > besteLaenge) {
        treffer = i;
        besteLaenge = name.length;
      }
    }
    if (treffer == null) return null;
    wechsleZu(treffer);
    return _seiten[treffer].name;
  }

  /// Kleinschreibung und weg mit allem, was kein Buchstabe ist. Whisper
  /// schreibt „Kalender-Ansicht." und die Seite heißt „Kalender Ansicht" —
  /// ohne das Einebnen fände sich nichts.
  String _normalisiere(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[^a-zäöüß0-9]'), '');
}
