import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:productivity/provider/permission_provider.dart';
import 'package:productivity/provider/user_provider.dart';
import 'package:productivity/widgets/drawer.dart';
import 'package:provider/provider.dart';

/// Baut den Drawer mit genau diesen Rechten.
Future<void> _zeige(WidgetTester tester, Set<String> rechte) async {
  // Der Drawer ist hoeher als die Standard-Testflaeche von 800x600.
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final p = PermissionProvider()..uebernehmen(rechte);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<PermissionProvider>.value(value: p),
        // Der Kopf des Drawers zeigt den angemeldeten Nutzer an.
        ChangeNotifierProvider<UserProvider>(create: (_) => UserProvider()),
      ],
      child: const MaterialApp(
        home: Scaffold(drawer: DrawerWidget(), body: SizedBox()),
      ),
    ),
  );
  await tester.pumpAndSettle();
  // Den Drawer aufziehen
  final state = tester.state<ScaffoldState>(find.byType(Scaffold));
  state.openDrawer();
  await tester.pumpAndSettle();
}

void main() {

  testWidgets('kein Menüpunkt heißt wie ein anderer', (tester) async {
    // „Kalender" gab es schon für die Kalenderansicht. Ein zweiter Eintrag
    // desselben Namens für die Verwaltung war schlicht nicht zu finden –
    // genau das ist passiert, und genau das faellt hier jetzt auf.
    await _zeige(tester, {'*'});

    final beschriftungen = tester
        .widgetList<Text>(find.descendant(
          of: find.byType(ListTile),
          matching: find.byType(Text),
        ))
        .map((t) => t.data)
        .whereType<String>()
        .toList();

    final doppelte = beschriftungen
        .where((n) => beschriftungen.where((m) => m == n).length > 1)
        .toSet();
    expect(doppelte, isEmpty, reason: 'Doppelt vergebene Menünamen: $doppelte');
  });

  testWidgets('die Kalenderverwaltung steht im Menü', (tester) async {
    await _zeige(tester, {'*'});
    expect(find.text('Kalender verwalten'), findsOneWidget);
  });

  testWidgets('mit allen Rechten steht alles im Menü', (tester) async {
    await _zeige(tester, {'*'});
    expect(find.text('Vorräte'), findsOneWidget);
    expect(find.text('Notizen'), findsOneWidget);
    expect(find.text('Zeiten'), findsOneWidget);
  });

  testWidgets('ohne Vorratsrecht fehlt der Eintrag', (tester) async {
    await _zeige(tester, {'notes:read'});
    expect(find.text('Notizen'), findsOneWidget);
    expect(find.text('Vorräte'), findsNothing);
  });

  testWidgets('ein leerer Abschnitt verschwindet samt Überschrift',
      (tester) async {
    // Sonst stünde "VORRÄTE" über nichts.
    await _zeige(tester, {'notes:read'});
    expect(find.text('VORRÄTE'), findsNothing);
    expect(find.text('WISSENSMANAGEMENT'), findsOneWidget);
  });

  testWidgets('die Verwaltung sieht nur, wer verwalten darf', (tester) async {
    await _zeige(tester, {'notes:read'});
    expect(find.text('Benutzer & Rollen'), findsNothing);

    await _zeige(tester, {'admin:roles'});
    expect(find.text('Benutzer & Rollen'), findsOneWidget);
  });

  testWidgets('Einstellungen bleiben immer erreichbar', (tester) async {
    await _zeige(tester, {});
    expect(find.text('Einstellungen'), findsOneWidget);
  });
}
