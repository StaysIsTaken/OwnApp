// Springt die Wochenansicht wirklich, oder rechnet sie nur richtig?
//
// Der bestehende Test prueft `zielStunde` -- die Entscheidung, welche
// Stunde gemeint ist. Der Fehler, den der Nutzer gemeldet hatte, sass aber
// NICHT dort, sondern im Sprung selbst: er lag in `initState`, und im
// TabBarView hat der Scroll-Controller beim ersten Frame oft noch keine
// Ausdehnung. `maxScrollExtent` war 0, das `clamp` machte daraus 0, und die
// Ansicht begann bei Mitternacht.
//
// Ein Test, der nur die Rechnung prueft, waere gruen geblieben, waehrend
// genau das kaputt ist. Deshalb dieser hier: er zeichnet die Ansicht und
// sieht nach, wo sie steht.
//
// Die Gegenprobe (alte Fassung wiederhergestellt) macht GENAU EINEN dieser
// Tests rot -- den ersten. Bei den anderen beiden steht dabei, warum sie
// nicht unterscheiden. Vier Haekchen, von denen nur eines traegt, waeren
// schlimmer als eines.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:productivity/provider/planner_provider.dart';
import 'package:productivity/provider/settings_provider.dart';
import 'package:productivity/tabs/planner/views/week_view.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Dieselbe Stundenhoehe wie in der Ansicht.
const double stundenHoehe = 64.0;

Future<double> offsetNachAufbau(WidgetTester tester,
    {required DateTime datum, double hoehe = 500}) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = Size(800, hoehe);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(MultiProvider(
    providers: [
      // Frisch und leer: `isLoading` ist false, `entries` leer. Mehr
      // braucht das Raster nicht, um gezeichnet zu werden.
      ChangeNotifierProvider(create: (_) => PlannerProvider()),
      ChangeNotifierProvider(create: (_) => SettingsProvider()),
    ],
    child: MaterialApp(home: Scaffold(body: WeekView(selectedDate: datum))),
  ));
  await tester.pumpAndSettle();

  final rolle = tester
      .widgetList<SingleChildScrollView>(find.byType(SingleChildScrollView))
      .firstWhere((s) => s.controller != null);
  return rolle.controller!.offset;
}

void main() {
  testWidgets('die aktuelle Woche beginnt bei der jetzigen Stunde',
      (tester) async {
    final jetzt = DateTime.now();
    final offset = await offsetNachAufbau(tester, datum: jetzt);

    // Eine Stunde Vorlauf, damit der eben vergangene Termin noch zu sehen
    // ist. Genau das hat die alte Fassung nicht getan: sie sprang auf eine
    // feste 7 -- oder, wenn der Controller noch nicht ausgemessen war,
    // gar nicht.
    final erwartet =
        ((jetzt.hour + jetzt.minute / 60.0 - 1) * stundenHoehe).clamp(0.0, 1e9);

    expect(offset, closeTo(erwartet, stundenHoehe),
        reason: 'Steht bei ${offset / stundenHoehe + 1} Uhr statt bei '
            '${jetzt.hour}:${jetzt.minute}');
  });

  // ACHTUNG, dieser Test unterscheidet NICHT: die alte Fassung sprang auf
  // eine feste 7 und stand damit ebenfalls ueber null. Er faengt nur den
  // schlimmsten Fall -- „klebt ganz oben" --, und den hat die Gegenprobe
  // bestaetigt gelassen. Er bleibt trotzdem stehen: genau so hat der Nutzer
  // den Fehler beschrieben, und wenn der Sprung je wieder ins Leere laeuft,
  // ist DIESER Test der, der es in seinen Worten sagt.
  testWidgets('nicht bei Mitternacht', (tester) async {
    final jetzt = DateTime.now();
    if (jetzt.hour < 2) return; // Nachts waere 0 die richtige Antwort.

    final offset = await offsetNachAufbau(tester, datum: jetzt);
    expect(offset, greaterThan(0.0),
        reason: 'Die Ansicht klebt oben, obwohl es ${jetzt.hour} Uhr ist');
  });

  // Unterscheidet ebenfalls nicht, und zwar durch einen Zufall der Zahlen:
  // die alte Fassung sprang auf 7 * 64 = 448, der Vormittags-Rueckfall
  // landet bei (8 - 1) * 64 = 448. Dasselbe Ergebnis aus verschiedenen
  // Gruenden. Geprueft wird die Entscheidung dahinter in
  // kalender_startzeit_test.dart; hier steht nur, dass sie beim Controller
  // ankommt.
  testWidgets('eine fremde Woche beginnt beim Vormittag', (tester) async {
    // „Jetzt" sagt nichts ueber eine Woche aus, die man weggeblaettert hat.
    final fremd = DateTime.now().add(const Duration(days: 21));
    final offset = await offsetNachAufbau(tester, datum: fremd);

    expect(offset, closeTo((8 - 1) * stundenHoehe, stundenHoehe));
  });

  testWidgets('wer selbst scrollt, wird nicht zurueckgerissen',
      (tester) async {
    // Ein Raster, das bei jedem Neuzeichnen zur Uhrzeit zurueckspringt,
    // waere unbenutzbar.
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(800, 500);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final planer = PlannerProvider();
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: planer),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
      ],
      child: MaterialApp(
          home: Scaffold(body: WeekView(selectedDate: DateTime.now()))),
    ));
    await tester.pumpAndSettle();

    final rolle = tester
        .widgetList<SingleChildScrollView>(find.byType(SingleChildScrollView))
        .firstWhere((s) => s.controller != null)
        .controller!;

    rolle.jumpTo(0);
    await tester.pump();
    // Ein Neuzeichnen ausloesen, wie es der Provider staendig tut.
    planer.notifyListeners();
    await tester.pumpAndSettle();

    expect(rolle.offset, 0.0);
  });
}
