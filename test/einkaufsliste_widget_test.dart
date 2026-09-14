// Die Einkaufsliste ist die einzige Kachel, die etwas aendert. Deshalb
// steht sie hier doppelt auf dem Pruefstand: was sie zeigt, und was sie
// zurueckmeldet.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:productivity/dataclasses/einkauf.dart';
import 'package:productivity/tabs/dashboard/custom/tile_catalog.dart';
import 'package:productivity/tabs/dashboard/custom/tile_checklist_view.dart';
import 'package:productivity/tabs/dashboard/custom/tile_data.dart';
import 'package:productivity/tabs/dashboard/custom/tile_spec.dart';
import 'package:productivity/tabs/dashboard/custom/tile_views.dart';

Einkaufsposition position(int id, String name,
        {bool erledigt = false, double? menge}) =>
    Einkaufsposition(
      id: id, listId: 7, name: name, erledigt: erledigt, menge: menge,
    );

TileData bauen(List<Einkaufsposition> positionen, {int liste = 7}) =>
    TileCatalog.byKey('einkauf.liste')!.build(
      DashboardData(einkauf: {7: positionen}),
      {'liste': liste},
      const [],
    );

Future<void> zeichne(WidgetTester tester, TileData daten,
    {TileKontext kontext = TileKontext.leer}) async {
  tester.view.physicalSize = const Size(600, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 400,
        height: 600,
        child: TileChecklistView(data: daten, kontext: kontext),
      ),
    ),
  ));
  await tester.pump();
}

void main() {

  group('Was die Quelle liefert', () {
    test('der Name steht da, so wie er getippt wurde', () {
      // Frueher stand hier die Zutat, und ohne Zutat ging gar nichts.
      // Jetzt ist der Name die Position.
      expect(bauen([position(1, 'Milch')]).haken.single.titel, 'Milch');
    });

    test('eine Menge steht darunter', () {
      final d = bauen([position(1, 'Milch', menge: 2)]);
      expect(d.haken.single.untertitel, '2');
    });

    test('ohne Menge bleibt die Zeile leer', () {
      // Sonst stuende unter jedem Posten eine leere Zeile.
      expect(bauen([position(1, 'Milch')]).haken.single.untertitel, isNull);
    });

    test('der Zustand kommt mit', () {
      final d = bauen([position(1, 'Brot', erledigt: true)]);
      expect(d.haken.single.erledigt, isTrue);
    });

    test('leere Liste meldet sich als leer', () {
      expect(bauen(const []).isEmpty, isTrue);
    });

    test('ohne gewaehlte Liste bleibt die Kachel leer', () {
      // Auf einem Kuechengeraet ist "die falsche Liste" der schlechtere
      // Fehler als "noch nichts eingestellt".
      final d = TileCatalog.byKey('einkauf.liste')!.build(
        DashboardData(einkauf: {7: [position(1, 'Milch')]}),
        const {},
        const [],
      );
      expect(d.isEmpty, isTrue);
      expect(d.emptyHint, contains('keine Liste'));
    });

    test('eine andere Liste zeigt nichts von dieser', () {
      final d = bauen([position(1, 'Milch')], liste: 99);
      expect(d.haken, isEmpty);
    });
  });

  group('Im Baukasten', () {
    test('die Quelle hat einen Parameter fuer die Liste', () {
      // Ohne ihn koennte eine Kachel nicht sagen, welchen Zettel sie zeigt.
      final quelle = TileCatalog.byKey('einkauf.liste')!;
      expect(quelle.params.map((p) => p.key), contains('liste'));
      expect(quelle.params.first.art, ParamArt.einkaufsliste);
    });

    test('nur die Abhakliste nimmt diese Datenform', () {
      expect(TileViews.forShape(TileShape.checklist).map((v) => v.key),
          ['checklist']);
    });

    test('sie braucht die Flaeche – auch leer, wegen des Eingabefelds', () {
      expect(TileViews.byKey('checklist')!.fuelltFlaeche, isTrue);
    });
  });

  group('Gezeichnet', () {
    testWidgets('Abgehaktes rutscht nach unten statt zu verschwinden',
        (tester) async {
      // Wer sich verklickt, muss es zurueckholen koennen – und wer im Laden
      // steht, will sehen, was schon im Wagen liegt.
      final d = TileData.checklist(const [
        TileCheckItem(id: 'a', titel: 'Brot', erledigt: true),
        TileCheckItem(id: 'b', titel: 'Milch'),
      ]);
      await zeichne(tester, d);

      expect(find.text('Brot'), findsOneWidget);
      expect(find.text('Milch'), findsOneWidget);
      expect(tester.getTopLeft(find.text('Milch')).dy,
          lessThan(tester.getTopLeft(find.text('Brot')).dy));
    });

    testWidgets('ein Tipp meldet den neuen Zustand', (tester) async {
      final gemeldet = <String, bool>{};
      await zeichne(
        tester,
        TileData.checklist(
            const [TileCheckItem(id: 'a', titel: 'Brot')]),
        kontext: TileKontext(
            umschalten: (id, wert) async => gemeldet[id] = wert),
      );

      await tester.tap(find.text('Brot'));
      await tester.pump();
      expect(gemeldet, {'a': true});
    });

    testWidgets('ohne Rueckkanal laesst sich nichts abhaken', (tester) async {
      // Dieselbe Kachel im Dashboard am Rechner: dort zeigt sie nur.
      await zeichne(tester,
          TileData.checklist(const [TileCheckItem(id: 'a', titel: 'Brot')]));
      final kasten = tester.widget<Checkbox>(find.byType(Checkbox));
      expect(kasten.onChanged, isNull);
    });

    testWidgets('das Eingabefeld erscheint nur mit Rueckkanal', (tester) async {
      await zeichne(tester, TileData.checklist(const []));
      expect(find.byType(TextField), findsNothing);

      await zeichne(tester, TileData.checklist(const []),
          kontext: TileKontext(hinzufuegen: (_) async {}));
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('Eingetipptes wird weitergereicht', (tester) async {
      String? bekommen;
      await zeichne(tester, TileData.checklist(const []),
          kontext: TileKontext(hinzufuegen: (t) async => bekommen = t));

      await tester.enterText(find.byType(TextField), '  Butter  ');
      await tester.pump();
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      // Getrimmt: Leerzeichen am Rand sind kein Teil des Namens.
      expect(bekommen, 'Butter');
    });

    testWidgets('leerer Text wird nicht abgeschickt', (tester) async {
      var gerufen = false;
      await zeichne(tester, TileData.checklist(const []),
          kontext: TileKontext(hinzufuegen: (_) async => gerufen = true));

      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(gerufen, isFalse);
    });

    testWidgets('leere Liste zeigt ihren Hinweis', (tester) async {
      await zeichne(tester,
          const TileData.checklist([], emptyHint: 'Die Liste ist leer'));
      expect(find.text('Die Liste ist leer'), findsOneWidget);
    });
  });
}
