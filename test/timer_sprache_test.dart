// „Jarvis, stell einen Timer für fünf Minuten."
//
// Drei Dinge werden hier geprueft, und das dritte ist der eigentliche Grund
// fuer den ganzen Umbau:
//
// 1. Der Satz wird verstanden — auch mit gesprochenen Zahlen, denn Whisper
//    schreibt „fuenf" so oft wie „5".
// 2. Es wird nur erkannt, was wirklich ein Timer-Befehl ist. Ein zu
//    gieriger Parser faengt Saetze ab, die ans Modell gehoert haetten.
// 3. Der Timer laeuft im Provider und damit weiter, waehrend die Uhrkachel
//    gar nicht zu sehen ist. Vorher sass er im Widget-State und stand still,
//    sobald man weiterblaetterte.

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:productivity/dataservice/timer_befehle.dart';
import 'package:productivity/dataservice/timer_ton.dart';
import 'package:productivity/provider/timer_provider.dart';

void main() {
  setUp(() {
    TimerTon.stumm = true;
    TimerTon.gespielt = 0;
  });

  group('Dauer heraushoeren', () {
    test('Ziffern und Minuten', () {
      expect(TimerBefehle.dauerAus('timer für 5 minuten'),
          const Duration(minutes: 5));
    });

    test('gesprochene Zahlen', () {
      // Whisper schreibt nicht zuverlaessig Ziffern.
      expect(TimerBefehle.dauerAus('timer für fünf minuten'),
          const Duration(minutes: 5));
      expect(TimerBefehle.dauerAus('timer auf zwanzig minuten'),
          const Duration(minutes: 20));
    });

    test('zusammengesetzte Zahlwoerter bleiben ganz', () {
      // „fünf" steckt in „fünfundvierzig". Dass das gutgeht, liegt an der
      // geforderten Einheit dahinter, nicht an der Sortierung — die
      // Gegenprobe ohne Sortierung blieb gruen.
      expect(TimerBefehle.dauerAus('timer fünfundvierzig minuten'),
          const Duration(minutes: 45));
    });

    test('Stunden', () {
      expect(TimerBefehle.dauerAus('timer für 2 stunden'),
          const Duration(hours: 2));
    });

    test('Sekunden', () {
      expect(TimerBefehle.dauerAus('timer 90 sekunden'),
          const Duration(seconds: 90));
    });

    test('mehrere Angaben werden addiert', () {
      // Sonst fiele „eine Stunde und zwanzig Minuten" auf die Stunde
      // zusammen.
      expect(TimerBefehle.dauerAus('timer auf eine stunde und zwanzig minuten'),
          const Duration(hours: 1, minutes: 20));
    });

    test('Kommazahlen', () {
      expect(TimerBefehle.dauerAus('timer 1,5 stunden'),
          const Duration(minutes: 90));
    });

    test('feste Wendungen', () {
      expect(TimerBefehle.dauerAus('timer auf eine halbe stunde'),
          const Duration(minutes: 30));
      expect(TimerBefehle.dauerAus('timer für eine viertelstunde'),
          const Duration(minutes: 15));
      expect(TimerBefehle.dauerAus('timer auf anderthalb stunden'),
          const Duration(minutes: 90));
    });

    test('dreiviertelstunde schlaegt viertelstunde', () {
      // Die eine enthaelt die andere als Zeichenkette.
      expect(TimerBefehle.dauerAus('timer dreiviertelstunde'),
          const Duration(minutes: 45));
    });

    test('ohne Einheit keine Dauer', () {
      expect(TimerBefehle.dauerAus('timer auf 5'), isNull);
    });

    test('null ist keine Dauer', () {
      expect(TimerBefehle.dauerAus('timer auf 0 minuten'), isNull);
    });
  });

  group('Befehl erkennen', () {
    test('stellen mit Dauer', () {
      final b = TimerBefehle.erkenne('Jarvis, stelle einen Timer für 5 Minuten');
      expect(b, const Timerbefehl(Timeraktion.stellen,
          dauer: Duration(minutes: 5)));
    });

    test('die Eieruhr zaehlt auch', () {
      expect(TimerBefehle.erkenne('stell die eieruhr auf 3 minuten')?.aktion,
          Timeraktion.stellen);
    });

    test('anhalten', () {
      expect(TimerBefehle.erkenne('stopp den timer')?.aktion,
          Timeraktion.pausieren);
      expect(TimerBefehle.erkenne('halt den timer an')?.aktion,
          Timeraktion.pausieren);
    });

    test('zuruecksetzen', () {
      expect(TimerBefehle.erkenne('timer abbrechen')?.aktion,
          Timeraktion.zuruecksetzen);
    });

    test('weiterlaufen lassen', () {
      expect(TimerBefehle.erkenne('timer weiter')?.aktion, Timeraktion.starten);
    });

    test('nach der Restzeit fragen', () {
      expect(TimerBefehle.erkenne('wie lange läuft der timer noch')?.aktion,
          Timeraktion.restfrage);
    });

    test('eine Dauer schlaegt jedes andere Wort', () {
      // „stell den Timer auf 3 Minuten" enthaelt kein Stopp-Wort, aber
      // „starte einen Timer für 3 Minuten" enthaelt „start" — und meint
      // trotzdem eine neue Dauer.
      final b = TimerBefehle.erkenne('starte einen timer für 3 minuten');
      expect(b?.aktion, Timeraktion.stellen);
      expect(b?.dauer, const Duration(minutes: 3));
    });

    test('ohne das Wort Timer wird nichts erkannt', () {
      // Sonst faenge „wie lange noch" jeden Satz ab, der ans Modell gehoert.
      expect(TimerBefehle.erkenne('wie lange noch'), isNull);
      expect(TimerBefehle.erkenne('stell das mal ab'), isNull);
    });

    test('Timer ohne erkennbare Absicht geht ans Modell', () {
      expect(TimerBefehle.erkenne('was ist ein timer'), isNull);
    });

    test('ein Navigationsbefehl bleibt einer', () {
      // „zeig mir den Timer" ist ein Seitenwechsel, kein Stellen.
      expect(TimerBefehle.erkenne('zeig mir den timer'), isNull);
    });
  });

  group('Gesprochene Dauer', () {
    test('Einzahl bekommt ihre eigene Form', () {
      // „1 Minuten" verraet die Maschine deutlicher als jede Stimme.
      expect(dauerSprache(const Duration(minutes: 1)), 'eine Minute');
      expect(dauerSprache(const Duration(hours: 1)), 'eine Stunde');
    });

    test('Mehrzahl', () {
      expect(dauerSprache(const Duration(minutes: 5)), '5 Minuten');
    });

    test('zusammengesetzt', () {
      expect(dauerSprache(const Duration(hours: 1, minutes: 20)),
          'eine Stunde und 20 Minuten');
    });

    test('glatte Minuten nennen keine Sekunden', () {
      // „fuenf Minuten und null Sekunden" sagt niemand.
      expect(dauerSprache(const Duration(minutes: 5)), isNot(contains('Sekunde')));
    });

    test('krumme Zeit nennt alle drei Teile', () {
      expect(dauerSprache(const Duration(hours: 1, minutes: 2, seconds: 3)),
          'eine Stunde, 2 Minuten und 3 Sekunden');
    });
  });

  group('Der Timer im Provider', () {
    test('stellen und starten in einem', () {
      final t = TimerProvider();
      addTearDown(t.dispose);

      t.stelleUndStarte(const Duration(minutes: 5));
      expect(t.laeuft, isTrue);
      expect(t.rest, const Duration(minutes: 5));
      expect(t.gestellt, const Duration(minutes: 5));
    });

    test('laeuft weiter, ohne dass eine Kachel zusieht', () {
      fakeAsync((async) {
        final t = TimerProvider();
        t.stelleUndStarte(const Duration(minutes: 1));
        async.elapse(const Duration(seconds: 10));
        // Genau das ging vorher nicht: der Takt sass im Widget.
        expect(t.rest, const Duration(seconds: 50));
        t.dispose();
      });
    });

    test('klingelt beim Ablaufen genau einmal', () {
      fakeAsync((async) {
        final t = TimerProvider();
        t.stelleUndStarte(const Duration(seconds: 3));
        async.elapse(const Duration(seconds: 3));
        expect(TimerTon.gespielt, 1);
        expect(t.abgelaufen, isTrue);

        async.elapse(const Duration(seconds: 10));
        expect(TimerTon.gespielt, 1);
        t.dispose();
      });
    });

    test('pausieren haelt die Restzeit fest', () {
      fakeAsync((async) {
        final t = TimerProvider();
        t.stelleUndStarte(const Duration(minutes: 1));
        async.elapse(const Duration(seconds: 20));
        t.pausieren();
        async.elapse(const Duration(seconds: 30));
        expect(t.rest, const Duration(seconds: 40));
        expect(t.laeuft, isFalse);
        t.dispose();
      });
    });

    test('zuruecksetzen stellt die gestellte Dauer wieder her', () {
      fakeAsync((async) {
        final t = TimerProvider();
        t.stelleUndStarte(const Duration(minutes: 3));
        async.elapse(const Duration(seconds: 30));
        t.zuruecksetzen();
        expect(t.rest, const Duration(minutes: 3));
        expect(t.laeuft, isFalse);
        t.dispose();
      });
    });

    test('null Sekunden stellen nichts', () {
      final t = TimerProvider();
      addTearDown(t.dispose);
      t.stelleUndStarte(Duration.zero);
      expect(t.laeuft, isFalse);
      expect(t.gestellt, TimerProvider.standard);
    });

    test('der Takt steht, solange nichts laeuft', () {
      fakeAsync((async) {
        final t = TimerProvider();
        var meldungen = 0;
        t.addListener(() => meldungen++);
        // Ein Wandtablet soll nicht im Leerlauf jede Sekunde neu zeichnen.
        async.elapse(const Duration(seconds: 30));
        expect(meldungen, 0);
        t.dispose();
      });
    });
  });
}
