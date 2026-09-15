import 'package:flutter/foundation.dart';
import 'package:productivity/dataclasses/finanzen.dart';
import 'package:productivity/dataservice/api_client.dart';
import 'package:productivity/dataservice/finanz_rechnung.dart';

/// Das Haushaltsbuch: Kassen, Kategorien, Buchungen, Auswertung.
///
/// Beträge gehen als **Cent mit Vorzeichen** über die Leitung — negativ
/// ist eine Ausgabe. Den Schalter „Ausgabe / Einnahme" hat die
/// Oberfläche; hierher kommt schon das fertige Vorzeichen.
class FinanzService {
  FinanzService._();

  static const String _pfad = '/finanzen';

  /// Ein leerer String ist keine Kennung.
  ///
  /// Dieselbe Falle wie beim Einkauf: er sieht aus wie eine, der
  /// Fremdschlüssel lehnt ihn ab, der Server stürzt ab — und weil ein
  /// abgestürzter Server keine CORS-Kopfzeilen mehr setzt, meldet der
  /// Browser einen CORS-Fehler statt des echten Grundes. Darts `?wert`
  /// lässt nur null weg, nicht den leeren String.
  @visibleForTesting
  static String? kennung(String? wert) =>
      (wert == null || wert.isEmpty) ? null : wert;

  // ── Kassen ─────────────────────────────────────────────────────────────

  /// Eigene Kassen und die, auf denen man steht.
  ///
  /// [alle] verlangt `finance:read_all` — ein Sonderrecht, das der
  /// Haushalt bewusst nicht hat.
  static Future<List<Kasse>> kassen({bool alle = false}) async {
    final r = await ApiClient.dio.get(
      '$_pfad/kassen',
      queryParameters: alle ? {'alle': true} : null,
    );
    return (r.data as List<dynamic>)
        .map((e) => Kasse.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<Kasse> kasseAnlegen(
    String name, {
    String art = 'giro',
    String color = '#3B82F6',
    int startCents = 0,
  }) async {
    final r = await ApiClient.dio.post('$_pfad/kassen', data: {
      'name': name,
      'kind': art,
      'color': color,
      'start_cents': startCents,
    });
    return Kasse.fromJson(r.data as Map<String, dynamic>);
  }

  static Future<Kasse> kasseAendern(
    int id, {
    String? name,
    String? art,
    String? color,
    int? startCents,
  }) async {
    final r = await ApiClient.dio.put('$_pfad/kassen/$id', data: {
      'name': ?name,
      'kind': ?art,
      'color': ?color,
      'start_cents': ?startCents,
    });
    return Kasse.fromJson(r.data as Map<String, dynamic>);
  }

  static Future<void> kasseLoeschen(int id) =>
      ApiClient.dio.delete('$_pfad/kassen/$id');

  static Future<void> mitgliedHinzufuegen(int kasseId, String userId) =>
      ApiClient.dio.post('$_pfad/kassen/$kasseId/mitglieder/$userId');

  static Future<void> mitgliedEntfernen(int kasseId, String userId) =>
      ApiClient.dio.delete('$_pfad/kassen/$kasseId/mitglieder/$userId');

  // ── Kategorien ─────────────────────────────────────────────────────────

  static Future<List<Finanzkategorie>> kategorien() async {
    final r = await ApiClient.dio.get('$_pfad/kategorien');
    return (r.data as List<dynamic>)
        .map((e) => Finanzkategorie.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<Finanzkategorie> kategorieAnlegen(
    String name, {
    String art = 'ausgabe',
    String color = '#64748B',
    String? icon,
  }) async {
    final r = await ApiClient.dio.post('$_pfad/kategorien', data: {
      'name': name,
      'kind': art,
      'color': color,
      'icon': ?kennung(icon),
    });
    return Finanzkategorie.fromJson(r.data as Map<String, dynamic>);
  }

  static Future<Finanzkategorie> kategorieAendern(
    int id, {
    String? name,
    String? art,
    String? color,
  }) async {
    final r = await ApiClient.dio.put('$_pfad/kategorien/$id', data: {
      'name': ?name,
      'kind': ?art,
      'color': ?color,
    });
    return Finanzkategorie.fromJson(r.data as Map<String, dynamic>);
  }

  static Future<void> kategorieLoeschen(int id) =>
      ApiClient.dio.delete('$_pfad/kategorien/$id');

  // ── Buchungen ──────────────────────────────────────────────────────────

  /// Buchungen im Zeitraum, neueste zuerst.
  ///
  /// Ohne [kasse] alle sichtbaren: die Monatsansicht rechnet über den
  /// ganzen Haushalt, die Kasse ist nur ein Filter.
  static Future<List<Buchung>> buchungen({
    int? kasse,
    DateTime? von,
    DateTime? bis,
  }) async {
    final r = await ApiClient.dio.get('$_pfad/buchungen', queryParameters: {
      'kasse': ?kasse,
      if (von != null) 'von': Finanzrechnung.alsIso(von),
      if (bis != null) 'bis': Finanzrechnung.alsIso(bis),
    });
    return (r.data as List<dynamic>)
        .map((e) => Buchung.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// [cents] trägt das Vorzeichen: negativ ist eine Ausgabe.
  static Future<Buchung> buchen({
    required int kasseId,
    required DateTime tag,
    required int cents,
    required String titel,
    int? kategorieId,
    String? notiz,
    String? externeKennung,
  }) async {
    final r = await ApiClient.dio.post('$_pfad/buchungen', data: {
      'account_id': kasseId,
      'booked_on': Finanzrechnung.alsIso(tag),
      'amount_cents': cents,
      'title': titel,
      'category_id': ?kategorieId,
      'note': ?kennung(notiz),
      // Stabile Kennung des Erzeugers. Zusammen mit einem Unique-Index
      // im Backend verhindert sie, dass derselbe Vorgang zweimal im
      // Kassenbuch landet; der zweite Versuch kommt als 409 zurück.
      'external_uid': ?kennung(externeKennung),
    });
    return Buchung.fromJson(r.data as Map<String, dynamic>);
  }

  static Future<Buchung> buchungAendern(
    int id, {
    DateTime? tag,
    int? cents,
    String? titel,
    int? kategorieId,
    String? notiz,
  }) async {
    final r = await ApiClient.dio.put('$_pfad/buchungen/$id', data: {
      'booked_on': ?(tag == null ? null : Finanzrechnung.alsIso(tag)),
      'amount_cents': ?cents,
      'title': ?titel,
      'category_id': ?kategorieId,
      'note': ?kennung(notiz),
    });
    return Buchung.fromJson(r.data as Map<String, dynamic>);
  }

  static Future<void> buchungLoeschen(int id) =>
      ApiClient.dio.delete('$_pfad/buchungen/$id');

  // ── Daueraufträge ──────────────────────────────────────────────────────

  static Future<List<Dauerauftrag>> serien({int? kasse}) async {
    final r = await ApiClient.dio.get('$_pfad/serien', queryParameters: {
      'kasse': ?kasse,
    });
    return (r.data as List<dynamic>)
        .map((e) => Dauerauftrag.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// [cents] ist der **erste Betrag** und wird zur Stufe ab [start].
  ///
  /// Zusammen und nicht nacheinander: eine Regel ohne Betrag könnte das
  /// Nachbuchen nur überspringen.
  static Future<Dauerauftrag> serieAnlegen({
    required int kasseId,
    required String titel,
    required DateTime start,
    required int cents,
    String freq = 'MONTHLY',
    int intervall = 1,
    String? wochentage,
    int? monatstag,
    DateTime? ende,
    int? kategorieId,
    String? notiz,
  }) async {
    final r = await ApiClient.dio.post('$_pfad/serien', data: {
      'account_id': kasseId,
      'title': titel,
      'start_on': Finanzrechnung.alsIso(start),
      'amount_cents': cents,
      'freq': freq,
      'interval_n': intervall,
      'byweekday': ?kennung(wochentage),
      'bymonthday': ?monatstag,
      'end_on': ?(ende == null ? null : Finanzrechnung.alsIso(ende)),
      'category_id': ?kategorieId,
      'note': ?kennung(notiz),
    });
    return Dauerauftrag.fromJson(r.data as Map<String, dynamic>);
  }

  /// Zum Aussetzen: `aktiv: false` kommt durch.
  ///
  /// Der `?`-Marker lässt nur **null** weg, nicht `false` — ein
  /// ausdrücklich gesetztes `false` geht also mit. Verwechselt man das
  /// mit einer Prüfung auf „leer", baut man sich ein Aussetzen, das
  /// stillschweigend nichts tut.
  static Future<Dauerauftrag> serieAendern(
    int id, {
    String? titel,
    String? freq,
    int? intervall,
    String? wochentage,
    int? monatstag,
    DateTime? start,
    DateTime? ende,
    bool? aktiv,
    int? kategorieId,
    String? notiz,
  }) async {
    final r = await ApiClient.dio.put('$_pfad/serien/$id', data: {
      'title': ?titel,
      'freq': ?freq,
      'interval_n': ?intervall,
      'byweekday': ?kennung(wochentage),
      'bymonthday': ?monatstag,
      'start_on': ?(start == null ? null : Finanzrechnung.alsIso(start)),
      'end_on': ?(ende == null ? null : Finanzrechnung.alsIso(ende)),
      'active': ?aktiv,
      'category_id': ?kategorieId,
      'note': ?kennung(notiz),
    });
    return Dauerauftrag.fromJson(r.data as Map<String, dynamic>);
  }

  static Future<void> serieLoeschen(int id) =>
      ApiClient.dio.delete('$_pfad/serien/$id');

  /// „Ab April kostet der Abschlag 94,50."
  ///
  /// Zweimal derselbe Stichtag ist eine Korrektur, keine zweite Stufe.
  static Future<Betragsstufe> stufeSetzen(
    int serieId, {
    required DateTime gueltigAb,
    required int cents,
    String? notiz,
  }) async {
    final r = await ApiClient.dio.post('$_pfad/serien/$serieId/betrag', data: {
      'gueltig_ab': Finanzrechnung.alsIso(gueltigAb),
      'amount_cents': cents,
      'note': ?kennung(notiz),
    });
    return Betragsstufe.fromJson(r.data as Map<String, dynamic>);
  }

  static Future<void> stufeLoeschen(int serieId, int stufeId) =>
      ApiClient.dio.delete('$_pfad/serien/$serieId/betrag/$stufeId');

  // ── Vorschau und Nachbuchen ────────────────────────────────────────────

  /// Was im Zeitraum fällig ist und noch nicht gebucht wurde.
  ///
  /// Steht nirgends in der Datenbank — jeder Aufruf rechnet neu.
  static Future<List<Geplant>> vorschau({
    required DateTime von,
    required DateTime bis,
    int? kasse,
  }) async {
    final r = await ApiClient.dio.get('$_pfad/vorschau', queryParameters: {
      'von': Finanzrechnung.alsIso(von),
      'bis': Finanzrechnung.alsIso(bis),
      'kasse': ?kasse,
    });
    return (r.data as List<dynamic>)
        .map((e) => Geplant.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Trägt nach, was bis heute fällig war. Gibt zurück, wie viele.
  ///
  /// Wird beim Öffnen des Haushaltsbuchs gerufen, obwohl der Server das
  /// nachts ohnehin tut. Kein Übereifer: ein ausgefallener
  /// Hintergrundlauf darf nicht bedeuten, dass die Miete im Kassenbuch
  /// fehlt — dieselbe Überlegung wie bei [ErinnerungsAbgleich].
  ///
  /// Doppelt buchen kann das nicht; darüber wacht ein Unique-Index in
  /// der Datenbank.
  static Future<int> nachbuchen() async {
    final r = await ApiClient.dio.post('$_pfad/nachbuchen');
    return ((r.data as Map<String, dynamic>)['gebucht'] as num?)?.toInt() ?? 0;
  }

  // ── Auswertung ─────────────────────────────────────────────────────────

  static Future<Auswertung> auswertung({
    required DateTime von,
    required DateTime bis,
    int? kasse,
  }) async {
    final r = await ApiClient.dio.get('$_pfad/auswertung', queryParameters: {
      'von': Finanzrechnung.alsIso(von),
      'bis': Finanzrechnung.alsIso(bis),
      'kasse': ?kasse,
    });
    return Auswertung.fromJson(r.data as Map<String, dynamic>);
  }
}
