import 'package:productivity/dataclasses/haushalt.dart';

/// Welcher Ausschnitt gerade gezeigt wird.
///
/// Drei Werte und nicht zwei: **[alles] ist die Vorgabe**, und das ist
/// Absicht. Wer die App aufmacht, will sehen, was da ist — nicht erst
/// entscheiden, in welcher Hälfte er sucht. Die Umschaltung ist ein
/// Filter, kein Modus.
enum Bereich {
  alles('Alles'),
  meins('Meins'),
  unseres('Unseres');

  const Bereich(this.titel);

  final String titel;

  /// Was an die Abfrage gehängt wird. Für [alles] nichts — der Server
  /// liefert dann, was man überhaupt sehen darf.
  Map<String, dynamic> get abfrage => switch (this) {
        Bereich.alles => const {},
        Bereich.meins => const {'eigene': true},
        Bereich.unseres => const {'unseres': true},
      };

  /// Gehört etwas, das gerade angelegt wird, dem Haushalt?
  ///
  /// Auf „Unseres" ja — wer dort etwas anlegt, meint den Haushalt. Auf
  /// „Alles" und „Meins" nein: im Zweifel persönlich, denn das lässt
  /// sich hinterher teilen, während sich Geteiltes nicht ungesehen
  /// machen lässt.
  bool get legtFuerHaushaltAn => this == Bereich.unseres;
}

/// Die Sichtbarkeitsregel der Haushalte — als reine Rechnung.
///
/// Sie steht hier und nicht in den Seiten, aus demselben Grund wie
/// `finanz_rechnung.dart`: eine Seite, die beim Aufbau lädt, lässt sich
/// nicht prüfen, die Regel dahinter schon. Und diese Regel ist es wert:
/// **an ihr hängt das Leitprinzip.** Vergisst eine Seite sie, erscheint
/// bei jemandem ohne Haushalt eine Umschaltung zwischen „Meins" und
/// „Unserem", die ins Leere zeigt.
class Haushaltssicht {
  Haushaltssicht._();

  /// Gibt es im Menü überhaupt etwas zum Haushalt?
  ///
  /// Nur wer in einem ist oder gefragt wurde, ob er hinein möchte.
  /// **Sonst nicht** — kein leerer Abschnitt, kein ausgegrauter
  /// Menüpunkt, keine Erklärung, warum hier nichts steht.
  ///
  /// Eine offene Einladung zählt mit, sonst käme sie nirgends an: sie
  /// wird beim Öffnen der App geholt, und ohne Menüpunkt gäbe es keinen
  /// Ort, an dem man sie beantworten könnte.
  static bool zeigtMenue({Haushalt? haushalt, int offeneEinladungen = 0}) =>
      haushalt != null || offeneEinladungen > 0;

  /// Gibt es auf einer Modulseite die Umschaltung „Meins / Unseres"?
  ///
  /// Nur im Haushalt. Das ist das Leitprinzip in einer Zeile — und die
  /// Stelle, an der es kaputtgeht, wenn jemand sie vergisst. Eine offene
  /// Einladung reicht hier ausdrücklich **nicht**: solange sie offen ist,
  /// gibt es kein „unseres".
  static bool zeigtUmschaltung(Haushalt? haushalt) => haushalt != null;

  /// Was in der Mitgliederzeile steht.
  static String mitgliederSatz(Haushalt haushalt) {
    final n = haushalt.mitglieder.length;
    return n == 1 ? 'Nur du' : '$n Mitglieder';
  }

  /// Darf diese Person den Haushalt verlassen?
  ///
  /// Der Besitzer kann nicht gehen, solange andere drin sind — er
  /// übergibt erst. Der Server sagt dasselbe; hier steht es, damit der
  /// Knopf gar nicht erst anbietet, was hinterher abgelehnt wird.
  static bool darfGehen(Haushalt haushalt, String userId) {
    if (!haushalt.gehoert(userId)) return true;
    return haushalt.mitglieder.length <= 1;
  }

  /// „2 von 3 Mitgliedern rechnen mit."
  ///
  /// **Der wichtigste Satz der Finanzübersicht.** Ohne ihn hält jemand
  /// eine unvollständige Summe für die Wahrheit — derselbe Gedanke wie
  /// bei `ohne_preis` und `ohne_zutat`: lieber ehrlich sagen, was nicht
  /// verrechnet werden konnte, als eine Zahl zeigen, die vollständig
  /// aussieht.
  ///
  /// Rechnen alle mit, gibt es nichts zu sagen — dann ist der Satz leer,
  /// und die Seite zeigt keine Zeile. Eine Beruhigung („alle rechnen
  /// mit") wäre eine Zeile, die man nach dem dritten Mal nicht mehr
  /// liest, und dann übersieht man auch die Warnung.
  static String mitrechnenSatz(HaushaltsFinanzen finanzen) {
    if (!finanzen.unvollstaendig) return '';
    final fehlen = finanzen.fehlende;
    final wer = fehlen.length == 1
        ? '${fehlen.first} zeigt seine Zahlen nicht.'
        : '${fehlen.join(', ')} zeigen ihre Zahlen nicht.';
    return '${finanzen.rechnenMit} von ${finanzen.mitgliederGesamt} '
        'Mitgliedern rechnen mit — $wer';
  }

  /// „2 von 3 geben frei" — oder ein leerer String, wenn alle es tun.
  ///
  /// Derselbe Gedanke wie [mitrechnenSatz]: was ein Assistent aus dem
  /// Haushalt bekommt, ist unvollständig, sobald jemand nicht freigibt.
  /// Das gehört dazugesagt — sonst hält jemand eine halbe Liste für die
  /// ganze.
  static String freigabeSatz(List<Mitglied> mitglieder) {
    if (mitglieder.isEmpty) return '';
    final frei = mitglieder.where((m) => m.mcpFreigabe).toList();
    if (frei.length == mitglieder.length) {
      return 'Alle geben ihre Beiträge frei.';
    }
    if (frei.isEmpty) {
      return 'Niemand gibt frei — aus dem Haushalt geht nichts heraus.';
    }
    final fehlen = mitglieder
        .where((m) => !m.mcpFreigabe)
        .map((m) => m.name)
        .toList();
    final wer = fehlen.length == 1
        ? '${fehlen.first} gibt nicht frei.'
        : '${fehlen.join(', ')} geben nicht frei.';
    return '${frei.length} von ${mitglieder.length} geben frei — $wer';
  }

  /// Der Satz, der erklärt, warum der Knopf nicht geht.
  static const String warumNichtGehen =
      'Du führst diesen Haushalt. Übergib ihn erst an jemand anderen.';
}
