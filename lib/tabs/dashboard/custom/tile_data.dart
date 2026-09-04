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

  /// Freier Text – vom Nutzer geschrieben oder aus einer Sammlung geholt.
  /// Passt in keine der übrigen Formen: es gibt nichts zu rechnen und
  /// nichts zu zeichnen, nur etwas zu lesen.
  text,
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

  /// text
  final String? body;

  /// Kleine Zeile unter dem Text – Quelle, Datum, Urheber.
  final String? footnote;

  /// Wird angezeigt, wenn nichts da ist — statt einer leeren Fläche.
  final String emptyHint;

  const TileData.scalar(this.value, {this.target, this.unit})
      : shape = TileShape.scalar,
        items = const [],
        points = const {},
        body = null,
        footnote = null,
        emptyHint = '';

  const TileData.text(this.body, {this.footnote, this.emptyHint = 'Noch nichts'})
      : shape = TileShape.text,
        value = null,
        target = null,
        unit = null,
        items = const [],
        points = const {};

  const TileData.list(this.items, {this.emptyHint = 'Nichts vorhanden'})
      : shape = TileShape.list,
        body = null,
        footnote = null,
        value = null,
        target = null,
        unit = null,
        points = const {};

  const TileData.series(this.points, {this.unit, this.emptyHint = 'Keine Daten'})
      : shape = TileShape.series,
        body = null,
        footnote = null,
        value = null,
        target = null,
        items = const [];

  const TileData.distribution(this.points,
      {this.unit, this.emptyHint = 'Keine Daten'})
      : shape = TileShape.distribution,
        body = null,
        footnote = null,
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
      case TileShape.text:
        return body == null || body!.trim().isEmpty;
    }
  }
}

class TileListItem {
  final String title;
  final String? subtitle;
  final String? trailing;

  const TileListItem(this.title, {this.subtitle, this.trailing});
}
