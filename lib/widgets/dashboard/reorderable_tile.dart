import 'package:flutter/material.dart';
import 'package:productivity/widgets/platform_draggable.dart';

/// Umhüllt eine Dashboard-Karte, damit sie umsortiert werden kann.
///
/// **Gezogen wird am Griff**, nicht an der Karte. Die drei Striche oben
/// rechts erscheinen nur im Bearbeitungsmodus. Vorher war die ganze Karte
/// ziehbar — dabei verrutscht beim Antippen leicht etwas, und man sieht der
/// Karte nicht an, dass sie sich bewegen lässt.
///
/// Fallen lassen kann man dagegen überall auf der Zielkarte: das Ziel muss
/// leicht zu treffen sein, die Quelle bewusst gegriffen.
class ReorderableTile extends StatefulWidget {
  /// Schlüssel dieser Karte (z.B. 'tasks').
  final String tileKey;
  final Widget child;

  /// Wird gerufen, wenn `from` auf diese Karte fallen gelassen wurde.
  final void Function(String from, String to) onReorder;

  /// Solange false, verhält sich die Karte wie vorher — kein Griff, kein Ziehen.
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
          child: Stack(
            children: [
              widget.child,
              Positioned(top: 6, right: 6, child: _griff(colors)),
            ],
          ),
        );
      },
    );
  }

  /// Die drei Striche. Nur sie nehmen die Karte auf.
  Widget _griff(ColorScheme colors) {
    final knopf = Material(
      color: colors.primary,
      shape: const CircleBorder(),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(Icons.drag_indicator, size: 20, color: colors.onPrimary),
      ),
    );

    return Tooltip(
      message: usesDirectDrag
          ? 'Zum Verschieben hier ziehen'
          : 'Gedrückt halten und ziehen',
      child: MouseRegion(
        cursor: SystemMouseCursors.grab,
        child: platformDraggable<String>(
          data: widget.tileKey,
          // Beim Ziehen die ganze Karte als verkleinerte Kopie zeigen –
          // nicht nur den Griff, sonst weiss man nicht, was man bewegt.
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
          childWhenDragging: Opacity(opacity: 0.4, child: knopf),
          child: knopf,
        ),
      ),
    );
  }
}
