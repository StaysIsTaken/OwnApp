// Das Kanban-Board als Kachel: die Rechnung dahinter und das Bild davon.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:productivity/dataclasses/task.dart';
import 'package:productivity/tabs/dashboard/custom/tile_board_view.dart';
import 'package:productivity/tabs/dashboard/custom/tile_catalog.dart';
import 'package:productivity/tabs/dashboard/custom/tile_data.dart';
import 'package:productivity/tabs/dashboard/custom/tile_spec.dart';
import 'package:productivity/tabs/dashboard/custom/tile_views.dart';

Task aufgabe(String titel, String spalte, {DateTime? faellig}) => Task(
      id: titel,
      title: titel,
      kanbanState: spalte,
      dueDate: faellig,
      userId: 'u',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

TileData bauen(List<Task> aufgaben, {int limit = 5}) =>
    TileCatalog.byKey('tasks.board')!
        .build(DashboardData(tasks: aufgaben), {'limit': limit}, const []);

Future<void> zeichne(WidgetTester tester, TileData daten,
    {double breite = 1200,
    double hoehe = 600,
    TileKontext kontext = TileKontext.leer}) async {
  tester.view.physicalSize = Size(breite + 100, hoehe + 100);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: breite,
          height: hoehe,
          child: TileBoardView(data: daten, kontext: kontext),
        ),
      ),
    ),
  ));
  await tester.pump();
}

void main() {
  group('Die Spalten', () {
    test('stehen immer in derselben Reihenfolge', () {
      // Ein Board, dessen Spalten je nach Datenlage wandern, kann man nicht
      // im Vorbeigehen lesen.
      final d = bauen([aufgabe('a', 'done')]);
      expect(d.spalten.map((s) => s.titel),
          ['Offen', 'In Arbeit', 'Erledigt']);
    });

    test('leere Spalten bleiben stehen', () {
      // "Nichts in Arbeit" ist eine Auskunft.
      final d = bauen([aufgabe('a', 'todo')]);
      expect(d.spalten, hasLength(3));
      expect(d.spalten[1].eintraege, isEmpty);
    });

    test('jede Aufgabe landet in ihrer Spalte', () {
      final d = bauen([
        aufgabe('offen', 'todo'),
        aufgabe('laeuft', 'in_progress'),
        aufgabe('fertig', 'done'),
      ]);
      expect(d.spalten[0].eintraege.single.titel, 'offen');
      expect(d.spalten[1].eintraege.single.titel, 'laeuft');
      expect(d.spalten[2].eintraege.single.titel, 'fertig');
    });

    test('ein unbekannter Zustand faellt nicht unter den Tisch', () {
      // Sonst verschwindet die Aufgabe spurlos vom Board.
      final d = bauen([aufgabe('seltsam', 'irgendwas')]);
      expect(d.spalten[0].eintraege.single.titel, 'seltsam');
    });

    test('Faellige stehen oben', () {
      final d = bauen([
        aufgabe('ohne Datum', 'todo'),
        aufgabe('bald', 'todo', faellig: DateTime(2026, 9, 10)),
      ]);
      expect(d.spalten[0].eintraege.first.titel, 'bald');
    });

    test('die Grenze gilt je Spalte', () {
      final d = bauen(
        [for (var i = 0; i < 9; i++) aufgabe('t$i', 'todo')],
        limit: 3,
      );
      expect(d.spalten[0].eintraege, hasLength(3));
    });

    test('ohne Aufgaben gilt das Board als leer', () {
      expect(bauen(const []).isEmpty, isTrue);
    });
  });

  group('Die Spalte kennt ihren Schluessel', () {
    test('Datenbankwert, nicht Beschriftung', () {
      // "Offen" steht auf dem Bildschirm, `todo` in der Datenbank. Nur mit
      // dem Schluessel laesst sich eine Karte hierher verschieben.
      final d = bauen([aufgabe('a', 'todo')]);
      expect(d.spalten.map((s) => s.schluessel),
          ['todo', 'in_progress', 'done']);
    });
  });

  group('Im Baukasten', () {
    test('nur das Board nimmt diese Datenform', () {
      final passende =
          TileViews.forShape(TileShape.board).map((v) => v.key).toList();
      expect(passende, ['board']);
    });

    test('es braucht die ganze Flaeche', () {
      // Daran entscheidet die Kuechenseite, dass es ueber die volle Breite
      // geht statt in eine Rasterspalte.
      expect(TileViews.byKey('board')!.fuelltFlaeche, isTrue);
    });

    test('es kann eine Aufgabe anlegen', () {
      expect(TileCatalog.byKey('tasks.board')!.aktion?.recht, 'tasks:write');
    });
  });

  group('Gezeichnet', () {
    testWidgets('ohne Rueckkanal laesst sich nichts ziehen', (tester) async {
      // Im Dashboard am Rechner zeigt das Board nur.
      await zeichne(tester, bauen([aufgabe('a', 'todo')]));
      expect(find.byType(Draggable<TileCheckItem>), findsNothing);
      expect(find.byType(LongPressDraggable<TileCheckItem>), findsNothing);
    });

    testWidgets('mit Rueckkanal sind die Karten ziehbar', (tester) async {
      await zeichne(tester, bauen([aufgabe('a', 'todo')]),
          kontext: TileKontext(verschieben: (_, _) async {}));
      final ziehbar = find.byWidgetPredicate((w) =>
          w is Draggable<TileCheckItem> ||
          w is LongPressDraggable<TileCheckItem>);
      expect(ziehbar, findsOneWidget);
    });

    testWidgets('eine Karte in eine andere Spalte ziehen meldet die Spalte',
        (tester) async {
      final gemeldet = <String, String>{};
      await zeichne(
        tester,
        bauen([aufgabe('Muell', 'todo')]),
        kontext: TileKontext(
            verschieben: (id, spalte) async => gemeldet[id] = spalte),
      );

      // Von der Karte auf die dritte Spalte ("Erledigt").
      final karte = find.text('Muell');
      final ziel = find.text('Erledigt');
      final griff = await tester.startGesture(tester.getCenter(karte));
      // Langer Druck, damit auch die Tablet-Variante ausloest.
      await tester.pump(const Duration(seconds: 1));
      await griff.moveTo(tester.getCenter(ziel) + const Offset(0, 60));
      await tester.pump();
      await griff.up();
      await tester.pump();

      expect(gemeldet, {'Muell': 'done'});
    });

    testWidgets('in die eigene Spalte zu ziehen meldet nichts', (tester) async {
      // Kein Fehler, aber auch keine Aenderung.
      var gerufen = false;
      await zeichne(
        tester,
        bauen([aufgabe('Muell', 'todo')]),
        kontext: TileKontext(verschieben: (_, _) async => gerufen = true),
      );

      final karte = find.text('Muell');
      final griff = await tester.startGesture(tester.getCenter(karte));
      await tester.pump(const Duration(seconds: 1));
      await griff.moveTo(tester.getCenter(find.text('Offen')) + const Offset(0, 60));
      await tester.pump();
      await griff.up();
      await tester.pump();

      expect(gerufen, isFalse);
    });

    testWidgets('alle drei Spalten stehen nebeneinander', (tester) async {
      await zeichne(tester, bauen([aufgabe('a', 'todo')]));
      expect(find.text('Offen'), findsOneWidget);
      expect(find.text('In Arbeit'), findsOneWidget);
      expect(find.text('Erledigt'), findsOneWidget);
    });

    testWidgets('die Karte steht in ihrer Spalte', (tester) async {
      await zeichne(tester, bauen([aufgabe('Muell rausbringen', 'todo')]));
      expect(find.text('Muell rausbringen'), findsOneWidget);
    });

    testWidgets('viele Karten sprengen die Spalte nicht', (tester) async {
      await zeichne(
        tester,
        bauen([for (var i = 0; i < 20; i++) aufgabe('t$i', 'todo')], limit: 20),
        hoehe: 320,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('auf schmalem Bildschirm bleibt es heil', (tester) async {
      // Dann wird geschoben statt gequetscht.
      await zeichne(tester, bauen([aufgabe('a', 'todo')]),
          breite: 360, hoehe: 300);
      expect(tester.takeException(), isNull);
    });
  });
}
