import 'package:flutter/material.dart';
import 'package:productivity/dataservice/haushalt_sicht.dart';
import 'package:productivity/provider/haushalt_provider.dart';
import 'package:provider/provider.dart';

/// „Alles / Meins / Unseres" — der Kopf jeder haushaltsfähigen Seite.
///
/// **Und er verschwindet vollständig, wenn man in keinem Haushalt ist.**
/// Das ist das Leitprinzip in einer Zeile Code — und die Stelle, an der
/// es kaputtgeht, wenn jemand sie vergisst. Deshalb steht die Regel
/// nicht hier, sondern in [Haushaltssicht.zeigtUmschaltung]: dort ist
/// sie prüfbar, hier wäre sie es nicht.
///
/// Ein `SizedBox.shrink` und kein `Visibility`: der Platz soll auch weg
/// sein, nicht nur der Inhalt.
class BereichsUmschalter extends StatelessWidget {
  final Bereich bereich;
  final ValueChanged<Bereich> onWechsel;

  /// Was im mittleren Knopf steht — „Meine Rezepte" liest sich besser
  /// als „Meins", wenn daneben „Unsere Rezepte" stünde.
  final String? meinsTitel;
  final String? unseresTitel;

  const BereichsUmschalter({
    super.key,
    required this.bereich,
    required this.onWechsel,
    this.meinsTitel,
    this.unseresTitel,
  });

  @override
  Widget build(BuildContext context) {
    final haushalt = context.watch<HaushaltProvider>().haushalt;
    if (!Haushaltssicht.zeigtUmschaltung(haushalt)) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: SizedBox(
        width: double.infinity,
        child: SegmentedButton<Bereich>(
          segments: [
            const ButtonSegment(
              value: Bereich.alles,
              label: Text('Alles'),
            ),
            ButtonSegment(
              value: Bereich.meins,
              label: Text(meinsTitel ?? Bereich.meins.titel),
            ),
            ButtonSegment(
              value: Bereich.unseres,
              label: Text(unseresTitel ?? Bereich.unseres.titel),
            ),
          ],
          selected: {bereich},
          showSelectedIcon: false,
          onSelectionChanged: (auswahl) => onWechsel(auswahl.first),
        ),
      ),
    );
  }
}
