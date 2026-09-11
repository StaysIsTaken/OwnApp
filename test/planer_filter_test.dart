// Der Kalenderfilter in der Ansicht: was Tag, Woche und Monat noch zeigen.
//
// Getrennt von kalender_filter_test.dart mit Absicht. Dort wird aus einem
// Satz eine Menge von IDs; hier wird geprueft, ob diese Menge in allen drei
// Abfragen ueberhaupt ankommt. Beides kann einzeln richtig und zusammen
// falsch sein -- eine Ansicht, die den Filter schlicht ignoriert, bestuende
// jeden Test der anderen Datei.
import 'package:flutter_test/flutter_test.dart';
import 'package:productivity/dataclasses/kalender.dart';
import 'package:productivity/dataclasses/planner_entry.dart';
import 'package:productivity/provider/planner_provider.dart';

final _tag = DateTime(2026, 9, 11, 10);

PlannerEntry termin(int id, {int? kalender, DateTime? wann}) => PlannerEntry(
      id: id,
      userId: 'u1',
      title: 'Termin $id',
      scheduledAt: wann ?? _tag,
      endsAt: (wann ?? _tag).add(const Duration(hours: 1)),
      createdAt: _tag,
      calendarId: kalender,
    );

PlannerProvider mitTerminen(List<PlannerEntry> termine) =>
    PlannerProvider()..setzeTermine(termine);

void main() {
  group('Ohne Filter', () {
    test('ist alles sichtbar, auch was in keinem Kalender liegt', () {
      final p = mitTerminen([termin(1, kalender: 7), termin(2)]);
      expect(p.getEntriesForDay(_tag).map((e) => e.id), [1, 2]);
      expect(p.filterAktiv, isFalse);
    });
  });

  group('Mit Filter', () {
    test('die Tagesansicht zeigt nur den gewaehlten Kalender', () {
      final p = mitTerminen([termin(1, kalender: 7), termin(2, kalender: 8)]);
      p.zeigeNur({7});
      expect(p.getEntriesForDay(_tag).map((e) => e.id), [1]);
    });

    test('die Wochenansicht auch', () {
      final p = mitTerminen([
        termin(1, kalender: 7, wann: DateTime(2026, 9, 8, 9)),
        termin(2, kalender: 8, wann: DateTime(2026, 9, 9, 9)),
      ]);
      p.zeigeNur({7});
      expect(p.getEntriesForWeek(DateTime(2026, 9, 7)).map((e) => e.id), [1]);
    });

    test('und die Monatsansicht', () {
      final p = mitTerminen([
        termin(1, kalender: 7, wann: DateTime(2026, 9, 3, 9)),
        termin(2, kalender: 8, wann: DateTime(2026, 9, 20, 9)),
      ]);
      p.zeigeNur({7});
      expect(p.getEntriesForMonth(DateTime(2026, 9, 1)).map((e) => e.id), [1]);
    });

    test('zwei Kalender gleichzeitig', () {
      final p = mitTerminen([
        termin(1, kalender: 7),
        termin(2, kalender: 8),
        termin(3, kalender: 9),
      ]);
      p.zeigeNur({7, 9});
      expect(p.getEntriesForDay(_tag).map((e) => e.id), [1, 3]);
    });

    test('ein Termin ohne Kalender faellt heraus', () {
      // „Nur der Arbeitskalender" heisst nur der Arbeitskalender. Ein
      // Termin, der in keinem liegt, gehoert nicht dazu.
      final p = mitTerminen([termin(1, kalender: 7), termin(2)]);
      p.zeigeNur({7});
      expect(p.getEntriesForDay(_tag).map((e) => e.id), [1]);
    });
  });

  group('Filter aufheben', () {
    test('mit null', () {
      final p = mitTerminen([termin(1, kalender: 7), termin(2, kalender: 8)]);
      p.zeigeNur({7});
      p.zeigeNur(null);
      expect(p.filterAktiv, isFalse);
      expect(p.getEntriesForDay(_tag), hasLength(2));
    });

    test('eine leere Auswahl heisst alle, nicht nichts', () {
      // Sonst haette „zeige wieder alle Kalender an" eine leere Ansicht
      // zur Folge -- das genaue Gegenteil.
      final p = mitTerminen([termin(1, kalender: 7)]);
      p.zeigeNur({});
      expect(p.filterAktiv, isFalse);
      expect(p.getEntriesForDay(_tag), hasLength(1));
    });
  });

  group('Was die Sprachantwort vorliest', () {
    final kalender = [
      Kalender(id: 7, ownerId: 'u1', ownerName: 'Jan', name: 'Arbeit',
          color: '#000000'),
      Kalender(id: 8, ownerId: 'u2', ownerName: 'Lisa', name: 'Müllabfuhr',
          color: '#000000'),
    ];

    test('ohne Filter sind es alle Namen', () {
      final p = PlannerProvider()..setzeKalender(kalender);
      expect(p.sichtbareNamen, ['Arbeit', 'Müllabfuhr']);
    });

    test('mit Filter nur die gewaehlten', () {
      final p = PlannerProvider()..setzeKalender(kalender);
      p.zeigeNur({8});
      expect(p.sichtbareNamen, ['Müllabfuhr']);
    });
  });
}
