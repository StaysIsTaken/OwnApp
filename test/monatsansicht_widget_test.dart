// Die Monatsansicht wirklich zeichnen – nicht nur die Quelle rechnen lassen.
//
// Der Ueberlauf in der Wochenansicht ist genau so gefunden worden: in der
// Logik war alles richtig, im Raster lief eine Spalte ueber.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:productivity/tabs/dashboard/custom/tile_data.dart';
import 'package:productivity/tabs/dashboard/custom/tile_month_view.dart';

Future<void> zeichne(
  WidgetTester tester,
  TileData daten, {
  double breite = 900,
  double hoehe = 600,
}) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: breite,
          height: hoehe,
          child: TileMonthView(data: daten),
        ),
      ),
    ),
  ));
  await tester.pump();
}

TileScheduleItem termin(String titel, DateTime start) => TileScheduleItem(
      title: titel,
      start: start,
      end: start.add(const Duration(hours: 1)),
      color: '#3B82F6',
    );

void main() {
  final ersterDiesenMonat = DateTime(DateTime.now().year, DateTime.now().month);

  testWidgets('Monatsname und Jahr stehen im Kopf', (tester) async {
    await zeichne(tester, TileData.schedule(const [], anker: ersterDiesenMonat));
    expect(find.textContaining('${ersterDiesenMonat.year}'), findsOneWidget);
  });

  testWidgets('alle sieben Wochentage stehen darunter', (tester) async {
    await zeichne(tester, TileData.schedule(const [], anker: ersterDiesenMonat));
    for (final t in ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So']) {
      expect(find.text(t), findsOneWidget, reason: t);
    }
  });

  testWidgets('ein Termin steht in seiner Zelle', (tester) async {
    final am10 = DateTime(ersterDiesenMonat.year, ersterDiesenMonat.month, 10, 9);
    await zeichne(tester,
        TileData.schedule([termin('Zahnarzt', am10)], anker: ersterDiesenMonat));
    expect(find.textContaining('Zahnarzt'), findsOneWidget);
  });

  testWidgets('der Anker bestimmt den gezeigten Monat', (tester) async {
    // Gegenprobe im Zeichnen: derselbe Termin, aber ein Monat weiter
    // geankert – dann darf er nicht auftauchen.
    final am10 = DateTime(ersterDiesenMonat.year, ersterDiesenMonat.month, 10, 9);
    final naechster =
        DateTime(ersterDiesenMonat.year, ersterDiesenMonat.month + 1);
    await zeichne(
        tester, TileData.schedule([termin('Zahnarzt', am10)], anker: naechster));
    expect(find.textContaining('Zahnarzt'), findsNothing);
  });

  testWidgets('ein voller Tag laeuft nicht ueber', (tester) async {
    // In einer kleinen Kachel ist Platz fuer zwei, drei Streifen – der Rest
    // muss als "+N" zusammenfallen statt die Zelle zu sprengen.
    final tag = DateTime(ersterDiesenMonat.year, ersterDiesenMonat.month, 12);
    await zeichne(
      tester,
      TileData.schedule([
        for (var i = 0; i < 10; i++)
          termin('Termin $i', tag.add(Duration(hours: 8 + i))),
      ], anker: ersterDiesenMonat),
      breite: 420,
      hoehe: 300,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('auch als kleine Kachel bleibt sie heil', (tester) async {
    await zeichne(tester, TileData.schedule(const [], anker: ersterDiesenMonat),
        breite: 320, hoehe: 200);
    expect(tester.takeException(), isNull);
  });
}
