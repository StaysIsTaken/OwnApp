// ─────────────────────────────────────────────
//  Der eigene MCP-Zugang: Adresse, Schlüssel-
//  Erkennungszeichen und der Stand des Baums.
// ─────────────────────────────────────────────

/// Was der Server über den eigenen Zugang herausgibt.
///
/// **Der Schlüssel ist nicht dabei**, und das ist kein Versehen: er wird
/// nur als Hash gespeichert und genau einmal angezeigt — direkt nachdem
/// er entstanden ist. [schluesselAnfang] ist bloß ein
/// Wiedererkennungszeichen, damit man weiß, welcher Schlüssel wo
/// eingetragen ist.
class McpZugang {
  final bool an;
  final String? slug;
  final String? schluesselAnfang;
  final DateTime? erstelltAm;
  final DateTime? zuletztBenutzt;

  /// Der ganze Baum als Feld → an/aus, so wie der Server ihn führt.
  final Map<String, bool> schalter;

  const McpZugang({
    this.an = false,
    this.slug,
    this.schluesselAnfang,
    this.erstelltAm,
    this.zuletztBenutzt,
    this.schalter = const {},
  });

  /// Ob es überhaupt schon einen Schlüssel gibt. Ohne ihn ist der Zugang
  /// eine Adresse ohne Tür.
  bool get hatSchluessel => (schluesselAnfang ?? '').isNotEmpty;

  bool ist(String feld) => schalter[feld] ?? false;

  static DateTime? _zeit(dynamic wert) =>
      wert == null ? null : DateTime.tryParse(wert.toString());

  factory McpZugang.fromJson(Map<String, dynamic> j) => McpZugang(
        an: j['an'] == true,
        slug: j['slug'] as String?,
        schluesselAnfang: j['schluessel_anfang'] as String?,
        erstelltAm: _zeit(j['erstellt_at']),
        zuletztBenutzt: _zeit(j['zuletzt_benutzt_at']),
        schalter: {
          for (final e in (j['schalter'] as Map<String, dynamic>? ?? {}).entries)
            e.key: e.value == true,
        },
      );
}

/// Die einzige Gelegenheit, den Schlüssel zu sehen.
class McpSchluessel {
  final String slug;
  final String schluessel;

  const McpSchluessel({required this.slug, required this.schluessel});

  factory McpSchluessel.fromJson(Map<String, dynamic> j) => McpSchluessel(
        slug: j['slug']?.toString() ?? '',
        schluessel: j['schluessel']?.toString() ?? '',
      );
}
