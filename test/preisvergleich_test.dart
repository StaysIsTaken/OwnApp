// „Dieser Zettel kostet bei Aldi 34 Euro, bei Rewe 39."
//
// Die Rechnung ist einfach. Schwierig ist, sie NICHT irrefuehrend zu
// machen -- und genau darum dreht sich die Haelfte dieser Tests.
//
// Die Falle: kennt man von Aldi drei Preise und von Rewe fuenfzehn, ist
// Aldis Summe kleiner. Nicht weil es billiger ist, sondern weil weniger
// drin steckt. Nebeneinandergestellt saehe das aus wie ein Preisvorteil
// und waere eine Luege aus lauter wahren Zahlen.

import 'package:flutter_test/flutter_test.dart';
import 'package:productivity/dataclasses/einkauf.dart';
import 'package:productivity/dataservice/einkauf_service.dart';
import 'package:productivity/dataservice/preisvergleich.dart';

Einkaufsposition posten(String name, {double? menge, bool erledigt = false}) =>
    Einkaufsposition(
      id: name.hashCode, listId: 1, name: name, menge: menge,
      erledigt: erledigt, orderIndex: 0,
    );

Warenpreis preis(String ware, String laden, double betrag) => Warenpreis(
      id: 0, bezeichnung: ware, shopId: laden, shopName: laden,
      preis: betrag,
    );

void main() {
  kennungen();

  test('zwei Laeden, drei Posten', () {
    final v = Preisvergleich.rechne(
      positionen: [posten('Milch'), posten('Butter')],
      preise: {
        'milch': [preis('milch', 'Aldi', 0.89), preis('milch', 'Rewe', 1.19)],
        'butter': [preis('butter', 'Aldi', 2.29), preis('butter', 'Rewe', 2.49)],
      },
    );
    expect(v.laeden.first.laden, 'Aldi');
    expect(v.laeden.first.summe, closeTo(3.18, 0.001));
    expect(v.laeden.last.summe, closeTo(3.68, 0.001));
    expect(v.verglichen, 2);
    expect(v.ersparnis, closeTo(0.50, 0.001));
  });

  test('die Menge zaehlt mit', () {
    // „Zwei Milch" ist etwas anderes als „Milch".
    final v = Preisvergleich.rechne(
      positionen: [posten('Milch', menge: 3)],
      preise: {'milch': [preis('milch', 'Aldi', 1.00)]},
    );
    expect(v.laeden.first.summe, closeTo(3.00, 0.001));
  });

  test('Abgehaktes zaehlt nicht mit', () {
    final v = Preisvergleich.rechne(
      positionen: [posten('Milch'), posten('Butter', erledigt: true)],
      preise: {
        'milch': [preis('milch', 'Aldi', 1.00)],
        'butter': [preis('butter', 'Aldi', 9.00)],
      },
    );
    expect(v.laeden.first.summe, closeTo(1.00, 0.001));
    expect(v.gesamt, 1);
  });

  test('Posten ohne Preis werden genannt statt verschluckt', () {
    // Sonst wundert man sich im Laden, warum die Summe nicht stimmt.
    final v = Preisvergleich.rechne(
      positionen: [posten('Milch'), posten('Batterien')],
      preise: {'milch': [preis('milch', 'Aldi', 1.00)]},
    );
    expect(v.ohnePreis, ['Batterien']);
    expect(v.verglichen, 1);
    expect(v.gesamt, 2);
  });

  test('ungleiche Abdeckung verzerrt die Summen NICHT', () {
    // Der Kern. Aldi kennt beide Posten, Rewe nur einen. Wuerde stur
    // summiert, staende Rewe mit 1,19 gegen Aldis 3,18 da -- und saehe
    // aus wie der Preisknueller.
    final v = Preisvergleich.rechne(
      positionen: [posten('Milch'), posten('Butter')],
      preise: {
        'milch': [preis('milch', 'Aldi', 0.89), preis('milch', 'Rewe', 1.19)],
        'butter': [preis('butter', 'Aldi', 2.29)],
      },
    );
    // Verglichen wird nur, was beide fuehren: die Milch.
    expect(v.verglichen, 1);
    expect(v.nichtUeberall, ['Butter']);
    final summen = {for (final l in v.laeden) l.laden: l.summe};
    expect(summen['Aldi'], closeTo(0.89, 0.001));
    expect(summen['Rewe'], closeTo(1.19, 0.001));
    // Und damit stimmt die Reihenfolge wieder.
    expect(v.laeden.first.laden, 'Aldi');
  });

  test('kennt nur ein Laden etwas, steht er allein da', () {
    final v = Preisvergleich.rechne(
      positionen: [posten('Milch')],
      preise: {'milch': [preis('milch', 'Aldi', 0.89)]},
    );
    expect(v.laeden.single.laden, 'Aldi');
    // Ohne zweiten Laden gibt es nichts zu sparen.
    expect(v.ersparnis, 0);
  });

  test('ohne jeden Preis ist der Vergleich leer', () {
    final v = Preisvergleich.rechne(
      positionen: [posten('Batterien')],
      preise: const {},
    );
    expect(v.leer, isTrue);
    expect(v.ohnePreis, ['Batterien']);
  });

  test('leere Liste ist leer', () {
    final v = Preisvergleich.rechne(positionen: const [], preise: const {});
    expect(v.leer, isTrue);
    expect(v.gesamt, 0);
  });

  test('bei zwei Eintraegen je Laden gewinnt der guenstigere', () {
    final v = Preisvergleich.rechne(
      positionen: [posten('Milch')],
      preise: {
        'milch': [preis('milch', 'Aldi', 1.29), preis('milch', 'Aldi', 0.89)],
      },
    );
    expect(v.laeden.single.summe, closeTo(0.89, 0.001));
  });

  test('Grossschreibung im Postennamen stoert nicht', () {
    // Das Gedaechtnis fuehrt kleingeschrieben; die Liste nicht.
    final v = Preisvergleich.rechne(
      positionen: [posten('  MILCH ')],
      preise: {'milch': [preis('milch', 'Aldi', 0.89)]},
    );
    expect(v.verglichen, 1);
  });
}

// Nachtrag, aus einem alten Fehler gelernt.
//
// Beim alten Modell ging eine leere `unitId` als `''` mit, der
// Fremdschluessel lehnte sie ab, der Server stuerzte ab -- und weil ein
// abgestuerzter Server keine CORS-Kopfzeilen mehr setzt, meldete der
// Browser einen CORS-Fehler statt des echten Grundes. Die alte Klasse ist
// weg, die Falle nicht: Darts `?wert` laesst nur null weg, nicht den
// leeren String.
void kennungen() {
  group('Ein leerer String ist keine Kennung', () {
    test('leer wird zu null', () {
      expect(EinkaufService.kennung(''), isNull);
    });

    test('null bleibt null', () {
      expect(EinkaufService.kennung(null), isNull);
    });

    test('eine echte Kennung geht durch', () {
      expect(EinkaufService.kennung('u1'), 'u1');
    });
  });
}
