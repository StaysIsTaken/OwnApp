import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:productivity/dataclasses/haushalt.dart';
import 'package:productivity/dataservice/haushalt_sicht.dart';
import 'package:productivity/provider/haushalt_provider.dart';
import 'package:productivity/widgets/bereich_umschalter.dart';
import 'package:provider/provider.dart';

/// Die Umschaltung „Alles / Meins / Unseres".
///
/// Der erste Test ist der, auf den es ankommt: **ohne Haushalt ist sie
/// nicht da.** Das ist das Leitprinzip an der sichtbarsten Stelle jeder
/// Modulseite, und es ist die Zeile, die beim vierten Einbauen jemand
/// vergisst.
void main() {
  Future<void> zeige(
    WidgetTester tester, {
    Haushalt? haushalt,
    Bereich bereich = Bereich.alles,
    ValueChanged<Bereich>? onWechsel,
  }) async {
    final h = HaushaltProvider()..uebernehmen(haushalt);
    await tester.pumpWidget(
      ChangeNotifierProvider<HaushaltProvider>.value(
        value: h,
        child: MaterialApp(
          home: Scaffold(
            body: BereichsUmschalter(
              bereich: bereich,
              onWechsel: onWechsel ?? (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  const zuhause = Haushalt(
    id: 1,
    name: 'Zuhause',
    ownerId: 'u1',
    mitglieder: [
      Mitglied(userId: 'u1', name: 'Alice', rolle: 'besitzer'),
      Mitglied(userId: 'u2', name: 'Bob'),
    ],
  );

  testWidgets('ohne Haushalt ist sie nicht da', (tester) async {
    await zeige(tester);
    expect(find.byType(SegmentedButton<Bereich>), findsNothing);
    expect(find.text('Unseres'), findsNothing);
  });

  testWidgets('ohne Haushalt nimmt sie auch keinen Platz weg',
      (tester) async {
    // Ein `Visibility` liesse die Luecke stehen. Der Platz soll weg sein,
    // nicht nur der Inhalt.
    await zeige(tester);
    final groesse = tester.getSize(find.byType(BereichsUmschalter));
    expect(groesse.height, 0);
  });

  testWidgets('im Haushalt stehen alle drei da', (tester) async {
    await zeige(tester, haushalt: zuhause);
    expect(find.text('Alles'), findsOneWidget);
    expect(find.text('Meins'), findsOneWidget);
    expect(find.text('Unseres'), findsOneWidget);
  });

  testWidgets('ein Tipp meldet den neuen Bereich', (tester) async {
    Bereich? gewaehlt;
    await zeige(tester,
        haushalt: zuhause, onWechsel: (b) => gewaehlt = b);

    await tester.tap(find.text('Unseres'));
    await tester.pumpAndSettle();
    expect(gewaehlt, Bereich.unseres);
  });

  testWidgets('die Beschriftung lässt sich anpassen', (tester) async {
    // „Meine Rezepte" liest sich besser als „Meins", wenn daneben
    // „Unsere Rezepte" stünde.
    final h = HaushaltProvider()..uebernehmen(zuhause);
    await tester.pumpWidget(
      ChangeNotifierProvider<HaushaltProvider>.value(
        value: h,
        child: const MaterialApp(
          home: Scaffold(
            body: BereichsUmschalter(
              bereich: Bereich.alles,
              onWechsel: _nichts,
              meinsTitel: 'Meine',
              unseresTitel: 'Unsere',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Meine'), findsOneWidget);
    expect(find.text('Unsere'), findsOneWidget);
    expect(find.text('Meins'), findsNothing);
  });

  group('Was an die Abfrage gehängt wird', () {
    test('Alles hängt nichts an', () {
      // Sonst bekäme der Server einen Filter, den er als „nur eigene"
      // liest — und die Seite wäre nach dem Öffnen halb leer.
      expect(Bereich.alles.abfrage, isEmpty);
    });

    test('Meins fragt nach den eigenen', () {
      expect(Bereich.meins.abfrage, {'eigene': true});
    });

    test('Unseres fragt nach denen des Haushalts', () {
      expect(Bereich.unseres.abfrage, {'unseres': true});
    });
  });

  group('Wohin Neues gehört', () {
    test('auf Unseres dem Haushalt', () {
      expect(Bereich.unseres.legtFuerHaushaltAn, isTrue);
    });

    test('auf Alles und Meins mir', () {
      // Im Zweifel persönlich: das lässt sich hinterher teilen, während
      // sich Geteiltes nicht ungesehen machen lässt.
      expect(Bereich.alles.legtFuerHaushaltAn, isFalse);
      expect(Bereich.meins.legtFuerHaushaltAn, isFalse);
    });
  });
}

void _nichts(Bereich _) {}
