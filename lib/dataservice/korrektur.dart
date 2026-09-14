/// „Nein, 16 Uhr." — nachbessern, ohne von vorn anzufangen.
///
/// Jarvis sagt, was er getan hat; danach bleibt das Mikrofon zehn Sekunden
/// offen. Das ist die **Bremse**: in dieser Zeit wird nicht auf alles
/// reagiert, sondern nur auf Sätze, die wie eine Korrektur aussehen. Ein
/// Küchentablet, das nach jeder Aktion zehn Sekunden lang jeden Halbsatz
/// aus dem Raum annimmt, wäre eine Zumutung — und in einer Küche mit Radio
/// und Gesprächen fängt es genug davon.
///
/// Alles andere fällt durch und geht den normalen Weg. Wer statt zu
/// korrigieren etwas Neues zuruft, wird nicht aufgehalten.
library;

enum Korrekturart {
  /// „Nimm das zurück", „lösch das wieder" — die Aktion soll weg.
  ruecknahme,

  /// „Nein, 16 Uhr" — es soll etwas anderes daraus werden. Was, entscheidet
  /// das Sprachmodell; es hat den Verlauf und weiß, was eben geschah.
  nachbesserung,
}

class Korrekturbefehle {
  Korrekturbefehle._();

  /// Wie lange nach einer Aktion zugehört wird.
  ///
  /// Zehn Sekunden. Lang genug, um „nein, halb elf" hinterherzuschieben,
  /// kurz genug, dass es keine weiteren Zurufe blockiert.
  static const Duration fenster = Duration(seconds: 10);

  /// Wörter, die die Aktion ganz weghaben wollen.
  static const List<String> _weg = [
    'zurücknehmen', 'zuruecknehmen', 'nimm das zurück', 'nimm das zurueck',
    'rückgängig', 'rueckgaengig', 'lösch das wieder', 'loesch das wieder',
    'lösch das', 'loesch das', 'weg damit', 'doch nicht', 'vergiss das',
    'streich das', 'mach das weg',
  ];

  /// Wörter, an denen eine Nachbesserung zu erkennen ist.
  ///
  /// Bewusst eng. Jedes zusätzliche Wort hier ist ein Satz mehr, der in
  /// diesen zehn Sekunden abgefangen wird, obwohl er gar nicht an Jarvis
  /// gerichtet war.
  static const List<String> _anders = [
    'nein', 'falsch', 'ich meinte', 'ich meine', 'nicht ', 'stattdessen',
    'sondern', 'korrigier', 'ändere das', 'aendere das', 'mach draus',
    'lieber',
  ];

  static bool _enthaelt(String text, List<String> woerter) =>
      woerter.any(text.contains);

  /// Ist das eine Korrektur? Null heißt: ganz normaler Zuruf.
  ///
  /// Die Rücknahme wird zuerst geprüft: „nein, nimm das zurück" trägt
  /// beides, und gemeint ist das Weg.
  static Korrekturart? erkenne(String roh) {
    final text = roh.toLowerCase();
    if (_enthaelt(text, _weg)) return Korrekturart.ruecknahme;
    if (_enthaelt(text, _anders)) return Korrekturart.nachbesserung;
    return null;
  }
}

/// Was zuletzt getan wurde und wie lange es sich noch korrigieren lässt.
class Korrekturfenster {
  String? _was;
  List<AusgefuehrteAktion> _aktionen = const [];
  DateTime? _seit;

  /// Ob gerade etwas zu korrigieren ist.
  bool get offen {
    final seit = _seit;
    return seit != null &&
        DateTime.now().difference(seit) <= Korrekturbefehle.fenster;
  }

  /// Was Jarvis zuletzt gemeldet hat — für die Rückfrage ans Modell.
  String? get was => offen ? _was : null;

  /// Die Rücknahmen, jüngste zuerst.
  ///
  /// Umgedreht, weil beim Zurücknehmen mehrerer Aktionen die Reihenfolge
  /// zählt: wer erst die Liste löscht und dann ihre Position, findet die
  /// Position nicht mehr.
  List<AusgefuehrteAktion> get ruecknahmen =>
      offen ? _aktionen.reversed.toList() : const [];

  bool get nehmbar => ruecknahmen.isNotEmpty;

  void merken(String was, List<AusgefuehrteAktion> aktionen) {
    _was = was;
    _aktionen = List.unmodifiable(aktionen);
    _seit = DateTime.now();
  }

  void schliessen() {
    _was = null;
    _aktionen = const [];
    _seit = null;
  }
}

/// Eine ausgeführte Aktion samt ihrer Umkehrung.
class AusgefuehrteAktion {
  final String label;
  final String rueckKind;
  final Map<String, dynamic> rueckParams;

  const AusgefuehrteAktion({
    required this.label,
    required this.rueckKind,
    required this.rueckParams,
  });
}
