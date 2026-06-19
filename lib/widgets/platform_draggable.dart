import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// True, wenn auf der aktuellen Plattform direktes Ziehen sinnvoll ist
/// (Desktop/Web – dort wird mit Mausrad gescrollt, kein Gesten-Konflikt).
/// Auf Touch-Geräten (Android/iOS) wird Long-Press genutzt, damit das
/// vertikale Scrollen im Kalender erhalten bleibt.
bool get usesDirectDrag {
  if (kIsWeb) return true;
  switch (defaultTargetPlatform) {
    case TargetPlatform.windows:
    case TargetPlatform.macOS:
    case TargetPlatform.linux:
      return true;
    case TargetPlatform.android:
    case TargetPlatform.iOS:
    case TargetPlatform.fuchsia:
      return false;
  }
}

/// Liefert je nach Plattform ein [Draggable] (Desktop/Web) oder
/// [LongPressDraggable] (Touch) mit identischen Parametern.
Widget platformDraggable<T extends Object>({
  required T data,
  required Widget feedback,
  required Widget childWhenDragging,
  required Widget child,
  DragAnchorStrategy dragAnchorStrategy = childDragAnchorStrategy,
}) {
  if (usesDirectDrag) {
    return Draggable<T>(
      data: data,
      dragAnchorStrategy: dragAnchorStrategy,
      feedback: feedback,
      childWhenDragging: childWhenDragging,
      child: child,
    );
  }
  return LongPressDraggable<T>(
    data: data,
    dragAnchorStrategy: dragAnchorStrategy,
    feedback: feedback,
    childWhenDragging: childWhenDragging,
    child: child,
  );
}
