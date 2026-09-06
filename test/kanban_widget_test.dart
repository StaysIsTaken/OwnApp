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
    {double breite = 1200, double hoehe = 600}) async {
  tester.view.physicalSize = Size(breite + 100, hoehe + 100);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: breite,
          height: hoehe,
          child: TileBoardView(data: daten),
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
      expect(d.spalten[0].eintraege.single.title, 'offen');
      expect(d.spalten[1].eintraege.single.title, 'laeuft');
      expect(d.spalten[2].eintraege.single.title, 'fertig');
    });

    test('ein unbekannter Zustand faellt nicht unter den Tisch', () {
      // Sonst verschwindet die Aufgabe spurlos vom Board.
      final d = bauen([aufgabe('seltsam', 'irgendwas')]);
      expect(d.spalten[0].eintraege.single.title, 'seltsam');
    });

    test('Faellige stehen oben', () {
      final d = bauen([
        aufgabe('ohne Datum', 'todo'),
        aufgabe('bald', 'todo', faellig: DateTime(2026, 9, 10)),
      ]);
      expect(d.spalten[0].eintraege.first.title, 'bald');
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
