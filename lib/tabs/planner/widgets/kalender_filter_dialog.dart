import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:productivity/provider/planner_provider.dart';

/// Auswahl, welche Kalender die Ansicht zeigt.
///
/// Dasselbe, was „zeige nur den Arbeitskalender an" per Sprache tut — nur
/// zum Antippen. Beide schreiben in [PlannerProvider.zeigeNur]; es gibt
/// keinen zweiten Filter, der danebenherlaufen könnte.
class KalenderFilterDialog extends StatefulWidget {
  const KalenderFilterDialog({super.key});

  @override
  State<KalenderFilterDialog> createState() => _KalenderFilterDialogState();
}

class _KalenderFilterDialogState extends State<KalenderFilterDialog> {
  /// Die Auswahl im Dialog. Leer heißt hier „alle" — genau wie im Provider.
  late Set<int> _gewaehlt;

  @override
  void initState() {
    super.initState();
    _gewaehlt = {...?context.read<PlannerProvider>().sichtbareKalender};
  }

  @override
  Widget build(BuildContext context) {
    final planer = context.watch<PlannerProvider>();
    final kalender = planer.kalender;

    return AlertDialog(
      title: const Text('Kalender anzeigen'),
      content: SizedBox(
        width: 360,
        child: kalender.isEmpty
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text('Keine Kalender gefunden.'),
              )
            : ListView(
                shrinkWrap: true,
                children: [
                  CheckboxListTile(
                    value: _gewaehlt.isEmpty,
                    title: const Text('Alle'),
                    onChanged: (an) {
                      if (an == true) setState(() => _gewaehlt.clear());
                    },
                  ),
                  const Divider(height: 1),
                  for (final k in kalender)
                    CheckboxListTile(
                      value: _gewaehlt.isEmpty || _gewaehlt.contains(k.id),
                      secondary: Icon(Icons.circle,
                          size: 14, color: _farbe(k.color)),
                      title: Text(k.name),
                      // Der Besitzer steht dabei, weil die eigenen Kalender
                      // anfangs alle „Mein Kalender" heißen.
                      subtitle: k.ownerName.isEmpty ? null : Text(k.ownerName),
                      onChanged: (an) => setState(() {
                        // Aus „alle" heraus bedeutet ein Klick: nur dieser.
                        if (_gewaehlt.isEmpty) {
                          _gewaehlt = {k.id};
                          return;
                        }
                        if (an == true) {
                          _gewaehlt.add(k.id);
                        } else {
                          _gewaehlt.remove(k.id);
                        }
                      }),
                    ),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: () {
            planer.zeigeNur(_gewaehlt);
            Navigator.pop(context);
          },
          child: const Text('Übernehmen'),
        ),
      ],
    );
  }

  static Color _farbe(String hex) {
    final wert = int.tryParse(hex.replaceFirst('#', ''), radix: 16);
    return wert == null ? Colors.blue : Color(0xFF000000 | wert);
  }
}
