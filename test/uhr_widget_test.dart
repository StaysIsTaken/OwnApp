// Uhr und Timer. Die Textformung ist reine Rechnung und laesst sich ohne
// Warten pruefen; das Verhalten braucht eine Uhr, die man vorstellen kann
// -- dafuer taugt pump(Dauer) im Widget-Test.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:productivity/tabs/dashboard/custom/tile_catalog.dart';
import 'package:productivity/tabs/dashboard/custom/tile_clock_view.dart';
import 'package:productivity/tabs/dashboard/custom/tile_data.dart';
import 'package:productivity/tabs/dashboard/custom/tile_spec.dart';
import 'package:productivity/tabs/dashboard/custom/tile_views.dart';

Future<void> zeichne(WidgetTester tester, {double hoehe = 500}) async {
  tester.view.physicalSize = Size(700, hoehe + 100);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: SizedBox(width: 600, height: hoehe, child: const TileClockView()),
    ),
  ));
  await tester.pump();
}

void main() {
  group('Zeit als Text', () {
    test('immer zweistellig', () {
      expect(zeitText(DateTime(2026, 9, 5, 7, 4, 3)), '07:04:03');
    });

    test('ohne Sekunden auf Wunsch', () {
      expect(zeitText(DateTime(2026, 9, 5, 7, 4, 3), mitSekunden: false),
          '07:04');
    });

    test('Mitternacht ist 00, nicht 24', () {
      expect(zeitText(DateTime(2026, 9, 5, 0, 0, 0)), '00:00:00');
    });

    test('das Datum nennt den Wochentag', () {
      // 5.9.2026 ist ein Samstag.
      expect(datumText(DateTime(2026, 9, 5)), 'Samstag, 5.9.2026');
    });
  });

  group('Dauer als Text', () {
    test('unter einer Stunde ohne Stundenteil', () {
      // Auf einer Eieruhr ist 04:30 leichter zu lesen als 00:04:30.
      expect(dauerText(const Duration(minutes: 4, seconds: 30)), '04:30');
    });

    test('ab einer Stunde mit', () {
      expect(dauerText(const Duration(hours: 1, minutes: 2, seconds: 3)),
          '1:02:03');
    });

    test('null bleibt null', () {
      expect(dauerText(Duration.zero), '00:00');
    });

    test('negative Dauer zeigt nicht minus', () {
      // Ein Timer laeuft ab, er laeuft nicht rueckwaerts.
      expect(dauerText(const Duration(seconds: -5)), '00:00');
    });
  });

  group('Im Baukasten', () {
    test('die Uhr braucht keine Einstellung', () {
      final q = TileCatalog.byKey('uhr')!;
      expect(q.params, isEmpty);
      expect(q.fields, isEmpty);
      expect(q.filterable, isFalse);
    });

    test('sie fuehrt auch nirgendwohin', () {
      // Es gibt keine "Uhr-Seite", auf die sie verweisen koennte.
      expect(TileCatalog.byKey('uhr')!.route, isNull);
    });

    test('nur die Uhr nimmt diese Datenform', () {
      expect(TileViews.forShape(TileShape.ohne).map((v) => v.key), ['clock']);
    });

    test('sie gilt nie als leer', () {
      final d = TileCatalog.byKey('uhr')!
          .build(const DashboardData(), const {}, const []);
      expect(d.isEmpty, isFalse);
    });
  });

  group('Gezeichnet', () {
    testWidgets('zeigt zuerst die Uhrzeit', (tester) async {
      await zeichne(tester);
      expect(find.text('Uhr'), findsOneWidget);
      expect(find.text('Timer'), findsOneWidget);
      // Der Datumstext steht nur in der Uhransicht.
      expect(find.text(datumText(DateTime.now())), findsOneWidget);
    });

    testWidgets('die Uhr laeuft weiter', (tester) async {
      await zeichne(tester);
      final vorher = find.text(zeitText(DateTime.now()));
      expect(vorher, findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      // Nach einer Sekunde steht dort eine andere Zeit.
      expect(find.text(zeitText(DateTime.now())), findsOneWidget);
    });

    testWidgets('auf Timer umschalten zeigt die Dauer', (tester) async {
      await zeichne(tester);
      await tester.tap(find.text('Timer'));
      await tester.pump();

      expect(find.text('05:00'), findsOneWidget);
      expect(find.text('Start'), findsOneWidget);
    });

    testWidgets('eine Vorgabe stellt die Dauer', (tester) async {
      await zeichne(tester);
      await tester.tap(find.text('Timer'));
      await tester.pump();
      await tester.tap(find.text('3 min'));
      await tester.pump();

      expect(find.text('03:00'), findsOneWidget);
    });

    testWidgets('gestartet zaehlt er herunter', (tester) async {
      await zeichne(tester);
      await tester.tap(find.text('Timer'));
      await tester.pump();
      await tester.tap(find.text('1 min'));
      await tester.pump();
      await tester.tap(find.text('Start'));
      await tester.pump();

      await tester.pump(const Duration(seconds: 1));
      expect(find.text('00:59'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('00:58'), findsOneWidget);
    });

    testWidgets('Pause haelt ihn an', (tester) async {
      await zeichne(tester);
      await tester.tap(find.text('Timer'));
      await tester.pump();
      await tester.tap(find.text('1 min'));
      await tester.pump();
      await tester.tap(find.text('Start'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('00:58'), findsOneWidget);

      await tester.tap(find.text('Pause'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));
      // Steht immer noch dort.
      expect(find.text('00:58'), findsOneWidget);
    });

    testWidgets('abgelaufen meldet er sich', (tester) async {
      await zeichne(tester);
      await tester.tap(find.text('Timer'));
      await tester.pump();
      await tester.tap(find.text('1 min'));
      await tester.pump();
      await tester.tap(find.text('Start'));
      await tester.pump();

      // Ohne Ton bleibt nur das Bild – dann muss es deutlich sein.
      await tester.pump(const Duration(seconds: 60));
      expect(find.text('00:00'), findsOneWidget);
      expect(find.text('Fertig!'), findsOneWidget);
    });

    testWidgets('zurueck stellt die eingestellte Dauer wieder her',
        (tester) async {
      await zeichne(tester);
      await tester.tap(find.text('Timer'));
      await tester.pump();
      await tester.tap(find.text('3 min'));
      await tester.pump();
      await tester.tap(find.text('Start'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 5));
      expect(find.text('02:55'), findsOneWidget);

      await tester.tap(find.text('Zurück'));
      await tester.pump();
      expect(find.text('03:00'), findsOneWidget);
    });

    testWidgets('zurueck auf die Uhr zeigt wieder die Zeit', (tester) async {
      await zeichne(tester);
      await tester.tap(find.text('Timer'));
      await tester.pump();
      await tester.tap(find.text('Uhr'));
      await tester.pump();
      expect(find.text(datumText(DateTime.now())), findsOneWidget);
    });
  });
}
