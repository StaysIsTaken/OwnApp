/// „Wer bist du?" — wenn die Stimme niemandem zuzuordnen ist.
///
/// Am Küchentablet steht kein Konto vor dem Gerät, sondern ein Mensch.
/// „Was steht bei mir an" hat deshalb ohne einen Sprecher keine Antwort.
/// Drei Wege führen zu einem:
///
/// 1. **Die Stimme** — erkannt, ohne dass jemand etwas tut.
/// 2. **Die Rückfrage** — erkennt sie niemanden, fragt Jarvis einmal nach.
/// 3. **Der Name im Satz** — hilft auch das nicht, sagt er, wie es geht:
///    „bitte sage den Satz nochmal mit dem jeweiligen Kalender-Benutzernamen".
///
/// ## Warum nicht einfach immer fragen
///
/// Weil die meisten Sätze keinen Sprecher brauchen. „Stell einen Timer für
/// fünf Minuten" ist für jeden dasselbe; würde Jarvis davor „wer bist du"
/// fragen, wäre die Sprachbedienung unbenutzbar. Gefragt wird nur, wenn
/// der Satz sich auf eine Person bezieht — siehe [brauchtSprecher].
library;

import 'package:clock/clock.dart';

class SprecherFrage {
  SprecherFrage._();

  /// Wörter, mit denen sich ein Satz auf den Sprecher selbst bezieht.
  ///
  /// Ganze Wörter, keine Teilzeichenketten: „mein" steckt in „meinen",
  /// aber auch in „gemeinsam" und „Gemeinde".
  static const Set<String> _selbstbezug = {
    'mir', 'mich', 'mein', 'meine', 'meinen', 'meinem', 'meiner', 'meins',
    'ich',
  };

  /// Wörter, die einen Satz erst persönlich machen.
  ///
  /// „Ich hätte gern einen Timer" bezieht sich zwar auf mich, aber die
  /// Antwort ist für jeden dieselbe. Erst zusammen mit einem dieser
  /// Bereiche wird die Person zur Frage.
  static const Set<String> _persoenlich = {
    'termin', 'termine', 'terminen', 'kalender', 'agenda', 'tag',
    'aufgabe', 'aufgaben', 'woche', 'ansteht', 'ansteh', 'anstehen',
    'plan', 'planung', 'journal', 'zeiten', 'zeiterfassung',
    // „Was steht bei mir an" trägt kein Bereichswort und ist trotzdem die
    // häufigste Terminfrage überhaupt. „steht" fängt sie ein, ohne
    // „stell einen Timer" mitzunehmen – das heißt „stell", nicht „steht".
    'steht', 'stehen',
  };

  static Set<String> _woerter(String roh) => roh
      .toLowerCase()
      .split(RegExp(r'[^a-zäöüß]+'))
      .where((w) => w.isNotEmpty)
      .toSet();

  /// Braucht dieser Satz eine Person, um beantwortbar zu sein?
  ///
  /// Beides muss zutreffen: ein Selbstbezug **und** ein persönlicher
  /// Bereich. „Was steht bei mir an" ja, „stell mir einen Timer" nein.
  static bool brauchtSprecher(String text) {
    final w = _woerter(text);
    return w.any(_selbstbezug.contains) && w.any(_persoenlich.contains);
  }

  /// Die Frage, die Jarvis stellt, wenn er die Stimme nicht zuordnen kann.
  static const String frage = 'Wer bist du?';

  /// Was er sagt, wenn auch die Antwort zu niemandem passt.
  ///
  /// Wortlaut mit Absicht: er sagt nicht nur, dass es nicht ging, sondern
  /// **was der Nutzer stattdessen tun kann**. „Ich habe dich nicht
  /// verstanden" allein ließe ihn ratlos vor dem Gerät stehen.
  static const String nichtGefunden =
      'Ich konnte nichts finden, bitte sage den Satz nochmal mit dem '
      'jeweiligen Kalender-Benutzernamen.';

  /// Deutet eine Antwort auf [frage] als Person.
  ///
  /// [bekannt] sind die Anzeigenamen der Personen im Haushalt. Gesucht
  /// wird unter ihnen, statt aus dem Satz einen Namen zu raten: wer nicht
  /// im Haushalt ist, hat auch keinen Kalender, und ein geratener Name
  /// führte zu „Niemanden namens Möhre gefunden".
  ///
  /// Gibt den **Namen wie in [bekannt] geschrieben** zurück, oder null.
  static String? deute(String antwort, List<String> bekannt) {
    final gesagt = _woerter(antwort);
    if (gesagt.isEmpty) return null;

    // Erst der ganze Satz gegen den ganzen Namen: „Lisa Meier" besteht aus
    // zwei Wörtern und ginge bei einer reinen Wortsuche verloren.
    final satz = antwort.toLowerCase().trim();
    for (final name in bekannt) {
      if (satz == name.toLowerCase()) return name;
    }
    for (final name in bekannt) {
      if (satz.contains(name.toLowerCase())) return name;
    }

    // Dann Wort für Wort — der Vorname reicht, wenn er eindeutig ist.
    //
    // Einleitungen wie „ich bin" werden NICHT herausgefiltert. Eine solche
    // Liste hatte hier gestanden, und die Gegenprobe zeigte: sie ändert an
    // keinem einzigen Fall etwas. Gesucht wird ohnehin nur unter den Namen
    // des Haushalts, und „bin" ist keiner.
    final treffer = <String>{};
    for (final name in bekannt) {
      for (final teil in _woerter(name)) {
        if (gesagt.contains(teil)) treffer.add(name);
      }
    }

    // Zwei Lisas im Haushalt: dann ist der Vorname keine Antwort. Nicht
    // raten — wie überall hier.
    return treffer.length == 1 ? treffer.first : null;
  }
}

/// Wer gerade spricht — für eine Weile gemerkt.
///
/// Am Küchentablet stellt man nicht eine Frage, sondern drei: „was steht
/// bei mir an", dann „und morgen?", dann „trag das ein". Müsste Jarvis vor
/// jeder davon „wer bist du" fragen, wäre die Rückfrage schlimmer als das
/// Problem.
///
/// Dieselben zehn Minuten wie beim Auswahlgedächtnis, und aus demselben
/// Grund: man ruft quer durch den Raum, geht etwas holen, kommt zurück.
class Sprechergedaechtnis {
  static const Duration gueltig = Duration(minutes: 10);

  String? _name;
  DateTime? _seit;

  /// Wer gerade spricht — null, wenn unbekannt oder zu lange her.
  String? get name {
    final seit = _seit;
    if (seit == null || clock.now().difference(seit) > gueltig) return null;
    return _name;
  }

  void merken(String name) {
    _name = name;
    _seit = clock.now();
  }

  /// Vergisst den Sprecher — etwa wenn jemand anderes das Gerät benutzt.
  void vergessen() {
    _name = null;
    _seit = null;
  }
}
