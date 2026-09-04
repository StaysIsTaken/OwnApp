import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:productivity/dataservice/api_client.dart';

/// Die eigenen Rechte — damit die Oberfläche nur zeigt, was auch geht.
///
/// Das ist ausdrücklich **keine** Absicherung. Geprüft wird an jedem
/// Endpunkt im Backend; hier geht es nur darum, niemandem Menüeinträge
/// hinzulegen, die alle in eine Fehlermeldung laufen.
class PermissionProvider extends ChangeNotifier {
  Set<String> _rechte = {};
  List<String> _rollen = [];
  bool _geladen = false;
  DateTime? _zuletztGeholt;

  PermissionProvider() {
    // Ein 403 heisst fast immer: die Rollen haben sich geaendert. Dann die
    // Rechte neu holen, damit das Menue sich berichtigt.
    ApiClient.onForbidden = _nachladen;
  }

  /// Nicht oefter als alle 30 Sekunden — sonst wuerde eine Seite mit
  /// mehreren gesperrten Abfragen einen Schwall ausloesen.
  static const Duration _abstand = Duration(seconds: 30);

  void _nachladen() {
    final jetzt = DateTime.now();
    if (_zuletztGeholt != null && jetzt.difference(_zuletztGeholt!) < _abstand) {
      return;
    }
    laden();
  }

  Set<String> get rechte => _rechte;
  List<String> get rollen => _rollen;
  bool get geladen => _geladen;

  /// Niemand hat irgendein Recht — der Nutzer ist angemeldet, aber noch
  /// nicht freigeschaltet. Die App zeigt dafür einen Hinweis statt lauter
  /// leerer Seiten.
  bool get istGesperrt => _geladen && _rechte.isEmpty;

  /// `*` schließt alles ein.
  bool darf(String recht) =>
      _rechte.contains('*') || _rechte.contains(recht);

  bool get darfVerwalten => darf('admin:roles') || darf('admin:users');

  /// Darf die Tablet-Ansicht benutzen. Nur dann erscheint der Schalter auf
  /// der Startseite — ohne das Recht gäbe es dort nichts einzuschalten.
  bool get darfTablet => darf('tablet:use');

  Future<void> laden() async {
    try {
      final r = await ApiClient.dio.get('/users/me/permissions');
      final d = r.data as Map<String, dynamic>;
      _rechte = (d['permissions'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toSet();
      _rollen = (d['roles'] as List<dynamic>? ?? [])
          .map((e) => (e as Map<String, dynamic>)['name'].toString())
          .toList();
      _geladen = true;
      _zuletztGeholt = DateTime.now();
    } on DioException {
      // Kein Netz oder ein altes Backend ohne diesen Endpunkt: dann lieber
      // alles anzeigen als alles verstecken. Wer etwas nicht darf, bekommt
      // ohnehin eine klare Meldung vom Server — eine App, die aus Versehen
      // ihr halbes Menü versteckt, wäre das schlechtere Verhalten.
      _rechte = {'*'};
      _geladen = true;
      _zuletztGeholt = DateTime.now();
    }
    notifyListeners();
  }

  /// Rechte von außen setzen — für Tests und für den Fall, dass sie
  /// woanders schon geladen wurden.
  void uebernehmen(Set<String> rechte, {List<String> rollen = const []}) {
    _rechte = rechte;
    _rollen = rollen;
    _geladen = true;
    _zuletztGeholt = DateTime.now();
    notifyListeners();
  }

  void leeren() {
    _rechte = {};
    _rollen = [];
    _geladen = false;
    _zuletztGeholt = null;
    notifyListeners();
  }
}
