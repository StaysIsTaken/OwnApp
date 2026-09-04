import 'package:flutter/material.dart';
import 'package:productivity/dataclasses/admin.dart';

/// Welche Rollen ein Benutzer hat — anhaken, fertig.
///
/// Bewusst ohne Rechte-Häkchen: Rechte hängen an der Rolle, nicht am Nutzer.
/// Sonst hätte man am Ende so viele Sonderfälle wie Personen, und keiner
/// wüsste mehr, warum jemand etwas darf.
class UserRolesSheet extends StatefulWidget {
  final AdminBenutzer benutzer;
  final List<Rolle> rollen;

  const UserRolesSheet({
    super.key,
    required this.benutzer,
    required this.rollen,
  });

  @override
  State<UserRolesSheet> createState() => _UserRolesSheetState();
}

class _UserRolesSheetState extends State<UserRolesSheet> {
  late final Set<String> _gewaehlt = {
    for (final r in widget.benutzer.rollen) r.id,
  };

  /// Die Rechte, die sich aus den angehakten Rollen ergeben — zusammengeführt.
  /// Damit sieht man vor dem Speichern, was dabei herauskommt, statt es
  /// hinterher zu erraten.
  Set<String> get _kuenftigeRechte {
    final rechte = <String>{};
    for (final rolle in widget.rollen) {
      if (_gewaehlt.contains(rolle.id)) rechte.addAll(rolle.rechte);
    }
    return rechte;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final rechte = _kuenftigeRechte;
    final alles = rechte.contains('*');

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: scheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.benutzer.anzeigename,
                    style: Theme.of(context).textTheme.titleLarge),
                Text('@${widget.benutzer.username}',
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
              children: [
                for (final rolle in widget.rollen)
                  CheckboxListTile(
                    value: _gewaehlt.contains(rolle.id),
                    onChanged: (an) => setState(() {
                      if (an == true) {
                        _gewaehlt.add(rolle.id);
                      } else {
                        _gewaehlt.remove(rolle.id);
                      }
                    }),
                    title: Text(rolle.name),
                    subtitle: Text(
                      rolle.darfAlles
                          ? 'Alle Rechte'
                          : '${rolle.rechte.length} Rechte'
                              '${rolle.beschreibung == null ? "" : " · ${rolle.beschreibung}"}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    secondary: rolle.istStandard
                        ? Tooltip(
                            message: 'Standard für neue Nutzer',
                            child: Icon(Icons.star_outline,
                                size: 18, color: scheme.primary),
                          )
                        : null,
                  ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    _gewaehlt.isEmpty
                        ? 'Ohne Rolle sieht dieser Nutzer nichts — anmelden '
                          'kann er sich trotzdem.'
                        : alles
                            ? 'Ergibt zusammen: alle Rechte.'
                            : 'Ergibt zusammen ${rechte.length} Rechte.',
                    style: TextStyle(
                      fontSize: 12,
                      color: _gewaehlt.isEmpty ? scheme.error : scheme.outline,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Abbrechen'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () =>
                          Navigator.pop(context, _gewaehlt.toList()),
                      child: const Text('Speichern'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
