// „Ja" und „nein" auf eine offene Rueckfrage.
//
// Schlaegt Jarvis etwas vor, wartete es bisher auf einen FINGERTIPP -- auf
// einem Kuechentablet, vor dem man mit mehligen Haenden steht, genau
// verkehrt herum. Der Kommentar im Sprach-Provider sagte es selbst: „eine
// offene Bestaetigung wartet auf einen Tipp, nicht auf ein Wort."
//
// Zwei Dinge pruefen hier mehrere Tests besonders:
//
// 1. **Ganze Woerter.** Alle anderen Parser dieses Projekts suchen
//    Teilzeichenketten -- das geht, weil sie ein Ankerwort verlangen
//    („Timer", „Liste"). Hier ist die ganze Aeusserung die Antwort, und
//    „ja" steckt in Januar, Jacke und jagen.
// 2. **Nein gewinnt.** Ein falsches „ja" fuehrt etwas aus, das der Nutzer
//    gerade abgelehnt hat. Der umgekehrte Fehler kostet eine Wiederholung.

import 'package:flutter_test/flutter_test.dart';
import 'package:productivity/dataservice/bestaetigung.dart';

void main() {
  group('Zustimmung', () {
    for (final satz in ['ja', 'Ja bitte', 'okay', 'mach das, genau',
                        'jo', 'klar', 'einverstanden']) {
      test('„$satz"', () {
        expect(Bestaetigung.erkenne(satz), Zustimmung.ja);
      });
    }
  });

  group('Ablehnung', () {
    for (final satz in ['nein', 'nee', 'lass mal', 'abbrechen',
                        'nein danke', 'vergiss es']) {
      test('„$satz"', () {
        expect(Bestaetigung.erkenne(satz), Zustimmung.nein);
      });
    }
  });

  group('Nein gewinnt', () {
    test('„nein, mach das nicht"', () {
      // Traegt „mach" UND „nein". Wer nein sagt, meint nie ja -- und der
      // Fehler in diese Richtung fuehrt etwas aus, das gerade abgelehnt
      // wurde.
      expect(Bestaetigung.erkenne('nein, mach das nicht'), Zustimmung.nein);
    });

    test('„okay, aber nicht heute"', () {
      expect(Bestaetigung.erkenne('okay, aber nicht heute'), Zustimmung.nein);
    });
  });

  group('Keine Antwort', () {
    test('ein ganz anderer Zuruf', () {
      // Wer statt zu antworten etwas Neues sagt, soll nicht aufgehalten
      // werden.
      expect(Bestaetigung.erkenne('stell einen Timer für fünf Minuten'),
          isNull);
      expect(Bestaetigung.erkenne('wie spät ist es'), isNull);
    });

    test('leer', () {
      expect(Bestaetigung.erkenne(''), isNull);
      expect(Bestaetigung.erkenne('   '), isNull);
    });
  });

  group('Ganze Woerter, keine Teilzeichenketten', () {
    test('Januar ist kein Ja', () {
      // Der Kern: mit `contains` waere „trag das im Januar ein" eine
      // Zustimmung gewesen.
      expect(Bestaetigung.erkenne('trag das im Januar ein'), isNull);
    });

    test('Jacke auch nicht', () {
      expect(Bestaetigung.erkenne('meine Jacke suchen'), isNull);
    });

    test('„keine" ist ein Nein, „Keinesfalls" bleibt eins', () {
      expect(Bestaetigung.erkenne('keine Ahnung'), Zustimmung.nein);
    });

    test('Grossschreibung und Satzzeichen stoeren nicht', () {
      expect(Bestaetigung.erkenne('JA!'), Zustimmung.ja);
      expect(Bestaetigung.erkenne('Nein.'), Zustimmung.nein);
    });
  });
}
