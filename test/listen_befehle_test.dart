// „Jarvis, lies mir die Einkaufsliste vor" -- und die Antwort auf die
// Rueckfrage danach.
//
// Beides gehoert zusammen: ohne Kurzgedaechtnis endet die Rueckfrage in
// einer Sackgasse, in der man den vollstaendigen Namen buchstabieren muss.
//
// Zwei Dinge pruefen hier mehrere Tests besonders:
//
// 1. **Der Parser ist nicht gierig.** „Setz Milch auf die Liste" enthaelt
//    das Wort Liste und ist trotzdem kein Vorlesen.
// 2. **Das Gedaechtnis ist kurzlebig.** Eine Auswahl, die eine
//    Viertelstunde spaeter noch gilt, beantwortet die falsche Frage.

import 'package:flutter_test/flutter_test.dart';
import 'package:productivity/dataservice/listen_befehle.dart';

void main() {
  group('Vorlesen erkennen', () {
    test('die uebliche Bitte', () {
      expect(ListenBefehle.istVorlesen('Jarvis, lies mir die Einkaufsliste vor'),
          isTrue);
    });

    test('auch ohne Verb-Vorsilbe', () {
      expect(ListenBefehle.istVorlesen('was steht auf der einkaufsliste'),
          isTrue);
      expect(ListenBefehle.istVorlesen('sag mir was auf dem zettel steht'),
          isTrue);
    });

    test('Hinzufuegen ist kein Vorlesen', () {
      // Der gefaehrliche Fall: der Satz enthaelt „Liste". Ein gieriger
      // Parser laese hier vor, statt Milch einzutragen.
      expect(ListenBefehle.istVorlesen('setz Milch auf die Liste'), isFalse);
      expect(ListenBefehle.istVorlesen('schreib Butter auf den zettel'),
          isFalse);
      expect(ListenBefehle.istVorlesen('streich die Milch von der Liste'),
          isFalse);
    });

    test('ohne das Wort Liste passiert nichts', () {
      // Sonst faenge „lies mir die Nachrichten vor" hier an.
      expect(ListenBefehle.istVorlesen('lies mir die nachrichten vor'),
          isFalse);
    });

    test('ohne Lese-Verb ebenfalls nicht', () {
      expect(ListenBefehle.istVorlesen('die einkaufsliste'), isFalse);
    });
  });

  group('Die Auswahl deuten', () {
    final namen = ['Wocheneinkauf', 'Baumarkt', 'Getränke'];

    test('ueber den Namen', () {
      expect(ListenBefehle.auswahlAus('die vom Baumarkt', namen), 1);
      expect(ListenBefehle.auswahlAus('Baumarkt', namen), 1);
    });

    test('ueber die Ordnungszahl', () {
      expect(ListenBefehle.auswahlAus('die zweite', namen), 1);
      expect(ListenBefehle.auswahlAus('die dritte bitte', namen), 2);
    });

    test('die letzte', () {
      // Bei zwei Listen sagt man eher „die letzte" als „die zweite".
      expect(ListenBefehle.auswahlAus('die letzte', namen), 2);
    });

    test('eine blanke Ziffer', () {
      expect(ListenBefehle.auswahlAus('die 2', namen), 1);
    });

    test('der Name schlaegt die Ordnungszahl', () {
      // „Die erste vom Baumarkt" meint den Baumarkt, nicht Platz eins.
      expect(ListenBefehle.auswahlAus('die erste vom Baumarkt', namen), 1);
    });

    test('eine Zahl jenseits der Auswahl zaehlt nicht', () {
      expect(ListenBefehle.auswahlAus('die fünfte', namen), isNull);
      expect(ListenBefehle.auswahlAus('die 9', namen), isNull);
    });

    test('ein fremder Satz ist keine Antwort', () {
      expect(ListenBefehle.auswahlAus('wie spät ist es', namen), isNull);
    });

    test('ohne Auswahl gibt es nichts zu deuten', () {
      expect(ListenBefehle.auswahlAus('die zweite', const []), isNull);
    });
  });

  group('Das Kurzgedaechtnis', () {
    test('merkt und loest auf', () {
      final g = Listengedaechtnis()..merken(['Wocheneinkauf', 'Baumarkt']);
      expect(g.aufloesen('die zweite'), 'Baumarkt');
    });

    test('ohne Gemerktes loest es nichts auf', () {
      // Sonst deutete jedes „die zweite" irgendetwas.
      expect(Listengedaechtnis().aufloesen('die zweite'), isNull);
    });

    test('vergessen raeumt es weg', () {
      final g = Listengedaechtnis()..merken(['A', 'B']);
      g.vergessen();
      expect(g.offen, isEmpty);
      expect(g.aufloesen('die erste'), isNull);
    });

    test('die Gueltigkeit ist kurz', () {
      // Wer zehn Minuten spaeter „die zweite" sagt, meint etwas anderes.
      expect(Listengedaechtnis.gueltig, const Duration(minutes: 2));
    });

    test('die Reihenfolge bleibt, wie vorgelesen wurde', () {
      // Die Ordnungszahl bezieht sich genau darauf.
      final g = Listengedaechtnis()..merken(['Zuerst', 'Danach']);
      expect(g.offen, ['Zuerst', 'Danach']);
      expect(g.aufloesen('die erste'), 'Zuerst');
    });
  });
}
