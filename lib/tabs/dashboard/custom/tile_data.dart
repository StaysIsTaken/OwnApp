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

  /// Termine mit Anfang und Ende. Anders als `list` behalten sie ihre
  /// Lage in der Zeit — nur damit lässt sich ein Wochenraster zeichnen.
  schedule,
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

  /// schedule
  final List<TileScheduleItem> schedule;

  /// Auf welchen Zeitraum sich die Termine beziehen – der Montag der Woche,
  /// der Erste des Monats.
  ///
  /// Ohne das zeichnete die Ansicht immer den *heutigen* Zeitraum, während
  /// die Quelle einen *versetzten* liefert: bei „nächste Woche" fielen alle
  /// Termine aus dem Raster und die Kachel blieb leer. Die Quelle weiß, was
  /// sie ausgewählt hat — also sagt sie es.
  final DateTime? anker;

  /// Wird angezeigt, wenn nichts da ist — statt einer leeren Fläche.
  final String emptyHint;

  const TileData.scalar(this.value, {this.target, this.unit})
      : anker = null,
        shape = TileShape.scalar,
        items = const [],
        points = const {},
        body = null,
        footnote = null,
        schedule = const [],
        emptyHint = '';

  const TileData.schedule(this.schedule,
      {this.anker, this.emptyHint = 'Nichts geplant'})
      : shape = TileShape.schedule,
        value = null,
        target = null,
        unit = null,
        items = const [],
        points = const {},
        body = null,
        footnote = null;

  const TileData.text(this.body, {this.footnote, this.emptyHint = 'Noch nichts'})
      : anker = null,
        shape = TileShape.text,
        schedule = const [],
        value = null,
        target = null,
        unit = null,
        items = const [],
        points = const {};

  const TileData.list(this.items, {this.emptyHint = 'Nichts vorhanden'})
      : anker = null,
        shape = TileShape.list,
        body = null,
        footnote = null,
        schedule = const [],
        value = null,
        target = null,
        unit = null,
        points = const {};

  const TileData.series(this.points, {this.unit, this.emptyHint = 'Keine Daten'})
      : anker = null,
        shape = TileShape.series,
        body = null,
        footnote = null,
        schedule = const [],
        value = null,
        target = null,
        items = const [];

  const TileData.distribution(this.points,
      {this.unit, this.emptyHint = 'Keine Daten'})
      : anker = null,
        shape = TileShape.distribution,
        body = null,
        footnote = null,
        schedule = const [],
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
      case TileShape.schedule:
        return schedule.isEmpty;
    }
  }
}

class TileListItem {
  final String title;
  final String? subtitle;
  final String? trailing;

  const TileListItem(this.title, {this.subtitle, this.trailing});
}

/// Ein Termin mit seiner Lage in der Zeit.
///
/// Eigene Klasse statt [TileListItem]: für ein Wochenraster braucht es
/// Anfang und Ende als echte Zeitpunkte, nicht als Text.
class TileScheduleItem {
  final String title;
  final DateTime start;
  final DateTime end;

  /// Farbe des Kalenders, aus dem der Termin stammt (#RRGGBB).
  final String? color;

  /// Woher er kommt – für die Legende, wenn mehrere Kalender laufen.
  final String? source;

  /// Ganztägig: wird über dem Raster gezeigt statt darin.
  final bool allDay;

  const TileScheduleItem({
    required this.title,
    required this.start,
    required this.end,
    this.color,
    this.source,
    this.allDay = false,
  });
}
