import 'package:flutter/material.dart';

/// Die Leiste zum Blättern über einem Kalender.
///
/// Links zurück, rechts vor, in der Mitte der Zeitraum. Steht man nicht
/// mehr auf dem Ausgangspunkt, kommt ein Knopf dazu, der dorthin
/// zurückführt — sonst tippt man sich nach acht Monaten vorwärts mühsam
/// wieder heim.
///
/// Eigenes Widget, weil Wochen- und Monatsansicht dieselbe Leiste
/// brauchen und sie sonst zweimal dastünde — mit der sicheren Aussicht,
/// dass die zweite irgendwann anders aussieht als die erste.
class KalenderBlaettern extends StatelessWidget {
  final String zeitraum;

  /// Zweite Zeile, kleiner — etwa „KW 35". Optional.
  final String? unterzeile;

  final VoidCallback onZurueck;
  final VoidCallback onVor;

  /// Null = wir stehen am Ausgangspunkt, es gibt nichts zurückzusetzen.
  final VoidCallback? onHeute;

  /// Grosse Knoepfe fuer ein Geraet an der Wand.
  final bool gross;

  const KalenderBlaettern({
    super.key,
    required this.zeitraum,
    required this.onZurueck,
    required this.onVor,
    this.unterzeile,
    this.onHeute,
    this.gross = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final knopfGroesse = gross ? 28.0 : 20.0;

    return SizedBox(
      height: gross ? 48 : 34,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded),
            iconSize: knopfGroesse,
            visualDensity:
                gross ? VisualDensity.standard : VisualDensity.compact,
            tooltip: 'Zurück',
            onPressed: onZurueck,
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  zeitraum,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: (gross ? text.titleMedium : text.labelLarge)
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                if (unterzeile != null)
                  Text(
                    unterzeile!,
                    style: TextStyle(
                      fontSize: gross ? 13 : 10,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          // Nur wenn man weg ist – ein Knopf, der nichts tut, ist im Weg.
          if (onHeute != null)
            TextButton(
              onPressed: onHeute,
              style: TextButton.styleFrom(
                visualDensity:
                    gross ? VisualDensity.standard : VisualDensity.compact,
                padding: EdgeInsets.symmetric(horizontal: gross ? 12 : 6),
              ),
              child: Text('Heute',
                  style: TextStyle(fontSize: gross ? 15 : 12)),
            ),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded),
            iconSize: knopfGroesse,
            visualDensity:
                gross ? VisualDensity.standard : VisualDensity.compact,
            tooltip: 'Weiter',
            onPressed: onVor,
          ),
        ],
      ),
    );
  }
}
