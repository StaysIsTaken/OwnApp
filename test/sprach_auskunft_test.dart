// Was das Tablet ohne Server beantwortet: Uhrzeit, Datum, Wetter.
//
// Die Erkennung ist reine Zeichenkettenarbeit und ohne Netz pruefbar. Die
// Wetterantwort selbst nicht -- die holt Daten und bleibt ungetestet.
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:productivity/dataservice/sprach_auskunft.dart';

void main() {
  setUpAll(() async {
    // DateFormat mit 'de_DE' braucht die geladenen Gebietsdaten.
    await initializeDateFormatting('de_DE');
  });

  group('Erkennung', () {
    test('Uhrzeit in den ueblichen Formulierungen', () {
      for (final satz in [
        'Wie spät ist es?',
        'Wie viel Uhr haben wir',
        'Sag mir die Uhrzeit',
      ]) {
        expect(SprachAuskunft.erkenne(satz), Auskunftsart.zeit, reason: satz);
      }
    });

    test('Datum', () {
      for (final satz in [
        'Welches Datum haben wir?',
        'Welcher Tag ist heute',
        'Den wievielten haben wir',
      ]) {
        expect(SprachAuskunft.erkenne(satz), Auskunftsart.datum, reason: satz);
      }
    });

    test('Wetter', () {
      for (final satz in [
        'Wie ist das Wetter?',
        'Regnet es draußen',
        'Wie warm ist es',
      ]) {
        expect(SprachAuskunft.erkenne(satz), Auskunftsart.wetter, reason: satz);
      }
    });

    test('Wetter gewinnt gegen Zeit, wenn beides vorkommt', () {
      // "Wie wird das Wetter heute um wie viel Uhr" ist eine Wetterfrage.
      // Andersherum waere die Antwort die Uhrzeit -- nutzlos.
      expect(SprachAuskunft.erkenne('Wie ist das Wetter um wie viel Uhr'),
          Auskunftsart.wetter);
    });

    test('normale Auftraege bleiben unberuehrt', () {
      // Das ist das Wichtigste: diese Saetze muessen ans Modell gehen,
      // nicht hier abgefangen werden.
      for (final satz in [
        'Milch auf die Einkaufsliste',
        'Trag Zahnarzt für Freitag ein',
        'Wie viele Aufgaben habe ich',
      ]) {
        expect(SprachAuskunft.erkenne(satz), isNull, reason: satz);
      }
    });
  });

  group('Antworten', () {
    test('volle Stunde ohne Minutenangabe', () {
      expect(SprachAuskunft.zeitAntwort(DateTime(2026, 9, 11, 14)),
          'Es ist 14 Uhr.');
    });

    test('mit Minuten, ohne fuehrende Null', () {
      // "14 Uhr 05" laese die Sprachausgabe als "null fuenf".
      expect(SprachAuskunft.zeitAntwort(DateTime(2026, 9, 11, 14, 5)),
          'Es ist 14 Uhr 5.');
    });

    test('das Datum nennt Wochentag und Monat ausgeschrieben', () {
      final satz = SprachAuskunft.datumAntwort(DateTime(2026, 9, 11));
      expect(satz, contains('Freitag'));
      expect(satz, contains('11. September 2026'));
    });
  });
}
