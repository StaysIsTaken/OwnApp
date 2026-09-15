import 'package:productivity/dataclasses/finanzen.dart';

/// Die Rechnung des Haushaltsbuchs — ohne Server, ohne Widget.
///
/// Sie steht hier und nicht in der Seite, weil sich genau das prüfen
/// lässt: eine Seite, die beim Aufbau lädt, zeigt im Test nur den
/// Ladekreis. Die Rechnung dahinter braucht nichts davon.
///
/// Gerechnet wird durchweg in **Cent als Ganzzahl**. Erst [alsText]
/// teilt durch hundert.
class Finanzrechnung {
  Finanzrechnung._();

  static const _monate = [
    'Januar', 'Februar', 'März', 'April', 'Mai', 'Juni',
    'Juli', 'August', 'September', 'Oktober', 'November', 'Dezember',
  ];

  // ── Geld anzeigen ──────────────────────────────────────────────────────

  /// „−47,83 €" oder „+2.500,00 €".
  ///
  /// Mit echtem Minuszeichen (U+2212), nicht mit Bindestrich: in einer
  /// Spalte aus Beträgen sitzt der Bindestrich zu hoch und zu kurz, und
  /// man übersieht ihn.
  static String alsText(int cents, {bool mitVorzeichen = true}) {
    final zeichen = !mitVorzeichen ? '' : (cents < 0 ? '−' : '+');
    return '$zeichen${nurBetrag(cents)}';
  }

  /// Ein Kontostand: „−500,00 €" oder „1.250,00 €".
  ///
  /// Anders als [alsText] **ohne Plus** — ein Plus vor einem Kontostand
  /// liest sich wie eine Buchung. Und anders als [nurBetrag] **mit
  /// Minus**: ein überzogenes Konto als „500,00 €" anzuzeigen und sich
  /// dabei auf die rote Farbe zu verlassen, ist keine Anzeige, sondern
  /// eine Falle — auf einem Ausdruck, einem Bildschirmfoto oder für
  /// jemanden, der Rot nicht sieht, steht dann das Gegenteil da.
  static String alsStand(int cents) =>
      '${cents < 0 ? '−' : ''}${nurBetrag(cents)}';

  /// Der Betrag so, wie er in ein Eingabefeld gehört: „12,50" oder
  /// „-12,50", ohne Währungszeichen.
  ///
  /// **Mit Vorzeichen, und zwar einem geraden Bindestrich.** Das Feld
  /// soll weitergetippt werden können, und ein typografisches Minus
  /// (`−`) steht auf keiner Tastatur — [cents] versteht zwar beide,
  /// aber wer es löschen und neu setzen will, käme nicht daran.
  ///
  /// Dass es das überhaupt gibt: [nurBetrag] wirft das Vorzeichen weg.
  /// Zum Vorbelegen eines Feldes, dessen Wert negativ sein darf, ist das
  /// falsch — der Anfangsbestand einer überzogenen Kasse wurde dabei
  /// still positiv, sobald jemand den Dialog nur öffnete und speicherte.
  static String fuersFeld(int cents) =>
      '${cents < 0 ? '-' : ''}${nurBetrag(cents).replaceAll(' €', '')}';

  /// „47,83 €" — ohne Vorzeichen, für Summen, deren Richtung schon
  /// danebensteht („Ausgaben: 320,00 €").
  static String nurBetrag(int cents) {
    final betrag = cents.abs();
    final euro = betrag ~/ 100;
    final rest = betrag % 100;
    return '${_tausender(euro)},${rest.toString().padLeft(2, '0')} €';
  }

  static String _tausender(int euro) {
    final ziffern = euro.toString();
    final puffer = StringBuffer();
    for (var i = 0; i < ziffern.length; i++) {
      if (i > 0 && (ziffern.length - i) % 3 == 0) puffer.write('.');
      puffer.write(ziffern[i]);
    }
    return puffer.toString();
  }

  // ── Geld einlesen ──────────────────────────────────────────────────────

  /// Was jemand ins Betragsfeld getippt hat, als Cent.
  ///
  /// Gibt `null` zurück, wenn daraus kein Betrag wird — der Aufrufer
  /// zeigt dann einen Hinweis, statt still eine Null zu buchen.
  ///
  /// Die Trennzeichen sind der ganze Aufwand hier, und sie sind es wert:
  /// ein Betrag wird aus der Banking-App kopiert, von Hand getippt oder
  /// vorgelesen, und jede Quelle schreibt es anders.
  ///
  /// * Sind **beide** Zeichen da (`1.234,56`), trennt das **letzte** die
  ///   Nachkommastellen; das andere ist der Tausenderpunkt.
  /// * Steht nur eines da und folgen ihm **genau drei** Ziffern
  ///   (`1.234`), ist es ein Tausenderpunkt — so liest man es auf
  ///   Deutsch.
  /// * Sonst trennt es die Nachkommastellen (`12,5` → 12,50 €).
  ///
  /// Mehr als zwei Nachkommastellen werden gerundet statt abgelehnt.
  /// „12,345" ist ein Vertipper und keine Anfrage, die man abweisen muss.
  static int? cents(String eingabe) {
    var t = eingabe.trim().replaceAll('€', '').replaceAll(' ', '');
    t = t.replaceAll(' ', '').replaceAll("'", '');
    if (t.isEmpty) return null;

    var negativ = false;
    if (t.startsWith('−') || t.startsWith('-')) {
      negativ = true;
      t = t.substring(1);
    } else if (t.startsWith('+')) {
      t = t.substring(1);
    }
    if (t.isEmpty) return null;

    final komma = t.lastIndexOf(',');
    final punkt = t.lastIndexOf('.');
    var trenner = komma > punkt ? komma : punkt;

    if (trenner >= 0) {
      final nachkomma = t.length - trenner - 1;
      final nurEines = komma < 0 || punkt < 0;
      final einmal = t.split(t[trenner]).length == 2;
      // Kommt dasselbe Zeichen mehrfach vor („1.234.567", „1,234,567"),
      // kann es keine Nachkommastelle abtrennen — dann sind es alles
      // Tausendertrennzeichen.
      if (nurEines && !einmal) trenner = -1;
      // „1.234" ist auf Deutsch eintausendzweihundertvierunddreissig.
      //
      // Das gilt NUR für den Punkt. Ein Komma trennt hier nie Tausender,
      // und diese Regel darauf auszudehnen kostete „12,344" den Faktor
      // tausend — der Test hat genau das gefunden.
      if (nurEines && einmal && nachkomma == 3 && t[trenner] == '.') {
        trenner = -1;
      }
    }

    String ganze, bruch;
    if (trenner < 0) {
      ganze = t;
      bruch = '';
    } else {
      ganze = t.substring(0, trenner);
      bruch = t.substring(trenner + 1);
    }
    ganze = ganze.replaceAll(',', '').replaceAll('.', '');

    if (ganze.isEmpty) ganze = '0';
    if (!_nurZiffern(ganze) || (bruch.isNotEmpty && !_nurZiffern(bruch))) {
      return null;
    }

    final euro = int.tryParse(ganze);
    if (euro == null) return null;

    var rest = 0;
    if (bruch.isNotEmpty) {
      // Auf zwei Stellen bringen: „5" → 50, „345" → 35 (gerundet).
      if (bruch.length == 1) {
        rest = int.parse(bruch) * 10;
      } else if (bruch.length == 2) {
        rest = int.parse(bruch);
      } else {
        final zwei = int.parse(bruch.substring(0, 2));
        final dritte = int.parse(bruch[2]);
        rest = dritte >= 5 ? zwei + 1 : zwei;
      }
    }

    // `rest` kann hier 100 sein: aus „9,995" wurden 9 Euro und 100 Cent.
    // Das ist gewollt — die Addition trägt den Euro dann selbst weiter.
    final gesamt = euro * 100 + rest;
    return negativ ? -gesamt : gesamt;
  }

  static bool _nurZiffern(String s) =>
      s.isNotEmpty && s.codeUnits.every((c) => c >= 0x30 && c <= 0x39);

  // ── Zeit ───────────────────────────────────────────────────────────────

  static DateTime monatsanfang(DateTime t) => DateTime(t.year, t.month, 1);

  /// Der letzte Tag des Monats — über „Tag 0 des nächsten", damit
  /// Februar und Schaltjahre sich selbst ausrechnen.
  static DateTime monatsende(DateTime t) => DateTime(t.year, t.month + 1, 0);

  /// Monat verschieben, ohne über den Monatsletzten zu stolpern.
  ///
  /// `DateTime(2026, 1, 31)` plus einen Monat ergäbe mit Dart-Arithmetik
  /// den 3. März. Hier wird immer vom Monatsanfang aus gerechnet.
  static DateTime monatVersetzt(DateTime t, int schritte) =>
      DateTime(t.year, t.month + schritte, 1);

  static String monatsname(DateTime t) => '${_monate[t.month - 1]} ${t.year}';

  static String alsDatum(DateTime t) =>
      '${_zwei(t.day)}.${_zwei(t.month)}.${t.year}';

  /// Was der Server als Tag erwartet: `2026-03-10`.
  static String alsIso(DateTime t) =>
      '${t.year.toString().padLeft(4, '0')}-${_zwei(t.month)}-${_zwei(t.day)}';

  static String _zwei(int n) => n.toString().padLeft(2, '0');

  // ── Daueraufträge in Worten ────────────────────────────────────────────

  static const _kurzeTage = {
    'MO': 'Mo', 'TU': 'Di', 'WE': 'Mi', 'TH': 'Do',
    'FR': 'Fr', 'SA': 'Sa', 'SU': 'So',
  };

  /// „monatlich am 1." · „alle 3 Monate am Monatsletzten" · „wöchentlich Mo, Fr"
  ///
  /// Der Punkt dabei ist die Ehrlichkeit beim 31.: das Backend kürzt auf
  /// den Monatsletzten, damit der Februar nicht ausfällt. Stünde hier
  /// „am 31.", erwartete der Nutzer im Februar nichts — und bekäme am
  /// 28. doch eine Buchung.
  static String takt(Dauerauftrag serie) {
    final n = serie.intervall;
    switch (serie.freq) {
      case 'DAILY':
        return n == 1 ? 'täglich' : 'alle $n Tage';
      case 'WEEKLY':
        final basis = n == 1 ? 'wöchentlich' : 'alle $n Wochen';
        final tage = _tageText(serie.wochentage);
        return tage == null ? basis : '$basis $tage';
      case 'YEARLY':
        final basis = n == 1 ? 'jährlich' : 'alle $n Jahre';
        return '$basis am ${serie.start.day}. ${_monate[serie.start.month - 1]}';
      case 'MONTHLY':
      default:
        final basis = n == 1 ? 'monatlich' : 'alle $n Monate';
        return '$basis ${_amTag(serie.monatstag ?? serie.start.day)}';
    }
  }

  static String _amTag(int tag) =>
      tag >= 31 ? 'am Monatsletzten' : 'am $tag.';

  static String? _tageText(String? wochentage) {
    if (wochentage == null || wochentage.trim().isEmpty) return null;
    final namen = [
      for (final t in wochentage.split(','))
        if (_kurzeTage[t.trim().toUpperCase()] != null)
          _kurzeTage[t.trim().toUpperCase()]!,
    ];
    return namen.isEmpty ? null : namen.join(', ');
  }

  /// „89,00 € seit 01.01.2026" — was eine Stufe aussagt.
  static String stufenText(Betragsstufe stufe) =>
      '${nurBetrag(stufe.cents)} ab ${alsDatum(stufe.gueltigAb)}';

  // ── Summen ─────────────────────────────────────────────────────────────

  static int summe(Iterable<Buchung> buchungen) =>
      buchungen.fold(0, (s, b) => s + b.cents);

  /// Was laut Vorschau noch kommt — dieselbe Rechnung, andere Herkunft.
  ///
  /// Bewusst getrennt von [summe] statt über eine gemeinsame
  /// Schnittstelle: eine Vorschauzeile und eine Buchung dürfen sich in
  /// der Rechnung nicht vermischen. Was geplant ist, ist nicht gebucht.
  static int summeGeplant(Iterable<Geplant> geplant) =>
      geplant.fold(0, (s, g) => s + g.cents);

  /// Buchungen nach Tag gebündelt, neuester Tag zuerst.
  ///
  /// Die Monatsansicht zeigt Tagesüberschriften; ohne das müsste sie
  /// beim Zeichnen vergleichen, ob der Vorgänger denselben Tag hatte —
  /// und das geht schief, sobald jemand die Sortierung ändert.
  static List<Tagesgruppe> nachTagen(List<Buchung> buchungen) {
    final sortiert = [...buchungen]..sort((a, b) {
        final tage = b.tag.compareTo(a.tag);
        return tage != 0 ? tage : b.id.compareTo(a.id);
      });

    final gruppen = <Tagesgruppe>[];
    for (final b in sortiert) {
      final tag = DateTime(b.tag.year, b.tag.month, b.tag.day);
      if (gruppen.isNotEmpty && gruppen.last.tag == tag) {
        gruppen.last.buchungen.add(b);
      } else {
        gruppen.add(Tagesgruppe(tag: tag, buchungen: [b]));
      }
    }
    return gruppen;
  }
}

/// Ein Tag mit seinen Buchungen.
class Tagesgruppe {
  final DateTime tag;
  final List<Buchung> buchungen;

  Tagesgruppe({required this.tag, required this.buchungen});

  int get summeCents => Finanzrechnung.summe(buchungen);
}
