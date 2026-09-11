// „Zeige nur den Arbeitskalender und Lisas Kalender an."
//
// Zwei Teile, beide ohne Netz pruefbar: aus dem Satz die Namen holen, und
// die Namen den vorhandenen Kalendern zuordnen. Der dritte Teil -- ob die
// Ansicht danach wirklich weniger zeigt -- steht in planer_filter_test.dart.
//
// Der Grund fuer die Sorgfalt hier: der Satz faengt mit demselben Wort an
// wie ein Seitenwechsel. „Zeige" leitet in Sprachbefehle die Navigation
// ein, und wenn diese Erkennung zu spaet greift, sucht das Tablet nach
// einer Seite namens „nur den arbeitskalender an".
import 'package:flutter_test/flutter_test.dart';
import 'package:productivity/dataclasses/kalender.dart';
import 'package:productivity/dataservice/kalender_filter.dart';
import 'package:productivity/dataservice/sprachbefehle.dart';

Kalender kal(int id, String name, {String besitzer = 'Jan'}) => Kalender(
      id: id,
      ownerId: 'u$id',
      ownerName: besitzer,
      name: name,
      color: '#3B82F6',
    );

void main() {
  group('Aus dem Satz die Namen', () {
    test('zwei Kalender mit und', () {
      expect(
        KalenderFilter.erkenne('Zeige nur den Arbeitskalender und den '
            'Müllkalender an'),
        ['arbeit', 'müll'],
      );
    });

    test('ein einzelner Kalender', () {
      expect(KalenderFilter.erkenne('Zeige nur den Arbeitskalender an'),
          ['arbeit']);
    });

    test('der Name steht getrennt vor dem Wort Kalender', () {
      expect(KalenderFilter.erkenne('Zeig nur den Kalender Müllabfuhr an'),
          ['kalender müllabfuhr']);
    });

    test('mit Komma statt und', () {
      expect(
        KalenderFilter.erkenne('Zeige nur Arbeit, Privat und Müll Kalender an'),
        ['arbeit', 'privat', 'müll'],
      );
    });

    test('Anrede und Satzzeichen stoeren nicht', () {
      expect(KalenderFilter.erkenne('Hey Jarvis, zeige mir nur den '
          'Arbeitskalender an.'), ['arbeit']);
    });

    test('alle wieder anzeigen liefert die leere Liste', () {
      // Leer heisst „Filter weg" -- nicht „nichts anzeigen". Das ist der
      // Unterschied, an dem eine Verwechslung teuer waere.
      for (final satz in [
        'Zeige wieder alle Kalender an',
        'Zeige alle Kalender',
        'Zeige nur alle Kalender an',
      ]) {
        expect(KalenderFilter.erkenne(satz), isEmpty, reason: satz);
      }
    });
  });

  group('Was keine Kalenderauswahl ist', () {
    test('ein Seitenwechsel bleibt einer', () {
      // Der eigentliche Grund fuer diese Datei: diese beiden Saetze duerfen
      // sich nicht ins Gehege kommen.
      expect(KalenderFilter.erkenne('Geh zum Kalender'), isNull);
      expect(KalenderFilter.erkenne('Zeige den Kalender'), isNull);
      expect(Sprachbefehle.navigationsZiel('Geh zum Kalender'), 'kalender');
    });

    test('ohne das Wort Kalender nicht', () {
      expect(KalenderFilter.erkenne('Zeige nur die offenen Aufgaben an'),
          isNull);
    });

    test('ohne nur ist es kein Filter', () {
      expect(KalenderFilter.erkenne('Zeige mir den Arbeitskalender'), isNull);
    });

    test('ein Auftrag bleibt ein Auftrag', () {
      expect(KalenderFilter.erkenne('Trag Zahnarzt in den Arbeitskalender ein'),
          isNull);
      expect(KalenderFilter.erkenne('Milch auf die Einkaufsliste'), isNull);
    });
  });

  group('Namen den Kalendern zuordnen', () {
    final vorhanden = [
      kal(1, 'Arbeit'),
      kal(2, 'Müllabfuhr'),
      kal(3, 'Mein Kalender', besitzer: 'Lisa'),
      kal(4, 'Haus'),
    ];

    test('genauer Name', () {
      expect(KalenderFilter.waehle(vorhanden, ['arbeit']), {1});
    });

    test('Teil des Namens genuegt', () {
      expect(KalenderFilter.waehle(vorhanden, ['müll']), {2});
    });

    test('ueber den Besitzer, wenn kein Kalender so heisst', () {
      // „Zeige nur Lisas Kalender an": „lisa" ist kein Kalendername.
      expect(KalenderFilter.waehle(vorhanden, ['lisas']), {3});
    });

    test('ein Name, der auf s endet, bleibt er selbst', () {
      // „Haus" darf nicht als Genitiv von „Hau" gelesen werden -- sonst
      // findet die Ansicht den Kalender nicht mehr, den es wirklich gibt.
      expect(KalenderFilter.waehle(vorhanden, ['haus']), {4});
    });

    test('mehrere Namen ergeben mehrere Kalender', () {
      expect(KalenderFilter.waehle(vorhanden, ['arbeit', 'müll']), {1, 2});
    });

    test('bei gleichem Namen erscheinen beide', () {
      // Einen davon zu raten hiesse, dem Nutzer Termine wegzunehmen, ohne
      // dass er es merkt.
      final doppelt = [
        kal(5, 'Mein Kalender', besitzer: 'Jan'),
        kal(6, 'Mein Kalender', besitzer: 'Lisa'),
      ];
      expect(KalenderFilter.waehle(doppelt, ['mein kalender']), {5, 6});
    });

    test('unbekannter Name findet nichts', () {
      expect(KalenderFilter.waehle(vorhanden, ['segelverein']), isEmpty);
    });
  });
}
