import 'package:flutter_test/flutter_test.dart';
import 'package:productivity/dataclasses/finanzen.dart';
import 'package:productivity/dataservice/finanz_rechnung.dart';

/// Daueraufträge in der App.
///
/// Zwei Dinge stehen hier im Mittelpunkt:
///
/// **Der Takt in Worten.** „alle 3 Monate am Monatsletzten" ist die
/// einzige Stelle, an der der Nutzer erfährt, was die Regel tut. Steht
/// dort „am 31.", erwartet er im Februar nichts — und bekommt am 28.
/// doch eine Buchung, weil der Server kürzt.
///
/// **Die Vorschau ist keine Buchung.** [Geplant] hat keine `id`, und
/// ihre Summe wird getrennt gerechnet. Was geplant ist, ist nicht
/// gebucht.
Dauerauftrag _serie({
  String freq = 'MONTHLY',
  int intervall = 1,
  String? wochentage,
  int? monatstag,
  DateTime? start,
  List<Betragsstufe> staffel = const [],
  int? aktuell,
  bool aktiv = true,
}) =>
    Dauerauftrag(
      id: 1,
      kasseId: 1,
      titel: 'Strom',
      freq: freq,
      intervall: intervall,
      wochentage: wochentage,
      monatstag: monatstag,
      start: start ?? DateTime(2026, 1, 15),
      staffel: staffel,
      aktuellerBetragCents: aktuell,
      aktiv: aktiv,
    );

Geplant _geplant(String tag, int cents) => Geplant(
      serieId: 1,
      kasseId: 1,
      tag: DateTime.parse(tag),
      cents: cents,
      titel: 'Miete',
    );

void main() {
  group('Der Takt in Worten', () {
    test('monatlich am Stichtag', () {
      expect(Finanzrechnung.takt(_serie(monatstag: 1)), 'monatlich am 1.');
    });

    test('der 31. heisst „am Monatsletzten"', () {
      // Die wichtigste Zeile: der Server kürzt auf den Monatsletzten,
      // damit der Februar nicht ausfällt. Stünde hier „am 31.", wäre die
      // Anzeige eine andere Auskunft als das Verhalten.
      expect(Finanzrechnung.takt(_serie(monatstag: 31)),
          'monatlich am Monatsletzten');
    });

    test('ohne Stichtag zählt der Starttag', () {
      expect(Finanzrechnung.takt(_serie(start: DateTime(2026, 3, 7))),
          'monatlich am 7.');
    });

    test('alle drei Monate – kein eigenes QUARTERLY', () {
      expect(Finanzrechnung.takt(_serie(intervall: 3, monatstag: 1)),
          'alle 3 Monate am 1.');
    });

    test('wöchentlich mit Tagen', () {
      expect(
        Finanzrechnung.takt(_serie(freq: 'WEEKLY', wochentage: 'MO,FR')),
        'wöchentlich Mo, Fr',
      );
    });

    test('wöchentlich mit Abstand und Tagen', () {
      expect(
        Finanzrechnung.takt(
            _serie(freq: 'WEEKLY', intervall: 2, wochentage: 'WE')),
        'alle 2 Wochen Mi',
      );
    });

    test('wöchentlich ohne Tage bleibt kurz', () {
      expect(Finanzrechnung.takt(_serie(freq: 'WEEKLY')), 'wöchentlich');
    });

    test('unbekannte Tageskürzel fallen weg statt zu stören', () {
      expect(Finanzrechnung.takt(_serie(freq: 'WEEKLY', wochentage: 'XX')),
          'wöchentlich');
    });

    test('täglich, mit und ohne Abstand', () {
      expect(Finanzrechnung.takt(_serie(freq: 'DAILY')), 'täglich');
      expect(Finanzrechnung.takt(_serie(freq: 'DAILY', intervall: 5)),
          'alle 5 Tage');
    });

    test('jährlich nennt Tag und Monat', () {
      expect(
        Finanzrechnung.takt(_serie(freq: 'YEARLY', start: DateTime(2026, 6, 15))),
        'jährlich am 15. Juni',
      );
    });
  });

  group('Die Vorschau ist keine Buchung', () {
    test('ihre Summe wird getrennt gerechnet', () {
      expect(
        Finanzrechnung.summeGeplant(
            [_geplant('2026-04-01', -95000), _geplant('2026-04-15', -8900)]),
        -103900,
      );
    });

    test('leere Vorschau ist null', () {
      expect(Finanzrechnung.summeGeplant([]), 0);
    });

    test('Geplant liest das Vorzeichen als Richtung', () {
      expect(_geplant('2026-04-01', -95000).istAusgabe, isTrue);
      expect(_geplant('2026-04-01', 250000).istAusgabe, isFalse);
    });

    test('aus JSON, ohne id', () {
      final g = Geplant.fromJson(const {
        'series_id': 7,
        'account_id': 2,
        'category_id': 3,
        'booked_on': '2026-04-01',
        'amount_cents': -95000,
        'title': 'Miete',
        'geplant': true,
      });
      expect(g.serieId, 7);
      expect(g.tag, DateTime(2026, 4, 1));
      expect(g.cents, -95000);
    });
  });

  group('Dauerauftrag', () {
    test('aus JSON, mit Staffel', () {
      final serie = Dauerauftrag.fromJson(const {
        'id': 7,
        'account_id': 2,
        'category_id': 3,
        'title': 'Strom',
        'freq': 'MONTHLY',
        'interval_n': 1,
        'bymonthday': 1,
        'start_on': '2026-01-01',
        'active': true,
        'staffel': [
          {'id': 1, 'series_id': 7, 'gueltig_ab': '2026-01-01',
           'amount_cents': -8900},
          {'id': 2, 'series_id': 7, 'gueltig_ab': '2026-04-01',
           'amount_cents': -9450},
        ],
        'aktueller_betrag_cents': -8900,
        'naechste_faelligkeit': '2026-02-01',
      });
      expect(serie.staffel.length, 2);
      expect(serie.staffel.last.cents, -9450);
      expect(serie.aktuellerBetragCents, -8900);
      expect(serie.naechsteFaelligkeit, DateTime(2026, 2, 1));
      expect(serie.istAusgabe, isTrue);
    });

    test('fehlende Felder werfen nicht', () {
      // App und Backend werden nicht im Gleichschritt ausgerollt.
      final serie = Dauerauftrag.fromJson(const {
        'id': 1,
        'account_id': 1,
        'title': 'X',
        'freq': 'MONTHLY',
        'start_on': '2026-01-01',
      });
      expect(serie.staffel, isEmpty);
      expect(serie.aktuellerBetragCents, isNull);
      expect(serie.naechsteFaelligkeit, isNull);
      expect(serie.aktiv, isTrue);
    });

    test('`active: false` kommt als ausgesetzt an', () {
      // Der Wert, den ein „ist leer"-Filter verschlucken würde.
      final serie = Dauerauftrag.fromJson(const {
        'id': 1,
        'account_id': 1,
        'title': 'X',
        'freq': 'MONTHLY',
        'start_on': '2026-01-01',
        'active': false,
      });
      expect(serie.aktiv, isFalse);
    });

    test('ohne Betrag gilt die Serie nicht als Ausgabe', () {
      expect(_serie().istAusgabe, isFalse);
      expect(_serie(aktuell: -8900).istAusgabe, isTrue);
    });
  });

  group('Betragsstufe', () {
    test('sagt Betrag und Stichtag', () {
      final stufe = Betragsstufe(
          id: 1, serieId: 7, gueltigAb: DateTime(2026, 4, 1), cents: -9450);
      expect(Finanzrechnung.stufenText(stufe), '94,50 € ab 01.04.2026');
    });

    test('aus JSON', () {
      final stufe = Betragsstufe.fromJson(const {
        'id': 2,
        'series_id': 7,
        'gueltig_ab': '2026-04-01',
        'amount_cents': -9450,
        'note': 'Abschlag angepasst',
      });
      expect(stufe.gueltigAb, DateTime(2026, 4, 1));
      expect(stufe.notiz, 'Abschlag angepasst');
    });
  });
}
