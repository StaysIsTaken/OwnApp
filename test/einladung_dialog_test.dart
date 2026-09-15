import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:productivity/dataclasses/haushalt.dart';
import 'package:productivity/tabs/haushalt/einladung_dialog.dart';

/// Das Pop-up beim Annehmen — die Stelle, an der jemand etwas preisgibt.
///
/// Es ist nicht überspringbar und hat die Vorgabe `nichts`. Beides steht
/// hier als Test, weil beides genau einmal falsch herum gebaut werden
/// muss, damit hinterher jemand mehr von sich zeigt als gewollt.
void main() {
  const einladung = Einladung(
    id: 7,
    haushaltId: 1,
    haushaltName: 'Zuhause',
    userId: 'u2',
    userName: 'Bob',
    vonId: 'u1',
    vonName: 'Alice',
  );

  /// Zeigt den Dialog. Was er am Ende liefert, landet in der Liste --
  /// der Rueckgabewert steht erst fest, wenn der Dialog zu ist.
  Future<List<Finanzsicht?>> zeige(WidgetTester tester) async {
    final ergebnis = <Finanzsicht?>[];
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            onPressed: () async {
              ergebnis.add(
                  await EinladungDialog.zeige(context, einladung: einladung));
            },
            child: const Text('auf'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('auf'));
    await tester.pumpAndSettle();
    return ergebnis;
  }

  testWidgets('es steht da, wer einlädt und wohin', (tester) async {
    await zeige(tester);
    expect(find.text('„Zuhause" beitreten'), findsOneWidget);
    expect(find.textContaining('Alice'), findsOneWidget);
  });

  testWidgets('alle vier Stufen stehen mit ihrer Erklärung da',
      (tester) async {
    await zeige(tester);
    for (final stufe in Finanzsicht.values) {
      expect(find.text(stufe.titel), findsOneWidget,
          reason: 'Stufe „${stufe.titel}" fehlt');
      expect(find.text(stufe.erklaerung), findsOneWidget,
          reason: 'Erklärung zu „${stufe.titel}" fehlt');
    }
  });

  testWidgets('wer nur beitritt, gibt nichts preis', (tester) async {
    // DIE Zeile, die man leicht falsch herum baut: wer das Pop-up
    // wegtippt, ohne etwas anzufassen, darf nichts preisgeben.
    final ergebnis = await zeige(tester);
    await tester.tap(find.text('Beitreten'));
    await tester.pumpAndSettle();

    expect(ergebnis, [Finanzsicht.nichts]);
  });

  testWidgets('eine gewählte Stufe kommt auch heraus', (tester) async {
    final ergebnis = await zeige(tester);
    await tester.tap(find.text(Finanzsicht.kategorien.titel));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Beitreten'));
    await tester.pumpAndSettle();

    expect(ergebnis, [Finanzsicht.kategorien]);
  });

  testWidgets('Abbrechen tritt niemandem bei', (tester) async {
    // null heisst: es wurde nichts angenommen. Eine Stufe zurueckzugeben
    // hiesse, dass die aufrufende Seite trotzdem beitritt.
    final ergebnis = await zeige(tester);
    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();

    expect(ergebnis, [null]);
    expect(find.byType(AlertDialog), findsNothing);
  });
}
