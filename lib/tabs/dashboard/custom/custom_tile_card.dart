import 'package:flutter/material.dart';
import 'package:productivity/provider/permission_provider.dart';
import 'package:productivity/tabs/dashboard/custom/tile_catalog.dart';
import 'package:productivity/tabs/dashboard/custom/tile_spec.dart';
import 'package:productivity/tabs/dashboard/custom/tile_views.dart';
import 'package:provider/provider.dart';

/// Stellt eine selbst zusammengestellte Kachel dar.
///
/// Kennt der Client eine Quelle oder Darstellung nicht (etwa weil die Kachel
/// auf einem neueren Gerät angelegt wurde), wird ein Hinweis gezeigt statt
/// eines Absturzes.
class CustomTileCard extends StatelessWidget {
  final CustomTile tile;
  final DashboardData data;
  final bool arranging;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  /// Wird gerufen, nachdem eine Kachelaktion wirklich etwas angelegt hat —
  /// die Seite lädt dann neu, damit der neue Termin sofort im Raster steht.
  /// Ein abgebrochener Dialog löst nichts aus.
  final VoidCallback? onGeaendert;

  const CustomTileCard({
    super.key,
    required this.tile,
    required this.data,
    this.arranging = false,
    this.onEdit,
    this.onDelete,
    this.onGeaendert,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    final source = TileCatalog.byKey(tile.source);
    final view = TileViews.byKey(tile.view);

    if (source == null || view == null) {
      return _Rahmen(
        titel: tile.title ?? 'Unbekannte Kachel',
        arranging: arranging,
        onEdit: null,
        onDelete: onDelete,
        child: Text(
          'Diese Kachel kennt die App nicht. Vermutlich in einer neueren '
          'Version angelegt.',
          style: text.bodySmall?.copyWith(color: colors.onSurfaceVariant),
        ),
      );
    }

    final ergebnis = source.build(data, tile.params, tile.filters);

    // Im Bearbeitungsmodus keine Aktion: dort wird gezogen und geändert,
    // nicht eingetragen. Und ohne das Recht bleibt sie weg — Ausblenden
    // ist Höflichkeit, geprüft wird im Backend.
    final aktion = source.aktion;
    final zeigeAktion = aktion != null &&
        !arranging &&
        (aktion.recht == null ||
            context.watch<PermissionProvider>().darf(aktion.recht!));

    return _Rahmen(
      titel: tile.title?.isNotEmpty == true ? tile.title! : source.label,
      arranging: arranging,
      onEdit: onEdit,
      onDelete: onDelete,
      aktion: zeigeAktion ? aktion : null,
      onAktion: zeigeAktion
          ? () async {
              final angelegt = await aktion.ausfuehren(context);
              if (angelegt) onGeaendert?.call();
            }
          : null,
      // Im Bearbeitungsmodus nicht navigieren – dort wird gezogen.
      onTap: (!arranging && source.route != null)
          ? () => Navigator.pushNamed(context, source.route!)
          : null,
      filterCount: tile.filters.length,
      child: ergebnis.isEmpty
          ? Text(
              ergebnis.emptyHint,
              style: text.bodySmall?.copyWith(color: colors.onSurfaceVariant),
            )
          : view.build(context, ergebnis),
    );
  }
}

class _Rahmen extends StatelessWidget {
  final String titel;
  final Widget child;
  final bool arranging;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onTap;
  final int filterCount;
  final TileAktion? aktion;
  final VoidCallback? onAktion;

  const _Rahmen({
    required this.titel,
    required this.child,
    required this.arranging,
    this.onEdit,
    this.onDelete,
    this.onTap,
    this.filterCount = 0,
    this.aktion,
    this.onAktion,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    titel,
                    style: text.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (filterCount > 0 && !arranging)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Tooltip(
                      message: filterCount == 1
                          ? '1 Filter aktiv'
                          : '$filterCount Filter aktiv',
                      child: Icon(Icons.filter_alt_outlined,
                          size: 16, color: colors.onSurfaceVariant),
                    ),
                  ),
                // Vor dem Pfeil: die Aktion ist das, was man hier tun kann,
                // der Pfeil führt nur woandershin.
                if (aktion != null && onAktion != null)
                  IconButton(
                    icon: Icon(aktion!.icon, size: 20),
                    tooltip: '${aktion!.label} anlegen',
                    visualDensity: VisualDensity.compact,
                    color: colors.primary,
                    onPressed: onAktion,
                  ),
                if (onTap != null && !arranging)
                  Icon(Icons.chevron_right_rounded,
                      size: 18, color: colors.outline),
                if (arranging) ...[
                  if (onEdit != null)
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      tooltip: 'Kachel bearbeiten',
                      visualDensity: VisualDensity.compact,
                      onPressed: onEdit,
                    ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, size: 18, color: colors.error),
                    tooltip: 'Kachel entfernen',
                    visualDensity: VisualDensity.compact,
                    onPressed: onDelete,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
      ),
    );
  }
}
