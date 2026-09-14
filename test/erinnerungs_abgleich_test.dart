// Der Abgleich, der die vorgemerkten Erinnerungen auffuellt.
//
// Warum es ihn gibt: eine Erinnerung entsteht auf dem GERAET, nicht auf dem
// Server. Jedes Geraet fuehrt seinen eigenen Vorrat und muss ihn auffuellen.
// Vorher tat das nur der Hintergrundlauf alle sechs Stunden -- auf iOS eine
// Bitte, kein Versprechen.
//
// Geprueft wird hier die Mechanik drumherum, nicht das Einplanen selbst
// (das liegt im NotificationScheduler): Ruhezeit, Zusammenfassen paralleler
// Laeufe, und dass ein Fehlschlag den naechsten Lauf nicht aussperrt.

import 'package:flutter_test/flutter_test.dart';
import 'package:productivity/dataservice/erinnerungs_abgleich.dart';

void main() {
  setUp(ErinnerungsAbgleich.vergessen);

  test('ohne Anmeldung passiert nichts', () async {
    // Kein Token hinterlegt -> der Lauf bricht ab, bevor er etwas holt.
    // Ohne diese Bremse liefe nach dem Logout weiter ein Serverabruf.
    expect(await ErinnerungsAbgleich.jetzt(erzwingen: true), 0);
  });

  test('ein fehlgeschlagener Lauf sperrt den naechsten nicht aus', () async {
    // Der Merker wird erst NACH Erfolg gesetzt. Sonst haette ein Lauf ohne
    // Netz die Ruhezeit gestartet, ohne etwas eingeplant zu haben.
    await ErinnerungsAbgleich.jetzt(erzwingen: true);
    expect(ErinnerungsAbgleich.zuletzt, isNull);
  });

  test('zwei gleichzeitige Aufrufe ergeben einen Lauf', () async {
    // Zwei Laeufe nebeneinander kaemen sich beim Abraeumen und Neusetzen
    // in die Quere: der eine loescht, was der andere gerade angemeldet hat.
    final a = ErinnerungsAbgleich.jetzt(erzwingen: true);
    final b = ErinnerungsAbgleich.jetzt(erzwingen: true);
    expect(identical(a, b), isTrue);
    await Future.wait([a, b]);
  });

  test('die Ruhezeit ist kurz genug zum Ankommen, lang genug zum Sparen', () {
    // Wer zwischen zwei Apps hin- und herspringt, soll nicht im Minutentakt
    // Abfragen ausloesen -- ein eben angelegter Termin aber trotzdem
    // ankommen.
    expect(ErinnerungsAbgleich.ruhe, const Duration(minutes: 2));
  });
}
