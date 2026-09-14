// Die gemeinsamen Teile der beiden Wochenansichten.
//
// Sie sind ausgelagert, weil sie wirklich dasselbe sind -- NICHT die
// ganzen Ansichten. Die Kachel leitet Stundenfenster und Stundenhoehe aus
// dem vorhandenen Platz ab und legt Termine absolut in einen Stack; der
// Planner zeigt 0 bis 24 bei fester Hoehe, baut Tagesspalten, rechnet
// Ueberlappungen in Nebenspalten und laesst ziehen. Ein Widget, das beides
// koennte, waere schwerer zu lesen als die zwei Dateien zusammen.
//
// Der Gewinn steht in den letzten Tests: die Kachel zeigte bisher nur den
// ersten Ganztagstermin eines Tages und mehrtaegige nur am Anfangstag.
// Durch die Auslagerung bekommt sie beides mit.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:productivity/widgets/kalender/wochenraster_teile.dart';

Ganztagseintrag eintrag(String titel, DateTime von, DateTime bis,
        {VoidCallback? tipp}) =>
    Ganztagseintrag(
      titel: titel, von: von, bis: bis, farbe: Colors.blue, beiTipp: tipp,
    );

void main() {
  final montag = DateTime(2026, 9, 14);
  final woche = [for (var i = 0; i < 7; i++) montag.add(Duration(days: i))];

  group('Wo die Ansicht beginnt', () {
    test('in dieser Woche die jetzige Stunde', () {
      expect(zielStunde(jetzt: DateTime(2026, 9, 16, 11, 30),
              wochenStart: montag),
          11.5);
    });

    test('in einer fremden Woche der Vormittag', () {
      expect(zielStunde(jetzt: DateTime(2026, 9, 16, 11),
              wochenStart: DateTime(2026, 9, 21)),
          8.0);
    });

    test('der Versatz haelt eine Stunde Vorlauf', () {
      // Sonst klebt „jetzt" am oberen Rand und der eben vergangene Termin
      // ist nicht mehr zu sehen.
      expect(
          startVersatz(
              jetzt: DateTime(2026, 9, 16, 11),
              wochenStart: montag,
              stundenHoehe: 64),
          (11 - 1) * 64);
    });

    test('die Kachel rechnet ihr Stundenfenster ein', () {
      // Faengt die Kachel erst bei 8 Uhr an, liegt 11 Uhr nicht bei 11
      // Stunden, sondern bei drei.
      expect(
          startVersatz(
              jetzt: DateTime(2026, 9, 16, 11),
              wochenStart: montag,
              stundenHoehe: 56,
              abStunde: 8),
          (11 - 8 - 1) * 56);
    });

    test('nie unter null', () {
      // Kurz nach Mitternacht wuerde der Vorlauf negativ.
      expect(
          startVersatz(
              jetzt: DateTime(2026, 9, 14, 0, 30),
              wochenStart: montag,
              stundenHoehe: 64),
          0.0);
    });
  });

  group('Ganztaegige zuordnen', () {
    test('ein Tag', () {
      final e = eintrag('Feiertag', montag, DateTime(2026, 9, 14, 23, 59));
      expect(e.liegtAuf(montag), isTrue);
      expect(e.liegtAuf(montag.add(const Duration(days: 1))), isFalse);
    });

    test('mehrere Tage liegen auf JEDEM davon', () {
      // Der Gewinn fuer die Kachel: sie verglich bisher nur den Anfangstag.
      // Schulferien waren am Montag zu sehen und danach nie wieder.
      final e = eintrag('Ferien', montag, DateTime(2026, 9, 16, 23, 59));
      expect(e.liegtAuf(montag), isTrue);
      expect(e.liegtAuf(montag.add(const Duration(days: 1))), isTrue);
      expect(e.liegtAuf(montag.add(const Duration(days: 2))), isTrue);
      expect(e.liegtAuf(montag.add(const Duration(days: 3))), isFalse);
    });
  });

  group('Der Streifen', () {
    Future<void> zeichne(WidgetTester tester,
        List<Ganztagseintrag> eintraege) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Ganztagsstreifen(
              tage: woche, eintraege: eintraege, zeitBreite: 54),
        ),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('ohne Eintraege ist er gar nicht da', (tester) async {
      await zeichne(tester, const []);
      expect(find.text('ganztags'), findsNothing);
    });

    testWidgets('zwei am selben Tag stehen beide da', (tester) async {
      // Der zweite Gewinn fuer die Kachel: sie zeigte nur `heute.first`.
      // Feiertag und Schulferien fallen regelmaessig zusammen.
      final bis = DateTime(2026, 9, 14, 23, 59);
      await zeichne(tester, [
        eintrag('Feiertag', montag, bis),
        eintrag('Ferien', montag, bis),
      ]);
      expect(find.text('Feiertag'), findsOneWidget);
      expect(find.text('Ferien'), findsOneWidget);
    });

    testWidgets('mehrtaegige erscheinen an jedem Tag', (tester) async {
      await zeichne(tester, [
        eintrag('Ferien', montag, DateTime(2026, 9, 16, 23, 59)),
      ]);
      expect(find.text('Ferien'), findsNWidgets(3));
    });

    testWidgets('ohne Rueckruf ist nichts antippbar', (tester) async {
      // Die Kuechenansicht fuehrt bewusst nirgendwohin.
      await zeichne(tester, [
        eintrag('Feiertag', montag, DateTime(2026, 9, 14, 23, 59)),
      ]);
      expect(
          find.descendant(
              of: find.byType(Ganztagsstreifen),
              matching: find.byType(GestureDetector)),
          findsNothing);
    });

    testWidgets('mit Rueckruf schon', (tester) async {
      var getippt = 0;
      await zeichne(tester, [
        eintrag('Feiertag', montag, DateTime(2026, 9, 14, 23, 59),
            tipp: () => getippt++),
      ]);
      await tester.tap(find.text('Feiertag'));
      expect(getippt, 1);
    });
  });
}
