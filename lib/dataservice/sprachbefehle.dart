/// Sprachbefehle, die das Tablet selbst beantwortet — ohne Server, ohne LLM.
///
/// Zwei Gründe, warum das nicht einfach alles an `/assistant/chat` geht:
/// Erstens kostet der Umweg mehrere Sekunden, und „geh zum Kalender" soll sich
/// sofort anfühlen. Zweitens kennt der Server die Seiten dieses Tablets gar
/// nicht — welche Ansichten es gibt, weiß nur das Gerät.
class Sprachbefehle {
  Sprachbefehle._();

  /// Das Verb, das einen Ansichtswechsel einleitet — nur das Verb.
  ///
  /// Früher standen hier ganze Wendungen wie „geh zu". Das ging schief, sobald
  /// jemand „geh **zum** Kalender" sagte: „zum" ist die Verschmelzung von „zu
  /// dem", und die Wendung passte nicht mehr. Statt jede Kombination
  /// aufzuzählen steht hier nur noch das Verb, und alles dahinter räumt
  /// [_fuellwoerter] weg.
  static const List<String> _navVerben = [
    'geh',
    'gehe',
    'wechsle',
    'wechsel',
    'zeig',
    'zeige',
    'öffne',
    'oeffne',
    'spring',
    'springe',
    'schalte',
  ];

  /// Alles, was zwischen Verb und Seitenname stehen darf: Präpositionen,
  /// Artikel, Höflichkeiten. Wird so lange von vorn abgetragen, bis der
  /// Seitenname übrig bleibt — „geh **zurück zu der** Kalenderansicht".
  static const List<String> _fuellwoerter = [
    'zurück',
    'zurueck',
    'wieder',
    'zu',
    'zum',
    'zur',
    'in',
    'ins',
    'auf',
    'nach',
    'die',
    'das',
    'der',
    'den',
    'dem',
    'mir',
    'mal',
    'bitte',
  ];

  /// Endungen, die man dranhängt, ohne dass die Seite so heißt.
  static const List<String> _endungen = [
    'ansicht',
    'seite',
    'tab',
  ];

  /// Erkennt einen Ansichtswechsel und liefert das gemeinte Ziel zurück.
  ///
  /// Rückgabe: der Rest hinter der Einleitung („kalender"), oder null wenn der
  /// Satz gar kein Navigationsbefehl ist.
  ///
  /// Eine Einleitung ist Pflicht. Nur auf den Seitennamen zu prüfen wäre
  /// verlockend, aber „Kalender morgen um drei eintragen" wäre dann ein
  /// Ansichtswechsel statt eines Termins.
  static String? navigationsZiel(String text) {
    var rest = text.trim().toLowerCase();
    if (rest.isEmpty) return null;

    // Anrede wegschneiden, falls sie in der Aufnahme gelandet ist.
    for (final anrede in ['jarvis', 'hey jarvis', 'hallo jarvis']) {
      if (rest.startsWith(anrede)) {
        rest = rest.substring(anrede.length).trim();
      }
    }
    rest = rest.replaceFirst(RegExp(r'^[,\.\s]+'), '');

    // Das längste Verb zuerst, damit „gehe" nicht als „geh" plus Rest „e"
    // gelesen wird.
    final verben = [..._navVerben]..sort((a, b) => b.length.compareTo(a.length));

    String? gefunden;
    for (final v in verben) {
      if (rest.startsWith('$v ')) {
        gefunden = rest.substring(v.length).trim();
        break;
      }
    }
    if (gefunden == null) return null;

    // Wiederholt und nicht einmal je Wort: „zurück zu der Kalender" braucht
    // drei Durchgänge, und in welcher Reihenfolge die Wörter fallen, soll
    // nicht davon abhängen, wie _fuellwoerter sortiert ist.
    var ziel = gefunden;
    var nochmal = true;
    while (nochmal) {
      nochmal = false;
      for (final f in _fuellwoerter) {
        if (ziel.startsWith('$f ')) {
          ziel = ziel.substring(f.length).trim();
          nochmal = true;
          break;
        }
      }
    }

    for (final e in _endungen) {
      if (ziel.endsWith(e) && ziel.length > e.length) {
        ziel = ziel.substring(0, ziel.length - e.length).trim();
      }
    }
    ziel = ziel.replaceAll(RegExp(r'[\.,!\?]+$'), '').trim();
    return ziel.isEmpty ? null : ziel;
  }
}
