// „Wer bist du?" -- wenn die Stimme niemandem zuzuordnen ist.
//
// Am Kuechentablet steht kein Konto vor dem Geraet, sondern ein Mensch.
// Drei Wege fuehren zu einem Sprecher: die Stimme, die Rueckfrage, der
// Name im Satz. Geprueft wird hier der zweite und dritte -- die beiden,
// die ohne Modell auskommen.
//
// Der Kern: **es wird nicht immer gefragt**. Wuerde Jarvis vor jedem Satz
// „wer bist du" fragen, waere die Sprachbedienung unbenutzbar.
import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:productivity/dataservice/sprecher_frage.dart';

void main() {
  group('Braucht der Satz ueberhaupt eine Person?', () {
    test('was steht bei mir an -- ja', () {
      expect(SprecherFrage.brauchtSprecher('Was steht bei mir an?'), isTrue);
    });

    test('meine Termine heute -- ja', () {
      expect(SprecherFrage.brauchtSprecher('Zeig meine Termine heute'), isTrue);
    });

    test('wie sieht mein Tag aus -- ja', () {
      expect(SprecherFrage.brauchtSprecher('Wie sieht mein Tag aus?'), isTrue);
    });

    test('stell einen Timer -- nein', () {
      // Der wichtigste Gegenfall. Eine Rueckfrage hier waere reine Plage.
      expect(SprecherFrage.brauchtSprecher('Stell einen Timer für fünf Minuten'),
          isFalse);
    });

    test('stell mir einen Timer -- auch nein', () {
      // Selbstbezug allein reicht nicht: die Antwort ist fuer jeden dieselbe.
      expect(SprecherFrage.brauchtSprecher('Stell mir einen Timer'), isFalse);
    });

    test('Milch auf die Einkaufsliste -- nein', () {
      expect(SprecherFrage.brauchtSprecher('Setz Milch auf die Einkaufsliste'),
          isFalse);
    });

    test('was steht bei Lisa an -- nein, da steht der Name schon drin', () {
      expect(SprecherFrage.brauchtSprecher('Was steht bei Lisa an?'), isFalse);
    });

    test('gemeinsam ist kein mein', () {
      // „mein" steckt in „gemeinsam" -- ganze Woerter, keine Teilstuecke.
      expect(SprecherFrage.brauchtSprecher('Gemeinsame Termine anzeigen'),
          isFalse);
    });

    test('ein leerer Satz braucht nichts', () {
      expect(SprecherFrage.brauchtSprecher(''), isFalse);
    });
  });

  group('Wer hat geantwortet?', () {
    const haushalt = ['Jan', 'Lisa', 'Max Meier'];

    test('nur der Name', () {
      expect(SprecherFrage.deute('Lisa', haushalt), 'Lisa');
    });

    test('ich bin Lisa', () {
      expect(SprecherFrage.deute('Ich bin Lisa', haushalt), 'Lisa');
    });

    test('hier ist Jan', () {
      expect(SprecherFrage.deute('Hier ist Jan', haushalt), 'Jan');
    });

    test('mein Name ist Lisa', () {
      expect(SprecherFrage.deute('Mein Name ist Lisa', haushalt), 'Lisa');
    });

    test('ein zweiteiliger Name wird ganz erkannt', () {
      expect(SprecherFrage.deute('Ich bin Max Meier', haushalt), 'Max Meier');
    });

    test('der Vorname allein reicht, wenn er eindeutig ist', () {
      expect(SprecherFrage.deute('Max', haushalt), 'Max Meier');
    });

    test('Gross- und Kleinschreibung ist egal', () {
      expect(SprecherFrage.deute('lisa', haushalt), 'Lisa');
    });

    test('die Schreibweise aus dem Haushalt kommt zurueck', () {
      // Damit der Name so weitergereicht wird, wie ihn der Server kennt.
      expect(SprecherFrage.deute('LISA', haushalt), 'Lisa');
    });

    test('ein unbekannter Name gibt nichts', () {
      expect(SprecherFrage.deute('Ich bin Mareike', haushalt), isNull);
    });

    test('gar keine Antwort gibt nichts', () {
      expect(SprecherFrage.deute('', haushalt), isNull);
    });

    test('eine Antwort ohne Namen gibt nichts', () {
      expect(SprecherFrage.deute('Ich bin hier', haushalt), isNull);
    });

    test('zwei gleiche Vornamen: lieber nichts als geraten', () {
      // Wie ueberall hier -- bei zwei Kandidaten wird nicht der erste
      // genommen. Ein falsch zugeordneter Kalender ist schlimmer als eine
      // zweite Nachfrage.
      const zwei = ['Lisa Meier', 'Lisa Schmidt'];
      expect(SprecherFrage.deute('Lisa', zwei), isNull);
    });

    test('mit vollem Namen wird auch bei zwei Lisas klar, wer gemeint ist', () {
      const zwei = ['Lisa Meier', 'Lisa Schmidt'];
      expect(SprecherFrage.deute('Ich bin Lisa Schmidt', zwei), 'Lisa Schmidt');
    });

    test('ein leerer Haushalt gibt nichts', () {
      expect(SprecherFrage.deute('Lisa', const []), isNull);
    });
  });

  group('Wie lange Jarvis sich den Sprecher merkt', () {
    // Am Kuechentablet stellt man nicht eine Frage, sondern drei. Muesste
    // Jarvis vor jeder „wer bist du" fragen, waere die Rueckfrage
    // schlimmer als das Problem.
    test('frisch gemerkt ist er da', () {
      final g = Sprechergedaechtnis()..merken('Lisa');
      expect(g.name, 'Lisa');
    });

    test('ohne etwas gemerkt zu haben: niemand', () {
      expect(Sprechergedaechtnis().name, isNull);
    });

    test('nach neun Minuten gilt er noch', () {
      final start = DateTime(2026, 9, 14, 12);
      final g = Sprechergedaechtnis();
      withClock(Clock.fixed(start), () => g.merken('Lisa'));
      withClock(Clock.fixed(start.add(const Duration(minutes: 9))),
          () => expect(g.name, 'Lisa'));
    });

    test('nach elf Minuten ist er vergessen', () {
      // Der eigentliche Test. Sonst wuerde am naechsten Morgen noch
      // derselbe Sprecher angenommen -- und der falsche Kalender
      // vorgelesen.
      final start = DateTime(2026, 9, 14, 12);
      final g = Sprechergedaechtnis();
      withClock(Clock.fixed(start), () => g.merken('Lisa'));
      withClock(Clock.fixed(start.add(const Duration(minutes: 11))),
          () => expect(g.name, isNull));
    });

    test('dieselben zehn Minuten wie beim Auswahlgedaechtnis', () {
      expect(Sprechergedaechtnis.gueltig, const Duration(minutes: 10));
    });

    test('vergessen wirkt sofort', () {
      final g = Sprechergedaechtnis()..merken('Lisa');
      g.vergessen();
      expect(g.name, isNull);
    });
  });

  group('Was Jarvis sagt', () {
    test('die Rueckfrage ist kurz', () {
      expect(SprecherFrage.frage, 'Wer bist du?');
    });

    test('die Fehlermeldung sagt, was der Nutzer tun kann', () {
      // Nicht nur „ging nicht" -- sonst steht er ratlos vor dem Geraet.
      expect(SprecherFrage.nichtGefunden, contains('bitte sage den Satz nochmal'));
      expect(SprecherFrage.nichtGefunden, contains('Benutzernamen'));
    });
  });
}
