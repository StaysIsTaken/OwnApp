import 'package:flutter_test/flutter_test.dart';
import 'package:productivity/dataclasses/finanzen.dart';
import 'package:productivity/dataservice/finanz_rechnung.dart';
import 'package:productivity/dataservice/finanz_service.dart';

/// Die Rechnung des Haushaltsbuchs.
///
/// Sie steht in einer eigenen Datei und nicht in der Seite, damit genau
/// das hier möglich ist — eine Seite, die beim Aufbau lädt, zeigt im Test
/// nur den Ladekreis.
///
/// Der Schwerpunkt liegt auf dem Einlesen von Beträgen. Das sieht nach
/// einer Kleinigkeit aus und ist die Stelle, an der still falsche Zahlen
/// ins Kassenbuch kommen: „1.234" heisst auf Deutsch etwas anderes als
/// „12.34", und beides wird getippt.
Buchung _b(int id, String tag, int cents, {String titel = 'X'}) => Buchung(
      id: id,
      kasseId: 1,
      tag: DateTime.parse(tag),
      cents: cents,
      titel: titel,
    );

void main() {
  group('Beträge anzeigen', () {
    test('Ausgabe bekommt ein echtes Minuszeichen', () {
      // Nicht der Bindestrich: in einer Spalte aus Beträgen sitzt er zu
      // hoch und zu kurz, und man übersieht ihn.
      expect(Finanzrechnung.alsText(-4783), '−47,83 €');
      expect(Finanzrechnung.alsText(-4783).startsWith('−'), isTrue);
    });

    test('Einnahme bekommt ein Plus', () {
      expect(Finanzrechnung.alsText(250000), '+2.500,00 €');
    });

    test('ohne Vorzeichen für Summen, deren Richtung danebensteht', () {
      expect(Finanzrechnung.nurBetrag(-32000), '320,00 €');
      expect(Finanzrechnung.nurBetrag(0), '0,00 €');
    });

    test('Tausenderpunkte sitzen richtig', () {
      expect(Finanzrechnung.nurBetrag(100), '1,00 €');
      expect(Finanzrechnung.nurBetrag(100000), '1.000,00 €');
      expect(Finanzrechnung.nurBetrag(123456789), '1.234.567,89 €');
    });

    test('einstellige Cent werden aufgefüllt', () {
      expect(Finanzrechnung.nurBetrag(905), '9,05 €');
    });
  });

  group('Beträge einlesen', () {
    test('Komma trennt die Nachkommastellen', () {
      expect(Finanzrechnung.cents('12,50'), 1250);
    });

    test('Punkt tut es auch – aus der Banking-App kopiert', () {
      expect(Finanzrechnung.cents('12.50'), 1250);
    });

    test('eine Nachkommastelle wird aufgefüllt', () {
      expect(Finanzrechnung.cents('12,5'), 1250);
    });

    test('ohne Trennzeichen sind es ganze Euro', () {
      expect(Finanzrechnung.cents('12'), 1200);
    });

    test('„1.234" ist auf Deutsch eintausendzweihundertvierunddreissig', () {
      // Die wichtigste Zeile dieser Datei. Läse man das als 1,23 €,
      // verschwänden bei jeder vierstelligen Summe drei Nullen.
      expect(Finanzrechnung.cents('1.234'), 123400);
    });

    test('mehrfacher Punkt ist immer Tausendertrennung', () {
      expect(Finanzrechnung.cents('1.234.567'), 123456700);
    });

    test('beide Zeichen: das letzte trennt die Nachkommastellen', () {
      expect(Finanzrechnung.cents('1.234,56'), 123456);
      expect(Finanzrechnung.cents('1,234.56'), 123456);
    });

    test('Euro-Zeichen und Leerzeichen stören nicht', () {
      expect(Finanzrechnung.cents(' 12,50 € '), 1250);
      expect(Finanzrechnung.cents('12,50€'), 1250);
    });

    test('Vorzeichen wird übernommen', () {
      expect(Finanzrechnung.cents('-12,50'), -1250);
      expect(Finanzrechnung.cents('−12,50'), -1250);
      expect(Finanzrechnung.cents('+12,50'), 1250);
    });

    test('mehr als zwei Nachkommastellen werden gerundet', () {
      // Ein Vertipper ist keine Anfrage, die man abweisen muss.
      expect(Finanzrechnung.cents('12,344'), 1234);
      expect(Finanzrechnung.cents('12,345'), 1235);
      expect(Finanzrechnung.cents('9,995'), 1000);
    });

    test('Unsinn gibt null statt einer stillen Null', () {
      expect(Finanzrechnung.cents(''), isNull);
      expect(Finanzrechnung.cents('   '), isNull);
      expect(Finanzrechnung.cents('abc'), isNull);
      expect(Finanzrechnung.cents('-'), isNull);
      expect(Finanzrechnung.cents('12x,50'), isNull);
    });

    test('was hineingeht, kommt wieder heraus', () {
      for (final cents in [1, 99, 100, 1250, 123456, 250000]) {
        final text = Finanzrechnung.nurBetrag(cents).replaceAll(' €', '');
        expect(Finanzrechnung.cents(text), cents, reason: text);
      }
    });
  });

  group('Monate', () {
    test('Monatsende rechnet sich selbst aus', () {
      expect(Finanzrechnung.monatsende(DateTime(2026, 2, 10)).day, 28);
      expect(Finanzrechnung.monatsende(DateTime(2028, 2, 10)).day, 29);
      expect(Finanzrechnung.monatsende(DateTime(2026, 4, 10)).day, 30);
      expect(Finanzrechnung.monatsende(DateTime(2026, 12, 1)).day, 31);
    });

    test('Blättern stolpert nicht über den Monatsletzten', () {
      // DateTime(2026, 1, 31) plus einen Monat ergäbe mit der üblichen
      // Arithmetik den 3. März.
      final januar = DateTime(2026, 1, 31);
      expect(Finanzrechnung.monatVersetzt(januar, 1), DateTime(2026, 2, 1));
    });

    test('Blättern läuft über den Jahreswechsel', () {
      expect(Finanzrechnung.monatVersetzt(DateTime(2026, 12, 1), 1),
          DateTime(2027, 1, 1));
      expect(Finanzrechnung.monatVersetzt(DateTime(2026, 1, 1), -1),
          DateTime(2025, 12, 1));
    });

    test('ISO-Datum für den Server ist zweistellig aufgefüllt', () {
      expect(Finanzrechnung.alsIso(DateTime(2026, 3, 9)), '2026-03-09');
      expect(Finanzrechnung.alsDatum(DateTime(2026, 3, 9)), '09.03.2026');
    });
  });

  group('Summen und Tagesgruppen', () {
    test('Saldo ist eine Summe, keine Fallunterscheidung', () {
      expect(
        Finanzrechnung.summe([
          _b(1, '2026-03-01', 250000),
          _b(2, '2026-03-02', -4783),
        ]),
        245217,
      );
    });

    test('leere Liste ist null', () {
      expect(Finanzrechnung.summe([]), 0);
    });

    test('Buchungen werden nach Tagen gebündelt, neuester zuerst', () {
      final gruppen = Finanzrechnung.nachTagen([
        _b(1, '2026-03-01', -100),
        _b(2, '2026-03-10', -200),
        _b(3, '2026-03-10', -300),
      ]);
      expect(gruppen.length, 2);
      expect(gruppen.first.tag, DateTime(2026, 3, 10));
      expect(gruppen.first.buchungen.length, 2);
      expect(gruppen.first.summeCents, -500);
      expect(gruppen.last.tag, DateTime(2026, 3, 1));
    });

    test('gleicher Tag bleibt eine Gruppe, egal wie sortiert hereinkam', () {
      final gruppen = Finanzrechnung.nachTagen([
        _b(1, '2026-03-10', -100),
        _b(2, '2026-03-01', -200),
        _b(3, '2026-03-10', -300),
      ]);
      expect(gruppen.map((g) => g.buchungen.length).toList(), [2, 1]);
    });

    test('Uhrzeit im Datum bündelt trotzdem auf den Tag', () {
      final gruppen = Finanzrechnung.nachTagen([
        Buchung(
            id: 1,
            kasseId: 1,
            tag: DateTime(2026, 3, 10, 8),
            cents: -100,
            titel: 'früh'),
        Buchung(
            id: 2,
            kasseId: 1,
            tag: DateTime(2026, 3, 10, 20),
            cents: -200,
            titel: 'spät'),
      ]);
      expect(gruppen.length, 1);
    });
  });

  group('Datenklassen', () {
    test('Kategorie „beides" passt in beide Richtungen', () {
      const geschenke = Finanzkategorie(id: 1, name: 'Geschenke', art: 'beides');
      expect(geschenke.passtZu(ausgabe: true), isTrue);
      expect(geschenke.passtZu(ausgabe: false), isTrue);
    });

    test('„Gehalt" wird bei Ausgaben nicht angeboten', () {
      // Eine falsch einsortierte Buchung fällt erst in der Auswertung auf.
      const gehalt = Finanzkategorie(id: 2, name: 'Gehalt', art: 'einnahme');
      expect(gehalt.passtZu(ausgabe: true), isFalse);
      expect(gehalt.passtZu(ausgabe: false), isTrue);
    });

    test('Buchung liest das Vorzeichen als Richtung', () {
      expect(_b(1, '2026-03-01', -100).istAusgabe, isTrue);
      expect(_b(2, '2026-03-01', 100).istAusgabe, isFalse);
    });

    test('Kasse aus JSON', () {
      final kasse = Kasse.fromJson(const {
        'id': 3,
        'owner_id': 'u1',
        'owner_name': 'Jan',
        'name': 'Haushalt',
        'kind': 'giro',
        'color': '#22C55E',
        'start_cents': 100000,
        'order_index': 0,
        'member_ids': ['u2'],
        'saldo_cents': 97500,
      });
      expect(kasse.name, 'Haushalt');
      expect(kasse.saldoCents, 97500);
      expect(kasse.memberIds, ['u2']);
      expect(kasse.gehoert('u1'), isTrue);
      expect(kasse.gehoert('u2'), isFalse);
    });

    test('Auswertung aus JSON, Ausgaben positiv', () {
      final a = Auswertung.fromJson(const {
        'von': '2026-03-01',
        'bis': '2026-03-31',
        'einnahmen_cents': 250000,
        'ausgaben_cents': 33000,
        'saldo_cents': 217000,
        'je_kategorie': [
          {'category_id': 1, 'name': 'Lebensmittel', 'color': '#22C55E',
           'cents': 33000},
        ],
      });
      expect(a.ausgabenCents, 33000);
      expect(a.jeKategorie.single.name, 'Lebensmittel');
      expect(a.leer, isFalse);
    });

    test('fehlende Felder werfen nicht', () {
      // Ein Server, der ein Feld noch nicht kennt, darf die Seite nicht
      // abreissen -- die App wird nicht im Gleichschritt ausgerollt.
      final a = Auswertung.fromJson(const {
        'von': '2026-03-01',
        'bis': '2026-03-31',
      });
      expect(a.leer, isTrue);
      expect(a.jeKategorie, isEmpty);
    });
  });

  group('Kennungen', () {
    test('ein leerer String ist keine Kennung', () {
      // Er sieht aus wie eine, der Fremdschlüssel lehnt ihn ab, der
      // Server stürzt ab -- und im Browser kommt es als CORS-Fehler an.
      expect(FinanzService.kennung(''), isNull);
      expect(FinanzService.kennung(null), isNull);
      expect(FinanzService.kennung('abc'), 'abc');
    });
  });

  // ── Vorzeichen, wo es eines geben muss ────────────────────────────────
  //
  // Ein Anfangsbestand ist keine Buchung: er hat keinen Schalter
  // „Ausgabe / Einnahme", der die Richtung tragen könnte. Ein überzogenes
  // Konto fängt schlicht mit einem Minus an — und genau daran ist es
  // gescheitert.

  group('alsStand', () {
    test('ein überzogenes Konto zeigt sein Minus', () {
      // Vorher stand hier „500,00 €" und nur die Farbe war rot. Auf einem
      // Ausdruck, einem Bildschirmfoto oder für jemanden, der Rot nicht
      // sieht, stand damit das Gegenteil da.
      expect(Finanzrechnung.alsStand(-50000), '−500,00 €');
    });

    test('ein gedeckter Stand bekommt kein Plus', () {
      // Ein Plus vor einem Kontostand liest sich wie eine Buchung.
      expect(Finanzrechnung.alsStand(125000), '1.250,00 €');
    });

    test('null ist null', () {
      expect(Finanzrechnung.alsStand(0), '0,00 €');
    });
  });

  group('fuersFeld', () {
    test('behält das Vorzeichen', () {
      // DER Fehler: `nurBetrag` warf es weg, und wer den Dialog einer
      // überzogenen Kasse nur öffnete und speicherte, drehte den
      // Anfangsbestand ins Positive.
      expect(Finanzrechnung.fuersFeld(-50000), '-500,00');
    });

    test('positiv ohne Vorzeichen', () {
      expect(Finanzrechnung.fuersFeld(1250), '12,50');
    });

    test('ohne Währungszeichen — es steht schon am Feld', () {
      expect(Finanzrechnung.fuersFeld(1250), isNot(contains('€')));
    });

    test('mit geradem Bindestrich, nicht mit typografischem Minus', () {
      // Sonst stünde im Feld ein Zeichen, das auf keiner Tastatur ist:
      // löschen ginge, neu setzen nicht.
      expect(Finanzrechnung.fuersFeld(-1250), startsWith('-'));
      expect(Finanzrechnung.fuersFeld(-1250), isNot(startsWith('−')));
    });

    test('was hineingeht, kommt wieder heraus', () {
      // Der eigentliche Beweis: Feld füllen, Feld lesen, derselbe Wert.
      for (final cents in [-50000, -1250, -1, 0, 1, 1250, 123456]) {
        expect(Finanzrechnung.cents(Finanzrechnung.fuersFeld(cents)), cents,
            reason: 'bei $cents');
      }
    });
  });
}
