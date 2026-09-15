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

  /// Der Satz, der erklärt, warum der Knopf nicht geht.
  static const String warumNichtGehen =
      'Du führst diesen Haushalt. Übergib ihn erst an jemand anderen.';
}
