// Ganztaegige Termine gehoeren nicht ins Stundenraster.
//
// So kommen Muellabfuhr, Feiertage und Schulferien herein: der ICS-Import
// legt einen Termin ohne Uhrzeit als 00:00 bis 23:59 ab. Im Raster fuellen
// sie damit die komplette Tagesspalte und draengen alles Uebrige an den
// Rand.
//
// Das Modell hat kein `all_day`-Feld -- die Erkennung ist abgeleitet. Sie
// ist deshalb keine Schaetzung: geprueft wird genau die Form, die der
// Importer schreibt (app/services/planner_import_service.py, _event_times).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:productivity/dataclasses/planner_entry.dart';
import 'package:productivity/provider/planner_provider.dart';
import 'package:productivity/provider/settings_provider.dart';
import 'package:productivity/tabs/planner/views/week_view.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

PlannerEntry termin(DateTime von, DateTime bis,
        {int id = 1, String titel = 'Test'}) =>
    PlannerEntry(
      id: id,
      userId: 'u1',
      title: titel,
      scheduledAt: von,
      endsAt: bis,
      durationMin: bis.difference(von).inMinutes,
      notified: false,
      notifyMinBefore: 0,
      orderIndex: 0,
      color: '#3B82F6',
      createdAt: von,
      isDetached: false,
      participants: const [],
    );

void main() {
  group('Erkennen', () {
    test('ein Tag ohne Uhrzeit', () {
      // Genau das schreibt der Importer fuer einen Feiertag.
      expect(
          termin(DateTime(2026, 9, 14), DateTime(2026, 9, 14, 23, 59))
              .istGanztaegig,
          isTrue);
    });

    test('mehrere Tage ohne Uhrzeit', () {
      // Schulferien: 23:59 des LETZTEN Tages.
      expect(
          termin(DateTime(2026, 9, 14), DateTime(2026, 9, 28, 23, 59))
              .istGanztaegig,
          isTrue);
    });

    test('ein normaler Termin nicht', () {
      expect(
          termin(DateTime(2026, 9, 14, 11), DateTime(2026, 9, 14, 12))
              .istGanztaegig,
          isFalse);
    });

    test('von Mitternacht bis Mitternacht ist keiner', () {
      // Der Importer schreibt 23:59, nicht 0:00 des Folgetages. Wer hier
      // grosszuegig waere, sortierte eine Nachtschicht in den
      // Ganztags-Streifen.
      expect(
          termin(DateTime(2026, 9, 14), DateTime(2026, 9, 15))
              .istGanztaegig,
          isFalse);
    });

    test('ein Termin, der um 0 Uhr anfaengt, aber frueher endet', () {
      // „Fruehschicht 0 bis 6" ist kein Ganztagstermin.
      expect(
          termin(DateTime(2026, 9, 14), DateTime(2026, 9, 14, 6))
              .istGanztaegig,
          isFalse);
    });

    test('einer, der spaet anfaengt und um 23:59 endet, auch nicht', () {
      // Beide Bedingungen muessen zutreffen, nicht eine.
      expect(
          termin(DateTime(2026, 9, 14, 20), DateTime(2026, 9, 14, 23, 59))
              .istGanztaegig,
          isFalse);
    });
  });

  group('Im Raster', () {
    /// Montag der laufenden Woche — die Ansicht zeigt immer sie.
    DateTime montag() {
      final h = DateTime.now();
      return DateTime(h.year, h.month, h.day)
          .subtract(Duration(days: h.weekday - 1));
    }

    Future<void> zeichne(WidgetTester tester, List<PlannerEntry> termine) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(1000, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final planer = PlannerProvider()..setzeTermine(termine);
      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: planer),
          ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ],
        child: MaterialApp(
            home: Scaffold(body: WeekView(selectedDate: DateTime.now()))),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('ein Feiertag steht im Streifen, nicht in der Stundenspalte',
        (tester) async {
      final tag = montag().add(const Duration(days: 1));
      await zeichne(tester, [
        termin(tag, DateTime(tag.year, tag.month, tag.day, 23, 59),
            titel: 'Feiertag'),
      ]);

      expect(find.text('ganztags'), findsOneWidget);
      expect(find.text('Feiertag'), findsOneWidget);
    });

    testWidgets('Schulferien stehen an JEDEM ihrer Tage', (tester) async {
      // Der unterscheidende Fall. Im Stundenraster erscheint ein Termin nur
      // an seinem Starttag (`_isSameDay(e.scheduledAt, day)`) -- Ferien
      // waeren am Montag zu sehen und danach nie wieder.
      final start = montag();
      final ende = DateTime(start.year, start.month, start.day, 23, 59)
          .add(const Duration(days: 2));
      await zeichne(tester, [termin(start, ende, titel: 'Ferien')]);

      expect(find.text('Ferien'), findsNWidgets(3));
    });

    testWidgets('zwei am selben Tag verdraengen sich nicht', (tester) async {
      // Die Kachelfassung zeigt nur `heute.first` -- Feiertag UND
      // Schulferien fallen regelmaessig zusammen, und dort verschwand dann
      // einer von beiden ohne Hinweis.
      final tag = montag().add(const Duration(days: 1));
      final bis = DateTime(tag.year, tag.month, tag.day, 23, 59);
      await zeichne(tester, [
        termin(tag, bis, id: 1, titel: 'Feiertag'),
        termin(tag, bis, id: 2, titel: 'Ferien'),
      ]);

      expect(find.text('Feiertag'), findsOneWidget);
      expect(find.text('Ferien'), findsOneWidget);
    });

    testWidgets('ohne ganztaegige gibt es keinen Streifen', (tester) async {
      final tag = montag().add(const Duration(days: 1));
      await zeichne(tester, [
        termin(DateTime(tag.year, tag.month, tag.day, 11),
            DateTime(tag.year, tag.month, tag.day, 12),
            titel: 'Zahnarzt'),
      ]);

      expect(find.text('ganztags'), findsNothing);
      expect(find.text('Zahnarzt'), findsOneWidget);
    });
  });
}
