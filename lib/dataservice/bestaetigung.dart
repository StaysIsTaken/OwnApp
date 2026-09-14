/// „Ja" und „nein" auf eine offene Rückfrage.
///
/// Schlägt Jarvis etwas vor, wartete es bisher auf einen **Fingertipp** —
/// auf einem Küchentablet, vor dem man mit mehligen Händen steht, genau
/// verkehrt herum. Der Kommentar im Sprach-Provider sagte es selbst: „eine
/// offene Bestätigung wartet auf einen Tipp, nicht auf ein Wort."
///
/// ## Warum ganze Wörter und kein `contains`
///
/// Alle anderen Parser hier suchen Teilzeichenketten — das geht, weil sie
/// ein Ankerwort verlangen („Timer", „Liste"). Hier ist die **ganze
/// Äußerung** die Antwort, und „ja" steckt in Januar, Jacke und jagen.
/// Deshalb wird in Wörter zerlegt.
library;

enum Zustimmung { ja, nein }

class Bestaetigung {
  Bestaetigung._();

  static const Set<String> _ja = {
    'ja', 'jawohl', 'jawoll', 'jo', 'joa', 'jup', 'jep', 'yes',
    'okay', 'ok', 'oke', 'klar', 'sicher', 'genau', 'richtig', 'stimmt',
    'passt', 'gerne', 'gern', 'bestätige', 'bestätigen', 'bestaetige',
    'einverstanden', 'los',
  };

  static const Set<String> _nein = {
    'nein', 'nee', 'ne', 'nö', 'noe', 'nichts', 'nicht', 'kein', 'keine',
    'no', 'falsch', 'abbrechen', 'abbruch', 'verwerfen', 'verwirf',
    'lass', 'lassen', 'stopp', 'stop', 'vergiss', 'quatsch', 'doch',
  };

  /// Deutet eine Antwort, oder null wenn der Satz keine ist.
  ///
  /// Wird **nur** gefragt, solange etwas offen ist — sonst schluckte ein
  /// beiläufiges „ja klar" den nächsten Zuruf.
  static Zustimmung? erkenne(String roh) {
    final woerter = roh
        .toLowerCase()
        .split(RegExp(r"[^a-zäöüß]+"))
        .where((w) => w.isNotEmpty)
        .toSet();
    if (woerter.isEmpty) return null;

    final nein = woerter.any(_nein.contains);
    // Nein gewinnt: „nein, mach das nicht" trägt beides, und wer „nein"
    // sagt, meint nie „ja". Andersherum wäre der Fehler teuer — bestätigt
    // wird etwas, das der Nutzer gerade abgelehnt hat.
    if (nein) return Zustimmung.nein;
    return woerter.any(_ja.contains) ? Zustimmung.ja : null;
  }
}
