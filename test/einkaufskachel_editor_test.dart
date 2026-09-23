// Die Einkaufslisten-Kachel machte den Bildschirm weiss.
//
// Der Befund war eindeutig und die Ursache eine Zeile: im Kachel-Editor
// stand
//
//     FutureBuilder(future: EinkaufService.listen(), ...)
//
// mit der Future DIREKT am Aufruf. `build()` erzeugt sie damit bei jedem
// Durchlauf neu -- die Future wird fertig, der FutureBuilder baut neu,
// `build()` erzeugt die naechste, sie wird fertig, und so weiter. Das
// hoert nie auf: der Server wird in Dauerschleife gefragt, der Bildbau
// kommt nicht zum Stillstand, und zu sehen ist eine leere weisse Flaeche.
//
// Nur diese eine Quelle war betroffen, weil `ParamArt.einkaufsliste` nur
// an ihr haengt. Alle anderen Einstellungen sind Zahlen und Texte und
// brauchen keinen Server.
//
// DESHALB ZAEHLT DIESER TEST DIE AUFRUFE. „Sieht richtig aus" haette den
// Fehler nie gefunden -- von aussen ist eine Endlosschleife erst zu
// erkennen, wenn das Geraet steht.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:productivity/dataclasses/einkauf.dart';
import 'package:productivity/tabs/dashboard/custom/tile_editor.dart';

Einkaufsliste liste(int id, String name) => Einkaufsliste(
      id: id, ownerId: 'u1', ownerName: 'Jan', name: name, offen: 3,
    );

/// Der Editor haengt an `showTileEditor`; ein Knopf davor genuegt.
Widget geruest(VoidCallback? _) => MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (ctx) => ElevatedButton(
            onPressed: () => showTileEditor(ctx),
            child: const Text('Kachel anlegen'),
          ),
        ),
      ),
    );

/// Eine Tablet-Flaeche. Die Vorgabe (800x600) ist zu klein: der Editor
/// nimmt den ganzen Bildschirm, und die Quellenauswahl liegt dann
/// ausserhalb -- der Tipp ginge ins Leere, ohne dass der Test es sagt.
void tabletGroesse(WidgetTester tester) {
  // Hoch genug, dass alle Schritte des Formulars gebaut werden. Zu kurz
  // heisst hier nicht „abgeschnitten", sondern „gar nicht vorhanden" --
  // was darunter liegt, baut Flutter erst beim Scrollen.
  tester.view.physicalSize = const Size(1600, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Future<void> oeffneUndWaehleEinkauf(WidgetTester tester) async {
  await tester.tap(find.text('Kachel anlegen'));
  await tester.pumpAndSettle();

  final quelle = find.text('Einkaufsliste zum Abhaken');
  await tester.ensureVisible(quelle);
  await tester.pumpAndSettle();
  await tester.tap(quelle);
  await tester.pumpAndSettle();
}

void main() {
  late int aufrufe;

  setUp(() {
    aufrufe = 0;
    einkaufslistenLader = () async {
      aufrufe++;
      return [liste(1, 'Wocheneinkauf'), liste(2, 'Baumarkt')];
    };
  });

  testWidgets('die Listen werden genau einmal geholt', (tester) async {
    tabletGroesse(tester);
    await tester.pumpWidget(geruest(null));
    await oeffneUndWaehleEinkauf(tester);

    // DER Test. Vor der Reparatur lief der Lader endlos weiter; hier waere
    // die Zahl bei jedem Neubau um eins gestiegen.
    expect(aufrufe, 1);
  });

  testWidgets('und auch nach weiteren Neubauten nur einmal', (tester) async {
    tabletGroesse(tester);
    await tester.pumpWidget(geruest(null));
    await oeffneUndWaehleEinkauf(tester);

    // Etwas anfassen, das setState ausloest -- die Ueberschrift.
    await tester.enterText(
        find.widgetWithText(TextField, 'Eigene Überschrift').first, 'Zettel');
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextField, 'Eigene Überschrift').first, 'Zettel!');
    await tester.pumpAndSettle();

    expect(aufrufe, 1);
  });

  testWidgets('die geladenen Listen stehen zur Wahl', (tester) async {
    tabletGroesse(tester);
    await tester.pumpWidget(geruest(null));
    await oeffneUndWaehleEinkauf(tester);

    expect(find.text('Welche Liste?'), findsOneWidget);
    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pumpAndSettle();
    expect(find.textContaining('Wocheneinkauf').hitTestable(), findsWidgets);
  });

  testWidgets('ein Fehler beim Laden sagt, dass es einer war', (tester) async {
    // Vorher stand hier „Noch keine Einkaufsliste vorhanden" -- ein Fehler
    // hinterlaesst nur `data == null` und sah damit aus wie eine leere
    // Liste. Die beiden Saetze fuehren zu verschiedenem Tun: beim einen
    // legt man eine Liste an, beim anderen sieht man nach dem Server.
    einkaufslistenLader = () async {
      aufrufe++;
      throw Exception('403');
    };

    tabletGroesse(tester);
    await tester.pumpWidget(geruest(null));
    await oeffneUndWaehleEinkauf(tester);

    expect(find.textContaining('konnten nicht geladen werden'), findsOneWidget);
    expect(find.textContaining('Noch keine Einkaufsliste'), findsNothing);
    // Auch der Fehlerfall darf nicht in die Schleife laufen -- eine
    // scheiternde Anfrage in Dauerschleife ist der schlimmere von beiden.
    expect(aufrufe, 1);
  });
}
