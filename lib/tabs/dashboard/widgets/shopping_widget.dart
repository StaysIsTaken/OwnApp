import 'package:flutter/material.dart';
import 'package:productivity/main.dart';
import 'package:productivity/dataclasses/einkauf.dart';
import 'package:productivity/dataservice/preisvergleich.dart';

/// Der Einkauf auf dem Dashboard.
///
/// Sass bis zuletzt auf dem alten `ShoppingListItem` — einem einzigen
/// flachen Zettel, dessen Posten an einer Zutat hingen. Der wurde
/// zwischenzeitlich verwaist: gefuettert hat ihn nur noch der Bon-Scan,
/// waehrend alles andere laengst auf den neuen Listen lief.
///
/// Der „guenstigste Laden" kommt damit auf eine bessere Grundlage. Vorher
/// rechnete er ueber `ShoppingListItemPrice` — Preise, die am Posten
/// hingen und mit ihm verschwanden. Jetzt kommt er aus dem
/// Preisgedaechtnis, das an der Ware haengt und den Einkauf ueberlebt, und
/// er rechnet auf gemeinsamer Grundlage statt Summen ueber verschiedene
/// Warenkoerbe zu vergleichen (siehe [Preisvergleich]).
class ShoppingWidget extends StatelessWidget {
  /// Alle sichtbaren Listen — für die Kopfzeile „3 Zettel".
  final List<Einkaufsliste> listen;

  /// Die Liste, die gezeigt wird: die erste. Mehr als eine auf einer Kachel
  /// zu zeigen hiesse, von jeder zu wenig zu zeigen.
  final Einkaufsliste? gezeigt;

  /// Die Positionen von [gezeigt].
  final List<Einkaufsposition> positionen;

  /// Was der Zettel wo kostet — null, solange die Preise noch laden.
  final Preisvergleich? vergleich;

  final Future<void> Function(Einkaufsposition) beiAbhaken;

  const ShoppingWidget({
    super.key,
    required this.listen,
    required this.gezeigt,
    required this.positionen,
    required this.vergleich,
    required this.beiAbhaken,
  });

  String _menge(double? menge) {
    if (menge == null || menge == 1) return '';
    return menge % 1 == 0 ? menge.toInt().toString() : menge.toString();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    final offen = positionen.where((p) => !p.erledigt).toList();

    return Material(
      color: colors.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => Navigator.pushNamed(context, AppRoutes.einkauf),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.shopping_cart_outlined,
                      color: colors.primary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    // Der Name des Zettels statt eines allgemeinen
                    // „Einkauf": bei mehreren Listen ist sonst nicht zu
                    // sehen, welche hier steht.
                    gezeigt?.name ?? 'Einkauf',
                    style: text.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Spacer(),
                  if (listen.length > 1)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Text('+${listen.length - 1}',
                          style: text.labelSmall
                              ?.copyWith(color: colors.outline)),
                    ),
                  Icon(Icons.chevron_right_rounded, color: colors.outline),
                ],
              ),
              const SizedBox(height: 12),

              if (listen.isEmpty)
                _Ruhe(text: 'Noch keine Einkaufsliste', colors: colors,
                    textTheme: text)
              else if (offen.isEmpty)
                _Ruhe(text: 'Nichts mehr offen', colors: colors,
                    textTheme: text)
              else ...[
                Text(
                  offen.length == 1 ? '1 Posten offen'
                                    : '${offen.length} Posten offen',
                  style: text.bodySmall?.copyWith(color: colors.outline),
                ),
                const SizedBox(height: 12),
                ...offen.take(4).map((p) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 24,
                            height: 24,
                            child: Checkbox(
                              value: false,
                              onChanged: (_) => beiAbhaken(p),
                              visualDensity: VisualDensity.compact,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(p.name,
                                style: text.bodySmall,
                                overflow: TextOverflow.ellipsis),
                          ),
                          Text(_menge(p.menge),
                              style: text.labelSmall
                                  ?.copyWith(color: colors.outline)),
                        ],
                      ),
                    )),
                if (offen.length > 4)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, left: 32),
                    child: Text('+ ${offen.length - 4} weitere',
                        style: text.labelSmall
                            ?.copyWith(color: colors.outline)),
                  ),
                if (vergleich != null && !vergleich!.leer)
                  _Kosten(vergleich: vergleich!, colors: colors, text: text),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Ruhe extends StatelessWidget {
  final String text;
  final ColorScheme colors;
  final TextTheme textTheme;

  const _Ruhe({required this.text, required this.colors,
               required this.textTheme});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.tertiaryContainer.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle_rounded, color: colors.tertiary, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(text,
                  style: textTheme.bodySmall
                      ?.copyWith(color: colors.onTertiaryContainer)),
            ),
          ],
        ),
      );
}

/// Die Kostenzeile.
///
/// Nennt die Grundlage mit. Eine Summe ohne sie waere hier besonders
/// irrefuehrend: auf einer Kachel liest man die Zahl im Vorbeigehen und
/// hat keine Gelegenheit, nach dem Kleingedruckten zu fragen.
class _Kosten extends StatelessWidget {
  final Preisvergleich vergleich;
  final ColorScheme colors;
  final TextTheme text;

  const _Kosten({required this.vergleich, required this.colors,
                 required this.text});

  String _euro(double b) => '${b.toStringAsFixed(2)} €'.replaceFirst('.', ',');

  @override
  Widget build(BuildContext context) {
    final guenstigster = vergleich.laeden.first;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: colors.primaryContainer.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.savings_outlined, size: 14, color: colors.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(guenstigster.laden,
                      style: text.labelSmall
                          ?.copyWith(color: colors.onPrimaryContainer),
                      overflow: TextOverflow.ellipsis),
                ),
                Text(_euro(guenstigster.summe),
                    style: text.labelSmall?.copyWith(
                        color: colors.primary, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 2),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'auf ${vergleich.verglichen} von ${vergleich.gesamt} Posten',
                style: text.labelSmall?.copyWith(color: colors.outline),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
