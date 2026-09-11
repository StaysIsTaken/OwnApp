// Wann Jarvis nach seiner Antwort weiter zuhoert.
//
// Der Anlass: "In welchen Kalender soll ich es eintragen?" Darauf will man
// sofort antworten koennen und nicht erst wieder "Hey Jarvis" sagen muessen.
// Das ist kein Gespraech, das ist ein Formular.
//
// Die Gegenrichtung ist genauso wichtig: nach einem erledigten Auftrag darf
// das Mikrofon NICHT offen bleiben. "Eingetragen. Noch etwas?" ist
// Hoeflichkeit, keine Rueckfrage.
import 'package:flutter_test/flutter_test.dart';
import 'package:productivity/provider/sprach_provider.dart';

void main() {
  group('Rueckfrage erkennen', () {
    test('eine Frage, bei der nichts passiert ist', () {
      expect(
        SprachProvider.istRueckfrage(
          'In welchen Kalender soll ich es eintragen?',
          etwasGetan: false,
        ),
        isTrue,
      );
    });

    test('Fragezeichen mitten im Satz zaehlt nicht', () {
      // Nur das Ende entscheidet. "Wer? Ich habe es eingetragen." wartet
      // auf nichts.
      expect(
        SprachProvider.istRueckfrage(
          'Wer? Ich habe es eingetragen.',
          etwasGetan: false,
        ),
        isFalse,
      );
    });

    test('nachgestellte Leerzeichen stoeren nicht', () {
      expect(
        SprachProvider.istRueckfrage('Welcher Kalender?   ', etwasGetan: false),
        isTrue,
      );
    });

    test('eine Aussage ist keine Frage', () {
      expect(
        SprachProvider.istRueckfrage('Steht auf der Einkaufsliste.',
            etwasGetan: false),
        isFalse,
      );
    });
  });

  group('Wenn etwas passiert ist, wird nicht weiter gelauscht', () {
    test('auch nicht bei einer hoeflichen Schlussfrage', () {
      // Sonst bliebe das Mikrofon nach JEDEM Auftrag offen, nur weil das
      // Modell gern "Noch etwas?" anhaengt.
      expect(
        SprachProvider.istRueckfrage('Eingetragen. Noch etwas?',
            etwasGetan: true),
        isFalse,
      );
    });

    test('eine wartende Bestaetigung wartet auf einen Tipp, nicht auf ein Wort',
        () {
      expect(
        SprachProvider.istRueckfrage('Soll ich das wirklich loeschen?',
            etwasGetan: true),
        isFalse,
      );
    });
  });
}
