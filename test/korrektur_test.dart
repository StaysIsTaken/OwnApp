// „Nein, 16 Uhr" -- nachbessern, ohne von vorn anzufangen.
//
// Jarvis sagt, was er getan hat; danach bleibt das Mikrofon zehn Sekunden
// offen. Das ist die BREMSE: in dieser Zeit wird nicht auf alles reagiert,
// sondern nur auf Saetze, die wie eine Korrektur aussehen. Ein
// Kuechentablet, das nach jeder Aktion zehn Sekunden lang jeden Halbsatz
// aus dem Raum annimmt, waere eine Zumutung -- und in einer Kueche mit
// Radio und Gespraechen faengt es genug davon.
//
// Der zweite Kern: zurueckgenommen wird nur, was sich EXAKT umkehren
// laesst. Bietet der Server keine Umkehrung an, wird nichts gemerkt --
// ehrlich nichts anzubieten ist besser als etwas Halbrichtiges.

import 'package:flutter_test/flutter_test.dart';
import 'package:productivity/dataservice/korrektur.dart';

AusgefuehrteAktion aktion(String label) => AusgefuehrteAktion(
      label: label, rueckKind: 'delete_task',
      rueckParams: const {'task_id': 'x'},
    );

void main() {
  group('Ruecknahme erkennen', () {
    for (final satz in ['nimm das zurück', 'lösch das wieder', 'rückgängig',
                        'weg damit', 'vergiss das', 'doch nicht']) {
      test('„$satz"', () {
        expect(Korrekturbefehle.erkenne(satz), Korrekturart.ruecknahme);
      });
    }

    test('Ruecknahme schlaegt Nachbesserung', () {
      // „nein, nimm das zurueck" traegt beides -- gemeint ist das Weg.
      expect(Korrekturbefehle.erkenne('nein, nimm das zurück'),
          Korrekturart.ruecknahme);
    });
  });

  group('Nachbesserung erkennen', () {
    for (final satz in ['nein, 16 Uhr', 'ich meinte morgen', 'falsch',
                        'nicht 15 sondern 16', 'mach draus halb elf']) {
      test('„$satz"', () {
        expect(Korrekturbefehle.erkenne(satz), Korrekturart.nachbesserung);
      });
    }
  });

  group('Die Bremse', () {
    for (final satz in ['wie spät ist es',
                        'stell einen Timer für fünf Minuten',
                        'setz Milch auf die Liste',
                        'das Wetter ist schön heute']) {
      test('„$satz" ist keine Korrektur', () {
        // Genau dafuer ist die Bremse da: im offenen Fenster faellt so ein
        // Satz durch und geht den normalen Weg.
        expect(Korrekturbefehle.erkenne(satz), isNull);
      });
    }
  });

  group('Das Fenster', () {
    test('zehn Sekunden', () {
      // Lang genug fuer ein „nein, halb elf", kurz genug, dass es keine
      // weiteren Zurufe blockiert.
      expect(Korrekturbefehle.fenster, const Duration(seconds: 10));
    });

    test('frisch ist es zu', () {
      expect(Korrekturfenster().offen, isFalse);
      expect(Korrekturfenster().nehmbar, isFalse);
    });

    test('gemerkt ist es offen', () {
      final f = Korrekturfenster()..merken('Termin angelegt', [aktion('A')]);
      expect(f.offen, isTrue);
      expect(f.was, 'Termin angelegt');
      expect(f.nehmbar, isTrue);
    });

    test('geschlossen gibt es nichts mehr her', () {
      final f = Korrekturfenster()..merken('X', [aktion('A')]);
      f.schliessen();
      expect(f.offen, isFalse);
      expect(f.ruecknahmen, isEmpty);
      expect(f.was, isNull);
    });

    test('ohne Umkehrung ist nichts zurueckzunehmen', () {
      // Der Server bietet keine an -- dann wird auch keine gemerkt.
      final f = Korrekturfenster()..merken('Notiz angelegt', const []);
      expect(f.offen, isTrue);
      expect(f.nehmbar, isFalse);
    });

    test('zurueckgenommen wird in umgekehrter Reihenfolge', () {
      // Wer erst die Liste loescht und dann ihre Position, findet die
      // Position nicht mehr.
      final f = Korrekturfenster()
        ..merken('zwei Sachen', [aktion('Liste'), aktion('Position')]);
      expect(f.ruecknahmen.map((a) => a.label).toList(),
          ['Position', 'Liste']);
    });
  });
}
