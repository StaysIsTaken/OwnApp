// Uhr und Timer. Die Textformung ist reine Rechnung und laesst sich ohne
// Warten pruefen; das Verhalten braucht eine Uhr, die man vorstellen kann
// -- dafuer taugt pump(Dauer) im Widget-Test.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:productivity/tabs/dashboard/custom/tile_catalog.dart';
import 'package:productivity/tabs/dashboard/custom/tile_clock_view.dart';
import 'package:productivity/tabs/dashboard/custom/tile_data.dart';
import 'package:productivity/tabs/dashboard/custom/tile_spec.dart';
import 'package:productivity/dataservice/timer_ton.dart';
import 'package:productivity/tabs/dashboard/custom/tile_views.dart';

/// Nur im Dialog suchen. Dieselbe Zeit steht oft auch in der Kachel
/// dahinter – ohne Eingrenzung findet man zwei und weiss nicht, welche.
Finder imDialog(String text) => find.descendant(
      of: find.byType(AlertDialog),
      matching: find.text(text),
    );

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
  setUp(() {
    // Kein Ton im Test – gezaehlt wird trotzdem, und darum geht es.
    TimerTon.stumm = true;
    TimerTon.gespielt = 0;
  });

  group('Der Ton beim Ablaufen', () {
    Future<void> timerStarten(WidgetTester tester, String vorgabe) async {
      await zeichne(tester);
      await tester.tap(find.text('Timer'));
      await tester.pump();
      await tester.tap(find.text(vorgabe));
      await tester.pump();
      await tester.tap(find.text('Start'));
      await tester.pump();
    }

    testWidgets('klingelt, wenn er abgelaufen ist', (tester) async {
      await timerStarten(tester, '1 min');
      expect(TimerTon.gespielt, 0);
      await tester.pump(const Duration(seconds: 60));
      expect(TimerTon.gespielt, 1);
    });

    testWidgets('klingelt genau einmal, nicht bei jedem Takt danach',
        (tester) async {
      // Sonst laeutet es im Sekundentakt weiter, bis jemand hinsieht.
      await timerStarten(tester, '1 min');
      await tester.pump(const Duration(seconds: 60));
      await tester.pump(const Duration(seconds: 10));
      expect(TimerTon.gespielt, 1);
    });

    testWidgets('klingelt nicht, solange er laeuft', (tester) async {
      await timerStarten(tester, '3 min');
      await tester.pump(const Duration(seconds: 30));
      expect(TimerTon.gespielt, 0);
    });

    testWidgets('klingelt nicht, wenn man ihn vorher anhaelt', (tester) async {
      await timerStarten(tester, '1 min');
      await tester.pump(const Duration(seconds: 30));
      await tester.tap(find.text('Pause'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 60));
      expect(TimerTon.gespielt, 0);
    });

    testWidgets('ein zweiter Durchlauf klingelt wieder', (tester) async {
      await timerStarten(tester, '1 min');
      await tester.pump(const Duration(seconds: 60));
      expect(TimerTon.gespielt, 1);

      await tester.tap(find.text('Start'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 60));
      expect(TimerTon.gespielt, 2);
    });
  });

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

  group('Eigene Zeit', () {
    Future<void> zumTimer(WidgetTester tester) async {
      await zeichne(tester, hoehe: 620);
      await tester.tap(find.text('Timer'));
      await tester.pump();
    }

    testWidgets('die Vorgaben bleiben', (tester) async {
      // Sie decken den haeufigen Fall in einem Tipp ab.
      await zumTimer(tester);
      for (final v in ['1 min', '3 min', '5 min', '10 min', '15 min', '30 min']) {
        expect(find.text(v), findsOneWidget, reason: v);
      }
    });

    testWidgets('daneben steht "Eigene"', (tester) async {
      await zumTimer(tester);
      expect(find.text('Eigene'), findsOneWidget);
    });

    testWidgets('Minuten und Sekunden lassen sich stellen', (tester) async {
      await zumTimer(tester);
      await tester.tap(find.text('Eigene'));
      await tester.pumpAndSettle();

      // Vorgabe ist 5 Minuten, also 05:00 im Dialog. Auf den Dialog
      // eingegrenzt: dieselbe Zahl steht auch in der Kachel dahinter.
      expect(imDialog('05:00'), findsOneWidget);

      // Zweimal plus bei den Sekunden.
      final plus = find.byIcon(Icons.add_rounded);
      await tester.tap(plus.last);
      await tester.pump();
      await tester.tap(plus.last);
      await tester.pump();
      expect(imDialog('05:02'), findsOneWidget);

      await tester.tap(find.text('Übernehmen'));
      await tester.pumpAndSettle();

      // Zweimal, und beides gehoert so: gross als Restzeit, und auf dem
      // Knopf, damit man sieht, was eingestellt ist.
      expect(find.text('05:02'), findsNWidgets(2));
    });

    testWidgets('ueber die Sekundengrenze wird umgerechnet', (tester) async {
      // Wer bei 55 Sekunden zweimal auf +10 tippt, meint 1:15 – nicht
      // "geht nicht".
      await zumTimer(tester);
      await tester.tap(find.text('Eigene'));
      await tester.pumpAndSettle();

      // Von 05:00 sechsmal +10 Sekunden = 06:00.
      final vielMehr = find.byIcon(Icons.keyboard_double_arrow_right_rounded);
      for (var i = 0; i < 6; i++) {
        await tester.tap(vielMehr.last);
        await tester.pump();
      }
      expect(imDialog('06:00'), findsOneWidget);
    });

    testWidgets('unter null geht es nicht', (tester) async {
      await zumTimer(tester);
      await tester.tap(find.text('1 min'));
      await tester.pump();
      await tester.tap(find.text('Eigene'));
      await tester.pumpAndSettle();

      final vielWeniger = find.byIcon(Icons.keyboard_double_arrow_left_rounded);
      for (var i = 0; i < 5; i++) {
        await tester.tap(vielWeniger.first);
        await tester.pump();
      }
      expect(imDialog('00:00'), findsOneWidget);
    });

    testWidgets('null laesst sich nicht uebernehmen', (tester) async {
      // Null Sekunden sind keine Zeit, die man stellen will.
      await zumTimer(tester);
      await tester.tap(find.text('Eigene'));
      await tester.pumpAndSettle();

      final vielWeniger = find.byIcon(Icons.keyboard_double_arrow_left_rounded);
      for (var i = 0; i < 3; i++) {
        await tester.tap(vielWeniger.first);
        await tester.pump();
      }
      expect(imDialog('00:00'), findsOneWidget);

      final knopf = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Übernehmen'));
      expect(knopf.onPressed, isNull);
    });

    testWidgets('Abbrechen aendert nichts', (tester) async {
      await zumTimer(tester);
      await tester.tap(find.text('Eigene'));
      await tester.pumpAndSettle();
      final plus = find.byIcon(Icons.add_rounded);
      await tester.tap(plus.last);
      await tester.pump();
      await tester.tap(find.text('Abbrechen'));
      await tester.pumpAndSettle();

      expect(find.text('05:00'), findsOneWidget);
    });

    testWidgets('eine eigene Zeit steht auf dem Knopf', (tester) async {
      // Sonst saehe "7:23 eingestellt" aus wie "nichts eingestellt".
      await zumTimer(tester);
      await tester.tap(find.text('Eigene'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.add_rounded).last);
      await tester.pump();
      await tester.tap(find.text('Übernehmen'));
      await tester.pumpAndSettle();

      expect(find.text('Eigene'), findsNothing);
      expect(find.text('05:01'), findsAtLeast(1));
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
