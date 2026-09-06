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
  _blaettern();

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

// Nachtrag: die Ansicht schneidet zu und laesst sich blaettern. Beides ist
// von der Quelle hierher gewandert, seit es die Blaetterknoepfe gibt.
void _blaettern() {
  group('Zuschnitt und Blaettern', () {
    testWidgets('nur die gezeigte Woche steht im Raster', (tester) async {
      // Die Quelle liefert alles – hier faellt der Rest weg.
      final montag = montagDieserWoche();
      await zeichne(
        tester,
        TileData.schedule([
          termin('Diese Woche', montag.add(const Duration(days: 2, hours: 10))),
          termin('Naechste Woche',
              montag.add(const Duration(days: 9, hours: 10))),
          termin('Letzte Woche', montag.subtract(const Duration(days: 3))),
        ], anker: montag),
        breite: 1000,
        hoehe: 700,
      );

      expect(find.text('Diese Woche'), findsOneWidget);
      expect(find.text('Naechste Woche'), findsNothing);
      expect(find.text('Letzte Woche'), findsNothing);
    });

    testWidgets('vorwaerts zeigt die naechste Woche', (tester) async {
      final montag = montagDieserWoche();
      await zeichne(
        tester,
        TileData.schedule([
          termin('Diese Woche', montag.add(const Duration(days: 2, hours: 10))),
          termin('Naechste Woche',
              montag.add(const Duration(days: 9, hours: 10))),
        ], anker: montag),
        breite: 1000,
        hoehe: 700,
      );

      await tester.tap(find.byTooltip('Weiter'));
      await tester.pump();

      expect(find.text('Naechste Woche'), findsOneWidget);
      expect(find.text('Diese Woche'), findsNothing);
    });

    testWidgets('rueckwaerts zeigt die vorige', (tester) async {
      final montag = montagDieserWoche();
      await zeichne(
        tester,
        TileData.schedule([
          termin('Letzte Woche', montag.subtract(const Duration(days: 3))),
        ], anker: montag),
        breite: 1000,
        hoehe: 700,
      );

      await tester.tap(find.byTooltip('Zurück'));
      await tester.pump();
      expect(find.text('Letzte Woche'), findsOneWidget);
    });

    testWidgets('"Heute" erscheint erst, wenn man weg ist', (tester) async {
      // Ein Knopf, der nichts tut, ist im Weg.
      await zeichne(tester, const TileData.schedule([]),
          breite: 1000, hoehe: 700);
      expect(find.text('Heute'), findsNothing);

      await tester.tap(find.byTooltip('Weiter'));
      await tester.pump();
      expect(find.text('Heute'), findsOneWidget);
    });

    testWidgets('"Heute" fuehrt zurueck', (tester) async {
      final montag = montagDieserWoche();
      await zeichne(
        tester,
        TileData.schedule(
            [termin('Diese Woche', montag.add(const Duration(days: 2, hours: 10)))],
            anker: montag),
        breite: 1000,
        hoehe: 700,
      );

      await tester.tap(find.byTooltip('Weiter'));
      await tester.pump();
      await tester.tap(find.byTooltip('Weiter'));
      await tester.pump();
      expect(find.text('Diese Woche'), findsNothing);

      await tester.tap(find.text('Heute'));
      await tester.pump();
      expect(find.text('Diese Woche'), findsOneWidget);
      expect(find.text('Heute'), findsNothing);
    });

    testWidgets('die Kalenderwoche steht dabei', (tester) async {
      await zeichne(tester, const TileData.schedule([]),
          breite: 1000, hoehe: 700);
      expect(find.textContaining('KW '), findsOneWidget);
    });
  });
}
