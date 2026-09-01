/// Die Datenformen, die eine Quelle liefern kann.
///
/// Sie sind der Angelpunkt des ganzen Baukastens: eine Darstellung erklärt,
/// welche Formen sie verarbeiten kann, und die Oberfläche bietet dem Nutzer
/// nur passende Kombinationen an. Dadurch braucht es keine Liste erlaubter
/// Paarungen, die man pflegen müsste — sie ergibt sich.
enum TileShape {
  /// Eine einzelne Zahl, optional mit Zielwert.
  scalar,

  /// Einträge mit Titel und Untertitel.
  list,

  /// Werte über die Zeit (Tag → Zahl).
  series,

  /// Werte je Kategorie (Name → Zahl).
  distribution,
}

/// Ergebnis einer Quelle.
class TileData {
  final TileShape shape;

  /// scalar
  final double? value;
  final double? target;
  final String? unit;

  /// list
  final List<TileListItem> items;

  /// series und distribution: Beschriftung → Wert, Reihenfolge bleibt erhalten
  final Map<String, double> points;

  /// Wird angezeigt, wenn nichts da ist — statt einer leeren Fläche.
  final String emptyHint;

  const TileData.scalar(this.value, {this.target, this.unit})
      : shape = TileShape.scalar,
        items = const [],
        points = const {},
        emptyHint = '';

  const TileData.list(this.items, {this.emptyHint = 'Nichts vorhanden'})
      : shape = TileShape.list,
        value = null,
        target = null,
        unit = null,
        points = const {};

  const TileData.series(this.points, {this.unit, this.emptyHint = 'Keine Daten'})
      : shape = TileShape.series,
        value = null,
        target = null,
        items = const [];

  const TileData.distribution(this.points,
      {this.unit, this.emptyHint = 'Keine Daten'})
      : shape = TileShape.distribution,
        value = null,
        target = null,
        items = const [];

  bool get isEmpty {
    switch (shape) {
      case TileShape.scalar:
        return value == null;
      case TileShape.list:
        return items.isEmpty;
      case TileShape.series:
      case TileShape.distribution:
        return points.isEmpty || points.values.every((v) => v == 0);
    }
  }
}

class TileListItem {
  final String title;
  final String? subtitle;
  final String? trailing;

  const TileListItem(this.title, {this.subtitle, this.trailing});
}
