import 'package:flutter_test/flutter_test.dart';
import 'package:productivity/dataclasses/einkauf.dart';
import 'package:productivity/dataservice/einkauf_service.dart';
import 'package:productivity/dataservice/finanz_rechnung.dart';

/// Die Brücke von der Einkaufsliste ins Haushaltsbuch, App-Seite.
///
/// Was hier geprüft wird, ist bewusst wenig Rechnung und viel
/// **Ehrlichkeit**: die Summe ist eine Schätzung, und der Nutzer muss das
/// erfahren. Ein Betrag ohne diesen Hinweis sähe aus wie eine Tatsache —
/// und wer ihn später im Kassenbuch wiederfindet, könnte ihn nicht mehr
/// als Schätzung erkennen.
Buchungsvorschlag _v({
  int summe = 3418,
  int anzahl = 7,
  List<String> ohnePreis = const [],
  String laden = 'Aldi',
}) =>
    Buchungsvorschlag(
      shopId: 's1',
      laden: laden,
      summeCents: summe,
      anzahl: anzahl,
      ohnePreis: ohnePreis,
    );

void main() {
  group('Der Vorschlag', () {
    test('aus JSON', () {
      final v = Buchungsvorschlag.fromJson(const {
        'shop_id': 's1',
        'laden': 'Aldi',
        'summe_cents': 3418,
        'anzahl': 7,
        'ohne_preis': ['Batterien', 'Backpapier'],
      });
      expect(v.laden, 'Aldi');
      expect(v.summeCents, 3418);
      expect(v.ohnePreis.length, 2);
      expect(v.vollstaendig, isFalse);
      expect(v.leer, isFalse);
    });

    test('ohne bekannte Preise ist er leer, nicht kaputt', () {
      // Der Laden kennt nichts von diesem Zettel. Die Liste ist trotzdem
      // in Ordnung — der Nutzer tippt den Betrag eben selbst.
      final v = Buchungsvorschlag.fromJson(const {
        'shop_id': 's1',
        'laden': 'Baumarkt',
        'summe_cents': 0,
        'anzahl': 0,
        'ohne_preis': ['Schrauben'],
      });
      expect(v.leer, isTrue);
      expect(v.summeCents, 0);
    });

    test('fehlende Felder werfen nicht', () {
      // App und Backend werden nicht im Gleichschritt ausgerollt.
      final v = Buchungsvorschlag.fromJson(const {'laden': 'Aldi'});
      expect(v.summeCents, 0);
      expect(v.ohnePreis, isEmpty);
      expect(v.leer, isTrue);
    });

    test('vollständig heisst: kein Posten fehlt in der Summe', () {
      expect(_v().vollstaendig, isTrue);
      expect(_v(ohnePreis: const ['Batterien']).vollstaendig, isFalse);
    });
  });

  group('Die Kennung gegen die Doppelbuchung', () {
    test('trägt Liste und Tag', () {
      expect(
        EinkaufService.einkaufsKennung(12, DateTime(2026, 3, 14)),
        'einkauf:12:2026-03-14',
      );
    });

    test('ist zweistellig aufgefüllt', () {
      // Sonst wären „2026-3-4" und „2026-03-04" zwei verschiedene
      // Kennungen für denselben Tag — und die Sperre liefe ins Leere.
      expect(
        EinkaufService.einkaufsKennung(1, DateTime(2026, 3, 4)),
        'einkauf:1:2026-03-04',
      );
    });

    test('derselbe Tag ergibt dieselbe Kennung', () {
      expect(
        EinkaufService.einkaufsKennung(5, DateTime(2026, 3, 14)),
        EinkaufService.einkaufsKennung(5, DateTime(2026, 3, 14, 23, 59)),
      );
    });

    test('anderer Tag oder andere Liste ergibt eine andere', () {
      final a = EinkaufService.einkaufsKennung(5, DateTime(2026, 3, 14));
      expect(a,
          isNot(EinkaufService.einkaufsKennung(5, DateTime(2026, 3, 15))));
      expect(a,
          isNot(EinkaufService.einkaufsKennung(6, DateTime(2026, 3, 14))));
    });
  });

  group('Der Betrag geht so in den Dialog, wie er dort steht', () {
    test('Cent werden zum Text und wieder zurück', () {
      // Der Dialog belegt sein Feld mit `nurBetrag` vor und liest es mit
      // `cents` wieder ein. Driftet das auseinander, bucht der Nutzer
      // einen anderen Betrag als den vorgeschlagenen.
      for (final cents in [89, 3418, 100000, 1]) {
        final text = Finanzrechnung.nurBetrag(cents).replaceAll(' €', '');
        expect(Finanzrechnung.cents(text), cents, reason: text);
      }
    });
  });
}
