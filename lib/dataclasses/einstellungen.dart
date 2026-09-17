// ─────────────────────────────────────────────
//  Was diese Person eingestellt hat — die Werte,
//  die am Konto hängen und nicht am Gerät.
// ─────────────────────────────────────────────

/// Die Einstellungen eines Kontos, so wie der Server sie kennt.
///
/// **Nicht hier drin:** Weckwort, Schwelle und Hell-/Dunkelmodus. Die
/// hängen am Gerät — gelauscht wird in der Küche, und das Tablet an der
/// Wand will tagsüber hell, während das Telefon dunkel bleibt.
class Einstellungen {
  final bool use24h;
  final String? wetterOrt;

  final String? kiModell;
  final double? kiTemperatur;
  final int? kiMaxTokens;

  /// Ob dieses Konto einen MCP-Zugang hat. Mehr sagt diese Antwort nicht —
  /// was darunter freigegeben ist, holt die Baum-Seite selbst.
  final bool mcpAn;

  const Einstellungen({
    this.use24h = true,
    this.wetterOrt,
    this.kiModell,
    this.kiTemperatur,
    this.kiMaxTokens,
    this.mcpAn = false,
  });

  factory Einstellungen.fromJson(Map<String, dynamic> j) => Einstellungen(
        use24h: j['use_24h'] != false,
        wetterOrt: j['weather_city'] as String?,
        kiModell: j['ai_model'] as String?,
        kiTemperatur: (j['ai_temperature'] as num?)?.toDouble(),
        kiMaxTokens: (j['ai_max_tokens'] as num?)?.toInt(),
        mcpAn: j['mcp_an'] == true,
      );
}
