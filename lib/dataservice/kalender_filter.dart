import 'package:productivity/dataclasses/kalender.dart';

/// Welche Kalender die Ansicht zeigen soll — gesprochen gesteuert.
///
/// „Zeige nur den Arbeitskalender und den Müllkalender an." Das ist kein
/// Auftrag ans Sprachmodell: der Server weiß nicht, was gerade auf dem
/// Tablet zu sehen ist, und der Umweg kostete Sekunden für eine Antwort,
/// die das Gerät selbst kennt. Deshalb steht die Erkennung hier, neben
/// [Sprachbefehle] und [SprachAuskunft].
///
/// Die Reihenfolge ist wichtig: Das hier muss **vor**
/// `Sprachbefehle.navigationsZiel` geprüft werden. „Zeige …" leitet dort
/// einen Seitenwechsel ein, und „zeige nur den Arbeitskalender an" landete
/// sonst als Suche nach einer Seite namens „nur den arbeitskalender an".
class KalenderFilter {
  KalenderFilter._();

  /// Wörter, die vor dem eigentlichen Namen stehen dürfen.
  static const List<String> _fuellwoerter = [
    'den',
    'dem',
    'der',
    'die',
    'das',
    'meinen',
    'meinem',
    'meine',
    'mein',
    'vom',
    'von',
    'im',
  ];

  /// Erkennt den Wunsch und liefert die genannten Namen.
  ///
  /// Rückgabe:
  /// * `null` — der Satz meint keine Kalenderauswahl,
  /// * leere Liste — „zeige wieder alle Kalender an", also Filter weg,
  /// * sonst die gesprochenen Namen in der genannten Reihenfolge.
  static List<String>? erkenne(String text) {
    var satz = text.trim().toLowerCase();
    if (satz.isEmpty) return null;

    for (final anrede in ['hey jarvis', 'hallo jarvis', 'jarvis']) {
      if (satz.startsWith(anrede)) satz = satz.substring(anrede.length);
    }
    satz = satz.replaceFirst(RegExp(r'^[,\.\s]+'), '');
    satz = satz.replaceAll(RegExp(r'[\.,!\?]+$'), '').trim();

    // Ohne „Kalender" im Satz ist es keine Kalenderauswahl. „Zeige nur die
    // offenen Aufgaben" darf nicht hier hängen bleiben.
    if (!satz.contains('kalender')) return null;

    final einleitung = RegExp(
      r'^(zeig|zeige|zeigt|blende|filtere?)\s+(mir\s+)?(bitte\s+)?',
    );
    if (!einleitung.hasMatch(satz)) return null;
    var rest = satz.replaceFirst(einleitung, '').trim();

    // „… wieder an" / „… ein" am Ende: reine Satzmelodie.
    rest = rest.replaceFirst(RegExp(r'\s+(an|ein|wieder an)$'), '').trim();

    // Alles zurück auf Anfang.
    if (RegExp(r'^(wieder\s+)?alle\s+kalender(\s+wieder)?$').hasMatch(rest)) {
      return const [];
    }

    final nur = RegExp(r'^(nur|ausschließlich|ausschliesslich|bloß|bloss)\s+');
    if (!nur.hasMatch(rest)) return null;
    rest = rest.replaceFirst(nur, '').trim();

    if (RegExp(r'^(wieder\s+)?alle\s+kalender$').hasMatch(rest)) {
      return const [];
    }

    final namen = <String>[];
    for (final teil in rest.split(RegExp(r'\s+und\s+|\s*,\s*|\s+sowie\s+'))) {
      final name = _namenTeil(teil);
      if (name != null) namen.add(name);
    }
    return namen.isEmpty ? null : namen;
  }

  /// Schält aus „den arbeitskalender" das „arbeit" heraus.
  static String? _namenTeil(String roh) {
    var teil = roh.trim();
    if (teil.isEmpty) return null;

    var nochmal = true;
    while (nochmal) {
      nochmal = false;
      for (final f in _fuellwoerter) {
        if (teil.startsWith('$f ')) {
          teil = teil.substring(f.length).trim();
          nochmal = true;
          break;
        }
      }
    }

    // „arbeitskalender" -> „arbeits" -> „arbeit"; „müll kalender" -> „müll".
    // Das angehängte Wort fällt weg, der Name bleibt. Steht „kalender"
    // allein da, war es kein Name.
    if (teil.endsWith('kalender')) {
      teil = teil.substring(0, teil.length - 'kalender'.length).trim();
      if (teil.endsWith('s')) teil = teil.substring(0, teil.length - 1);
    }
    teil = teil.trim();
    return teil.isEmpty ? null : teil;
  }

  /// Ordnet gesprochene Namen den vorhandenen Kalendern zu.
  ///
  /// In drei Stufen, jede nur wenn die vorige leer ausging: genauer Name,
  /// enthaltener Name, Name des Besitzers. Die letzte Stufe deckt „zeige nur
  /// Lisas Kalender an" ab — dort ist „lisa" kein Kalendername.
  ///
  /// Mehrdeutigkeit endet großzügig: heißen zwei Kalender „Mein Kalender",
  /// erscheinen beide. Einen davon zu raten hieße, dem Nutzer Termine
  /// wegzunehmen, ohne dass er es merkt.
  static Set<int> waehle(List<Kalender> kalender, List<String> namen) {
    final ids = <int>{};
    for (final roh in namen) {
      final gesucht = roh.toLowerCase().trim();
      if (gesucht.isEmpty) continue;

      // Erst das gesagte Wort, dann ohne Genitiv-s. In dieser Reihenfolge,
      // denn ein Kalender darf „Haus" heißen — „hau" wäre der falsche Name.
      final varianten = <String>{gesucht, _ohneGenitiv(gesucht)};

      Iterable<Kalender> treffer = const [];
      for (final v in varianten) {
        treffer = kalender.where((k) => k.name.toLowerCase() == v);
        if (treffer.isNotEmpty) break;
      }
      if (treffer.isEmpty) {
        for (final v in varianten) {
          treffer = kalender.where((k) =>
              k.name.toLowerCase().contains(v) ||
              v.contains(k.name.toLowerCase()));
          if (treffer.isNotEmpty) break;
        }
      }
      if (treffer.isEmpty) {
        for (final v in varianten) {
          treffer = kalender.where((k) =>
              k.ownerName.toLowerCase() == v ||
              k.ownerName.toLowerCase().contains(v));
          if (treffer.isNotEmpty) break;
        }
      }
      ids.addAll(treffer.map((k) => k.id));
    }
    return ids;
  }

  /// „lisas" -> „lisa". Gesprochen fällt das Genitiv-s mit, geschrieben
  /// heißt der Kalender trotzdem anders.
  static String _ohneGenitiv(String wort) {
    if (wort.length > 3 && wort.endsWith('s')) {
      return wort.substring(0, wort.length - 1);
    }
    return wort;
  }
}
