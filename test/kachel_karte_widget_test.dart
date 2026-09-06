// Die Kachel als Ganzes: Rahmen, Inhalt, und was sie im Kuechenmodus
// NICHT tut.
//
// Anlass war ein Bildschirmfoto: eine bildschirmbreite Karte, in der statt
// des Wochenrasters nur der Satz "Diese Woche ist nichts geplant" stand.
// In der Logik war alles richtig — die Quelle lieferte eine leere Liste,
// und die Karte machte daraus pflichtgemaess einen Hinweistext.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:productivity/provider/permission_provider.dart';
import 'package:productivity/tabs/dashboard/custom/custom_tile_card.dart';
import 'package:productivity/tabs/dashboard/custom/tile_spec.dart';
import 'package:productivity/tabs/dashboard/custom/tile_week_view.dart';
import 'package:provider/provider.dart';

Future<void> zeige(
  WidgetTester tester,
  CustomTile kachel, {
  DashboardData daten = const DashboardData(),
  bool nurAnzeige = false,
  double breite = 1200,
  double hoehe = 700,
}) async {
  tester.view.physicalSize = Size(breite + 100, hoehe + 100);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ChangeNotifierProvider<PermissionProvider>(
      create: (_) => PermissionProvider()..uebernehmen({'*'}),
      child: MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: breite,
              height: hoehe,
              child: CustomTileCard(
                tile: kachel,
                data: daten,
                nurAnzeige: nurAnzeige,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

const wochenkachel =
    CustomTile(id: 'w', source: 'planner.week', view: 'week', title: 'JP Kalender');

void main() {
  group('Leerer Kalender', () {
    testWidgets('zeichnet trotzdem das Wochenraster', (tester) async {
      // Der Fehler aus dem Bildschirmfoto: statt des Rasters stand nur ein
      // Satz da, auf einer bildschirmbreiten Karte.
      await zeige(tester, wochenkachel);

      expect(find.text('Diese Woche ist nichts geplant'), findsNothing);
      // Das Raster erkennt man an seinen Wochentagen.
      for (final tag in ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So']) {
        expect(find.text(tag), findsOneWidget, reason: tag);
      }
    });

    testWidgets('das Raster nimmt die ganze Karte', (tester) async {
      // Zog es sich auf seine Mindesthoehe zusammen, blieb unter einer
      // breiten Karte viel Schwarz.
      await zeige(tester, wochenkachel);

      final kasten = tester.getSize(find.byType(TileWeekView));
      expect(kasten.height, greaterThan(400));
    });
  });

  group('Eine Auswertung bleibt beim Hinweis', () {
    testWidgets('ohne Aufgaben steht dort ein Satz', (tester) async {
      // Ein Balkendiagramm ohne Werte ist eine leere Flaeche – da ist der
      // Hinweis mehr wert als das Bild.
      await zeige(
        tester,
        const CustomTile(id: 'b', source: 'tasks.by_state', view: 'bars'),
      );
      expect(find.text('Keine Aufgaben'), findsOneWidget);
    });
  });

  group('Kuechenmodus fuehrt nicht weg', () {
    testWidgets('kein Pfeil, der in die App zeigt', (tester) async {
      await zeige(tester, wochenkachel, nurAnzeige: true);
      expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
    });

    testWidgets('ausserhalb der Kueche gibt es ihn', (tester) async {
      // Gegenprobe im selben Test: dieselbe Kachel, nur nicht als Anzeige.
      await zeige(tester, wochenkachel, nurAnzeige: false);
      expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
    });

    testWidgets('der Knopf zum Anlegen bleibt', (tester) async {
      // Termine direkt anlegen war ausdruecklich gewuenscht – das fuehrt
      // nicht weg, sondern traegt ein.
      await zeige(tester, wochenkachel, nurAnzeige: true);
      expect(find.byIcon(Icons.event_available_outlined), findsOneWidget);
    });
  });
}
