/// „Jarvis, lies mir die Einkaufsliste vor."
///
/// Und die Antwort auf die Rückfrage danach: „die zweite", „die vom
/// Baumarkt". Beides gehört zusammen — ohne das Kurzgedächtnis endet die
/// Rückfrage in einer Sackgasse, in der man den Namen buchstabieren muss.
///
/// Wie [Sprachbefehle] und [TimerBefehle] beantwortet das Tablet den Satz
/// selbst. Hier kommt ein dritter Grund zu den bekannten hinzu: das Modell
/// würde eine Liste *nacherzählen*, und dabei Posten zusammenfassen,
/// umsortieren oder weglassen. Wer eine Einkaufsliste vorgelesen bekommt,
/// will sie vollständig und in der Reihenfolge, in der sie dasteht.
library;

class ListenBefehle {
  ListenBefehle._();

  /// Verben, mit denen man ums Vorlesen bittet.
  static const List<String> _lesen = [
    'lies', 'les', 'vorlesen', 'vorlies', 'sag mir', 'sag was',
    'was steht', 'was ist', 'was hab', 'was haben wir',
  ];

  /// Woran die Einkaufsliste zu erkennen ist.
  static const List<String> _liste = [
    'einkaufsliste', 'einkaufszettel', 'einkauf', 'liste', 'zettel',
  ];

  static bool _enthaelt(String text, List<String> woerter) =>
      woerter.any(text.contains);

  /// Ist das eine Bitte, die Einkaufsliste vorzulesen?
  ///
  /// Beides muss dastehen: ein Lese-Verb UND das Wort für die Liste. Nur
  /// auf „Liste" zu prüfen wäre verlockend, aber „setz Milch auf die Liste"
  /// wäre dann ein Vorlesen statt eines Eintrags.
  static bool istVorlesen(String roh) {
    final text = roh.toLowerCase();
    if (!_enthaelt(text, _liste)) return false;
    // Wer etwas hinzufügt, will nicht vorgelesen bekommen — auch wenn er
    // „sag mal, setz Milch auf die Liste" sagt.
    if (_enthaelt(text, ['setz', 'schreib', 'pack', 'füg', 'fueg', 'trag',
                         'hak', 'streich', 'lösch', 'loesch', 'entfern'])) {
      return false;
    }
    return _enthaelt(text, _lesen);
  }

  /// Welche der angebotenen Listen gemeint ist.
  ///
  /// Gibt den Index zurück, oder null wenn der Satz keine Antwort darauf
  /// ist. [namen] steht in der Reihenfolge, in der vorgelesen wurde — die
  /// Ordnungszahl bezieht sich darauf.
  static int? auswahlAus(String roh, List<String> namen) {
    if (namen.isEmpty) return null;
    final text = roh.toLowerCase().trim();

    // Erst der Name: er ist eindeutiger als jede Ordnungszahl. „Die vom
    // Baumarkt" und „Baumarkt" sollen beide gehen.
    for (var i = 0; i < namen.length; i++) {
      if (text.contains(namen[i].toLowerCase())) return i;
    }

    // Dann die Ordnungszahl. „Die letzte" bewusst dabei: bei zwei Listen
    // sagt man eher „die letzte" als „die zweite".
    const zahlen = {
      'erste': 0, 'ersten': 0, 'eine': 0, 'einen': 0,
      'zweite': 1, 'zweiten': 1,
      'dritte': 2, 'dritten': 2,
      'vierte': 3, 'vierten': 3,
      'fünfte': 4, 'fuenfte': 4, 'fünften': 4, 'fuenften': 4,
    };
    for (final eintrag in zahlen.entries) {
      if (text.contains(eintrag.key) && eintrag.value < namen.length) {
        return eintrag.value;
      }
    }
    if (text.contains('letzte')) return namen.length - 1;

    // Eine blanke Ziffer: „die 2".
    final ziffer = RegExp(r'\b([1-9])\b').firstMatch(text);
    if (ziffer != null) {
      final nummer = int.parse(ziffer.group(1)!) - 1;
      if (nummer < namen.length) return nummer;
    }
    return null;
  }
}

/// Was zuletzt zur Auswahl stand.
///
/// Ohne das endet jede Rückfrage in einer Sackgasse: Jarvis fragt „welche
/// Liste?", und die einzige Antwort, die ankommt, ist der vollständige
/// Name. „Die zweite" wäre für das Gerät bis dahin ein Satz wie jeder
/// andere gewesen.
///
/// **Nicht nur für Listen.** Der Name ist Geschichte — es merkt sich eine
/// beliebige Auswahl, die die App angeboten hat: Zettel, Kalender, Läden,
/// Aufgaben. Es kennt keinen davon, nur Namen in der Reihenfolge, in der
/// vorgelesen wurde.
///
/// Es gilt nur für Rückfragen, die **die App selbst** stellt. Fragt das
/// Sprachmodell (weil ein Werkzeug mehrere Treffer meldet), steht die
/// Auswahl in seiner eigenen Antwort und damit in seinem Verlauf — dort
/// löst es „die zweite" selbst auf.
class Auswahlgedaechtnis {
  /// Wie lange eine angebotene Auswahl gilt.
  ///
  /// Zehn Minuten. Die ersten zwei waren zu knapp: am Küchentablet ruft
  /// man quer durch den Raum, geht etwas holen und kommt zurück — und die
  /// Antwort kam dann in eine Auswahl, die es nicht mehr gab.
  static const Duration gueltig = Duration(minutes: 10);

  List<String> _namen = const [];
  DateTime? _seit;

  /// Was gerade zur Auswahl steht — leer, wenn nichts (mehr) offen ist.
  List<String> get offen {
    final seit = _seit;
    if (seit == null || DateTime.now().difference(seit) > gueltig) {
      return const [];
    }
    return _namen;
  }

  void merken(List<String> namen) {
    _namen = List.unmodifiable(namen);
    _seit = DateTime.now();
  }

  void vergessen() {
    _namen = const [];
    _seit = null;
  }

  /// Löst eine Antwort wie „die zweite" gegen das Gemerkte auf.
  ///
  /// Gibt den Namen zurück, oder null wenn nichts offen ist oder der Satz
  /// keine Antwort darauf war.
  String? aufloesen(String gesagt) {
    final namen = offen;
    if (namen.isEmpty) return null;
    final index = ListenBefehle.auswahlAus(gesagt, namen);
    return index == null ? null : namen[index];
  }
}
