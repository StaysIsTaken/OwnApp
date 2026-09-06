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
import 'package:productivity/tabs/dashboard/custom/tile_data.dart';
import 'package:productivity/tabs/dashboard/custom/tile_views.dart';
import 'package:productivity/tabs/dashboard/custom/tile_week_view.dart';
import 'package:provider/provider.dart';

Future<void> zeige(
  WidgetTester tester,
  CustomTile kachel, {
  DashboardData daten = const DashboardData(),
  bool kuechenmodus = false,
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
                kuechenmodus: kuechenmodus,
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
  _antippen();

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
      // Ueber die Kennung, nicht ueber das Symbol: dieselbe Pfeilform
      // steht seit dem Blaettern auch in der Kalenderleiste.
      await zeige(tester, wochenkachel, kuechenmodus: true);
      expect(find.byKey(const Key('kachel_fuehrt_weiter')), findsNothing);
    });

    testWidgets('ausserhalb der Kueche gibt es ihn', (tester) async {
      // Gegenprobe im selben Test: dieselbe Kachel, nur nicht als Anzeige.
      await zeige(tester, wochenkachel, kuechenmodus: false);
      expect(find.byKey(const Key('kachel_fuehrt_weiter')), findsOneWidget);
    });

    testWidgets('der Knopf zum Anlegen bleibt', (tester) async {
      // Termine direkt anlegen war ausdruecklich gewuenscht – das fuehrt
      // nicht weg, sondern traegt ein.
      await zeige(tester, wochenkachel, kuechenmodus: true);
      expect(find.byIcon(Icons.event_available_outlined), findsOneWidget);
    });

    testWidgets('und er ist beschriftet und gross', (tester) async {
      // An der Wand wird er mit dem Daumen getroffen, oft im Vorbeigehen.
      // Ein 20-Pixel-Symbol reicht dafuer nicht.
      await zeige(tester, wochenkachel, kuechenmodus: true);

      expect(find.text('Termin'), findsOneWidget);
      final flaeche = tester.getSize(find.ancestor(
        of: find.text('Termin'),
        matching: find.byType(FilledButton),
      ).first);
      // Die uebliche Mindestgroesse fuer eine Trefferflaeche ist 48.
      expect(flaeche.height, greaterThanOrEqualTo(48));
    });

    testWidgets('ausserhalb der Kueche bleibt es ein Symbol', (tester) async {
      // Im Dashboard am Rechner waere ein beschrifteter Knopf im
      // Kachelkopf zu laut – dort zaehlt Dichte.
      await zeige(tester, wochenkachel, kuechenmodus: false);
      expect(find.text('Termin'), findsNothing);
      expect(find.byIcon(Icons.event_available_outlined), findsOneWidget);
    });
  });
}

// Nachtrag: Termine antippen.
void _antippen() {
  TileScheduleItem termin(String titel, DateTime start, {int id = 1}) =>
      TileScheduleItem(
        id: id,
        title: titel,
        start: start,
        end: start.add(const Duration(hours: 1)),
      );

  DateTime montag() {
    final h = DateTime.now();
    final m = h.subtract(Duration(days: h.weekday - 1));
    return DateTime(m.year, m.month, m.day);
  }

  Future<void> zeichneWoche(WidgetTester tester,
      {TileKontext kontext = TileKontext.leer}) async {
    tester.view.physicalSize = const Size(1300, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 1200,
          height: 700,
          child: TileWeekView(
            data: TileData.schedule(
              [termin('Zahnarzt', montag().add(const Duration(hours: 9)))],
              anker: montag(),
            ),
            kontext: kontext,
          ),
        ),
      ),
    ));
    await tester.pump();
  }

  group('Termine antippen', () {
    testWidgets('ohne Rueckkanal passiert nichts', (tester) async {
      // Im Dashboard am Rechner fuehrt die Kachel als Ganzes in den
      // Planner – dort braucht der einzelne Termin keinen eigenen Griff.
      await zeichneWoche(tester);
      // In den Blick holen: die Ansicht faengt bei der jetzigen Stunde an,
      // ein Termin um neun liegt abends ausserhalb.
      await tester.ensureVisible(find.text('Zahnarzt'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Zahnarzt'));
      await tester.pump();
      // Kein Absturz, kein Dialog.
      expect(tester.takeException(), isNull);
    });

    testWidgets('mit Rueckkanal meldet der Termin seine Kennung',
        (tester) async {
      int? geoeffnet;
      await zeichneWoche(tester,
          kontext: TileKontext(terminOeffnen: (id) async => geoeffnet = id));

      await tester.ensureVisible(find.text('Zahnarzt'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Zahnarzt'));
      await tester.pump();
      expect(geoeffnet, 1);
    });

    testWidgets('ein Termin ohne Kennung bleibt unantippbar', (tester) async {
      // Kennung 0 heisst: der kommt nicht aus der Datenbank.
      var gerufen = false;
      tester.view.physicalSize = const Size(1300, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 1200,
            height: 700,
            child: TileWeekView(
              data: TileData.schedule(
                [termin('Ohne', montag().add(const Duration(hours: 9)), id: 0)],
                anker: montag(),
              ),
              kontext: TileKontext(terminOeffnen: (_) async => gerufen = true),
            ),
          ),
        ),
      ));
      await tester.pump();

      await tester.ensureVisible(find.text('Ohne'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ohne'));
      await tester.pump();
      expect(gerufen, isFalse);
    });
  });
}
