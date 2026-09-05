// Der erste Test in diesem Projekt, der wirklich etwas zeichnet.
//
// Bisher war die Oberflaeche nur in der Logik geprueft — und genau dort
// sind die Fehler durchgerutscht, die dem Nutzer aufgefallen sind: eine
// Wochenansicht, die den falschen Zeitraum zeichnet, und eine Kachel, die
// bei viel Platz aussieht wie bei wenig.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:productivity/tabs/dashboard/custom/tile_data.dart';
import 'package:productivity/tabs/dashboard/custom/tile_week_view.dart';

/// Zeichnet die Ansicht in einer Flaeche fester Groesse.
Future<void> zeichne(
  WidgetTester tester,
  TileData daten, {
  required double breite,
  required double hoehe,
}) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: breite,
          height: hoehe,
          child: TileWeekView(data: daten),
        ),
      ),
    ),
  ));
  await tester.pump();
}

TileScheduleItem termin(String titel, DateTime start, {int stunden = 1}) =>
    TileScheduleItem(
      title: titel,
      start: start,
      end: start.add(Duration(hours: stunden)),
      color: '#22C55E',
    );

DateTime montagDieserWoche() {
  final h = DateTime.now();
  final m = h.subtract(Duration(days: h.weekday - 1));
  return DateTime(m.year, m.month, m.day);
}

void main() {
  group('Grosse Flaeche – wie im Planner', () {
    testWidgets('zeigt den ganzen Tag mit Uhrzeiten', (tester) async {
      final montag = montagDieserWoche();
      await zeichne(
        tester,
        TileData.schedule([termin('Zahnarzt', montag.add(const Duration(hours: 9)))],
            anker: montag),
        breite: 1000,
        hoehe: 700,
      );

      // Beschriftung wie im Planner: 00:00 statt einer nackten 0.
      expect(find.text('00:00'), findsOneWidget);
      expect(find.text('23:00'), findsOneWidget);
    });

    testWidgets('der Termin steht im Raster', (tester) async {
      final montag = montagDieserWoche();
      await zeichne(
        tester,
        TileData.schedule([termin('Zahnarzt', montag.add(const Duration(hours: 9)))],
            anker: montag),
        breite: 1000,
        hoehe: 700,
      );
      expect(find.text('Zahnarzt'), findsOneWidget);
    });

    testWidgets('alle sieben Wochentage stehen im Kopf', (tester) async {
      await zeichne(tester, const TileData.schedule([]),
          breite: 1000, hoehe: 700);
      for (final tag in ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So']) {
        expect(find.text(tag), findsOneWidget, reason: tag);
      }
    });
  });

  group('Kleine Kachel – zusammengedraengt', () {
    testWidgets('zeigt nicht den ganzen Tag', (tester) async {
      // Bei wenig Platz verschenkt ein leerer Vormittag die halbe Kachel.
      await zeichne(tester, const TileData.schedule([]),
          breite: 400, hoehe: 220);
      expect(find.text('00:00'), findsNothing);
    });
  });

  group('Der Anker bestimmt die gezeigte Woche', () {
    testWidgets('ein Termin naechster Woche erscheint mit passendem Anker',
        (tester) async {
      // Das ist der Fehler, den es lange gab: die Ansicht zeichnete die
      // heutige Woche, waehrend die Quelle die naechste lieferte – der
      // Termin fiel aus dem Raster und die Kachel blieb leer.
      final naechsterMontag =
          montagDieserWoche().add(const Duration(days: 7));
      await zeichne(
        tester,
        TileData.schedule(
          [termin('Naechste Woche', naechsterMontag.add(const Duration(hours: 10)))],
          anker: naechsterMontag,
        ),
        breite: 1000,
        hoehe: 700,
      );
      expect(find.text('Naechste Woche'), findsOneWidget);
    });

    testWidgets('ohne passenden Anker faellt er heraus', (tester) async {
      // Die Gegenprobe im Zeichnen selbst: derselbe Termin, aber die
      // Ansicht auf diese Woche geankert.
      final naechsterMontag =
          montagDieserWoche().add(const Duration(days: 7));
      await zeichne(
        tester,
        TileData.schedule(
          [termin('Naechste Woche', naechsterMontag.add(const Duration(hours: 10)))],
          anker: montagDieserWoche(),
        ),
        breite: 1000,
        hoehe: 700,
      );
      expect(find.text('Naechste Woche'), findsNothing);
    });
  });

  group('Ohne Ueberlauf', () {
    testWidgets('viele Termine an einem Tag sprengen die Kachel nicht',
        (tester) async {
      final montag = montagDieserWoche();
      await zeichne(
        tester,
        TileData.schedule([
          for (var i = 0; i < 12; i++)
            termin('T$i', montag.add(Duration(hours: 8 + i))),
        ], anker: montag),
        breite: 500,
        hoehe: 260,
      );
      // tester.takeException() meldet einen Ueberlauf als Fehler.
      expect(tester.takeException(), isNull);
    });
  });
}
