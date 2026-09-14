// Was beim Tippen auf eine Mitteilung passiert.
//
// Die Mitteilung trug seit jeher einen payload wie `planner:42` -- nur
// wertete ihn niemand aus: `_handleNotificationTap` war eine leere Attrappe
// mit dem Kommentar „could be used for routing".
//
// Zwei Dinge pruefen hier mehrere Tests besonders:
//
// 1. **Fremde Praefixe fuehren nirgendwohin.** Vorrats- und Chat-Hinweise
//    tragen eigene; sie duerfen nicht versehentlich im Kalender landen.
// 2. **Ein abgeholtes Ziel ist weg.** Sonst spraenge die App bei jedem
//    Neuzeichnen wieder auf denselben Termin.

import 'package:flutter_test/flutter_test.dart';
import 'package:productivity/dataservice/mitteilungs_ziel.dart';

void main() {
  setUp(() {
    // Der Merker ist statisch -- ohne Leeren traegt ein Test den Stand des
    // vorigen mit.
    MitteilungsZiel.abholen();
    MitteilungsZiel.beiNeuemZiel = null;
  });

  group('Den payload lesen', () {
    test('ein Termin', () {
      expect(MitteilungsZiel.terminAus('planner:42'), 42);
    });

    test('Vorrat und Chat fuehren nirgendwohin', () {
      // Sonst landete ein Vorratshinweis im Kalender.
      expect(MitteilungsZiel.terminAus('pantry:expiring'), isNull);
      expect(MitteilungsZiel.terminAus('chat:abc-123'), isNull);
      // Der gefaehrliche Fall: ein fremdes Praefix mit einer Zahl dahinter.
      // Wer nur „alles hinter dem Doppelpunkt" liest, oeffnet hier den
      // Termin 42 -- und der hat mit der Mitteilung nichts zu tun.
      expect(MitteilungsZiel.terminAus('chat:42'), isNull);
      expect(MitteilungsZiel.terminAus('pantry:7'), isNull);
    });

    test('ohne payload nichts', () {
      expect(MitteilungsZiel.terminAus(null), isNull);
      expect(MitteilungsZiel.terminAus(''), isNull);
    });

    test('kaputte Nummer ergibt kein Ziel', () {
      // Lieber nichts tun als auf Termin 0 springen.
      expect(MitteilungsZiel.terminAus('planner:abc'), isNull);
      expect(MitteilungsZiel.terminAus('planner:'), isNull);
    });
  });

  group('Merken und abholen', () {
    test('was gemerkt wurde, kommt zurueck', () {
      MitteilungsZiel.merken('planner:7');
      expect(MitteilungsZiel.abholen(), 'planner:7');
    });

    test('abholen vergisst', () {
      // Sonst spraenge die App bei jedem Neuzeichnen wieder dorthin.
      MitteilungsZiel.merken('planner:7');
      MitteilungsZiel.abholen();
      expect(MitteilungsZiel.abholen(), isNull);
    });

    test('leeres wird nicht gemerkt', () {
      MitteilungsZiel.merken(null);
      MitteilungsZiel.merken('');
      expect(MitteilungsZiel.abholen(), isNull);
    });

    test('das juengste Ziel gewinnt', () {
      // Zwei Mitteilungen kurz hintereinander: die zuletzt angetippte ist
      // gemeint.
      MitteilungsZiel.merken('planner:1');
      MitteilungsZiel.merken('planner:2');
      expect(MitteilungsZiel.abholen(), 'planner:2');
    });
  });

  group('Der Anstoss', () {
    test('meldet, wenn ein Ziel eintrifft', () {
      // Ohne den Haken laege das Ziel bis zum naechsten Neuzeichnen herum --
      // und wer aus dem Hintergrund zurueckkommt, zeichnet nicht unbedingt
      // neu.
      var gerufen = 0;
      MitteilungsZiel.beiNeuemZiel = () => gerufen++;
      MitteilungsZiel.anstossen();
      expect(gerufen, 1);
    });

    test('ohne Haken passiert nichts', () {
      MitteilungsZiel.beiNeuemZiel = null;
      expect(MitteilungsZiel.anstossen, returnsNormally);
    });
  });
}
