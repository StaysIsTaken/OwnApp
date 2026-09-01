import 'package:flutter/material.dart';
import 'package:productivity/widgets/platform_draggable.dart';

/// Umhüllt eine Dashboard-Kachel, damit sie per Drag & Drop umsortiert
/// werden kann.
///
/// Nutzt `platformDraggable`: auf Desktop und Web zieht man direkt, auf
/// Touch-Geräten erst nach langem Drücken. Sonst würde jeder Wischversuch
/// zum Scrollen stattdessen eine Kachel aufnehmen.
class ReorderableTile extends StatefulWidget {
  /// Schlüssel dieser Kachel (z.B. 'tasks').
  final String tileKey;
  final Widget child;

  /// Wird gerufen, wenn `from` auf diese Kachel fallen gelassen wurde.
  final void Function(String from, String to) onReorder;

  /// Solange false, verhält sich die Kachel wie vorher — kein Ziehen.
  final bool enabled;

  const ReorderableTile({
    super.key,
    required this.tileKey,
    required this.child,
    required this.onReorder,
    this.enabled = true,
  });

  @override
  State<ReorderableTile> createState() => _ReorderableTileState();
}

class _ReorderableTileState extends State<ReorderableTile> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    final colors = Theme.of(context).colorScheme;

    return DragTarget<String>(
      // Auf sich selbst fallen lassen ergibt keine Änderung.
      onWillAcceptWithDetails: (d) {
        final ok = d.data != widget.tileKey;
        if (ok && !_hovering) setState(() => _hovering = true);
        return ok;
      },
      onLeave: (_) {
        if (_hovering) setState(() => _hovering = false);
      },
      onAcceptWithDetails: (d) {
        setState(() => _hovering = false);
        widget.onReorder(d.data, widget.tileKey);
      },
      builder: (context, candidate, rejected) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _hovering ? colors.primary : Colors.transparent,
              width: 2,
            ),
          ),
          child: platformDraggable<String>(
            data: widget.tileKey,
            // Beim Ziehen eine verkleinerte, angehobene Kopie zeigen.
            feedback: Material(
              color: Colors.transparent,
              child: Opacity(
                opacity: 0.9,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 340),
                  child: Transform.scale(scale: 0.95, child: widget.child),
                ),
              ),
            ),
            // Der Platz bleibt sichtbar, damit das Raster nicht springt.
            childWhenDragging: Opacity(opacity: 0.25, child: widget.child),
            child: widget.child,
          ),
        );
      },
    );
  }
}
