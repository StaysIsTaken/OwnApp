import 'package:productivity/dataclasses/mcp_zugang.dart';

/// Ein Bereich im MCP-Baum: Feldname, Beschriftung, Erklärung.
class McpBereich {
  final String feld;
  final String name;

  /// Was hier wirklich hinausgeht. Steht in der Oberfläche unter dem
  /// Schalter — bei „Journal" und „Finanzen" ist das kein Beiwerk.
  final String erklaerung;

  /// Ob dieser Bereich auch dem Haushalt gehören kann.
  final bool imHaushalt;

  const McpBereich(this.feld, this.name, this.erklaerung,
      {this.imHaushalt = false});

  String get schreibfeld => '${feld}_w';
}

/// Der Baum der MCP-Einstellungen — als reine Rechnung.
///
/// Die Seite selbst lädt beim Aufbau und lässt sich damit nicht prüfen;
/// diese Regeln schon. Derselbe Kunstgriff wie bei
/// `haushalt_sicht.dart` und `finanz_rechnung.dart` — und hier wiegt er
/// schwerer, weil an diesen Regeln hängt, was ein fremder Assistent zu
/// sehen bekommt.
class McpBaum {
  McpBaum._();

  /// Die eigenen Bereiche, in der Reihenfolge der Oberfläche.
  ///
  /// **Der Chat fehlt, und zwar absichtlich.** Dort hängen fremde
  /// Nachrichten dran, und die eigene Zustimmung reicht dafür nicht. Es
  /// gibt ihn deshalb gar nicht erst als ausgeschalteten Schalter — das
  /// wäre eine Einladung, ihn anzuschalten.
  static const List<McpBereich> bereiche = [
    McpBereich('mcp_rezepte', 'Rezepte',
        'Namen und Zutaten deiner Rezepte.', imHaushalt: true),
    McpBereich('mcp_vorrat', 'Vorrat',
        'Was da ist, mit Mengen und Haltbarkeit.', imHaushalt: true),
    McpBereich('mcp_einkauf', 'Einkaufslisten',
        'Deine Zettel und was darauf offen ist.', imHaushalt: true),
    McpBereich('mcp_essensplan', 'Essensplan',
        'Was wann gekocht werden soll.', imHaushalt: true),
    McpBereich('mcp_termine', 'Termine',
        'Titel und Zeiten deiner Termine.'),
    McpBereich('mcp_aufgaben', 'Aufgaben',
        'Titel, Fälligkeit und Stand deiner Aufgaben.'),
    McpBereich('mcp_notizen', 'Notizen',
        'Titel und vollständiger Text deiner Notizen.'),
    McpBereich('mcp_zeiten', 'Zeiterfassung',
        'Deine Zeiteinträge mit Beschreibung.'),
    McpBereich('mcp_preise', 'Preise',
        'Was Waren zuletzt wo gekostet haben.', imHaushalt: true),
    McpBereich('mcp_finanzen', 'Finanzen',
        'Kassen, Kontostände und die Auswertung des Monats.',
        imHaushalt: true),
    McpBereich('mcp_journal', 'Journal',
        'Der vollständige Text deiner Tagebucheinträge.'),
  ];

  /// Dieselben Bereiche in der Haushalts-Fassung (`mcp_h_…`).
  static List<McpBereich> get haushaltsbereiche => [
        for (final b in bereiche.where((b) => b.imHaushalt))
          McpBereich(b.feld.replaceFirst('mcp_', 'mcp_h_'), 'Unser${_e(b)} ${b.name}',
              b.erklaerung, imHaushalt: true),
      ];

  static String _e(McpBereich b) =>
      b.name.endsWith('e') || b.name.endsWith('n') ? 'e' : '';

  // ── Was die Oberfläche zeigt ────────────────────────────────────────

  /// Ob überhaupt etwas unter dem Hauptschalter steht.
  static bool zeigtBereiche(McpZugang zugang) => zugang.an;

  /// Ob unter einem Bereich die Schreiben-Ebene erscheint.
  static bool zeigtSchreiben(McpZugang zugang, String feld) =>
      zugang.an && zugang.ist(feld);

  /// Ob der Haushalts-Ast überhaupt erscheint.
  ///
  /// Nur mit Haushalt — sonst stünde dort ein Ast über etwas, das es
  /// nicht gibt. Dieselbe Regel wie bei „Meins / Unseres".
  static bool zeigtHaushalt(McpZugang zugang, {required bool imHaushalt}) =>
      zugang.an && imHaushalt;

  /// Ob unter dem Haushalts-Ast seine Bereiche erscheinen.
  static bool zeigtHaushaltsbereiche(McpZugang zugang,
          {required bool imHaushalt}) =>
      zeigtHaushalt(zugang, imHaushalt: imHaushalt) && zugang.ist('mcp_haushalt');

  // ── Was beim Ausschalten mitgeht ────────────────────────────────────

  /// Welche Felder der Server mit zurücksetzt, wenn dieses ausgeht.
  ///
  /// Die Regel gilt auf dem Server; hier steht sie, damit die Seite den
  /// neuen Stand sofort zeigen kann, ohne auf die Antwort zu warten —
  /// und damit sich prüfen lässt, dass beide dasselbe meinen.
  ///
  /// Ohne diese Regel passiert Folgendes: jemand schaltet Finanzen an,
  /// erlaubt Schreiben, schaltet Finanzen aus — und Monate später wieder
  /// an, und das Schreiben ist still wieder da.
  static List<String> beimAusschalten(String feld) {
    if (feld == 'mcp_an') {
      return [
        'mcp_haushalt',
        for (final b in bereiche) ...[b.feld, b.schreibfeld],
        for (final b in haushaltsbereiche) ...[b.feld, b.schreibfeld],
      ];
    }
    if (feld == 'mcp_haushalt') {
      return [
        for (final b in haushaltsbereiche) ...[b.feld, b.schreibfeld],
      ];
    }
    if (feld.endsWith('_w')) return const [];
    return ['${feld}_w'];
  }
}
