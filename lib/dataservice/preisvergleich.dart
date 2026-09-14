import 'package:productivity/dataclasses/einkauf.dart';

/// Was ein Laden für die verglichenen Posten kostet.
class Ladenkosten {
  final String laden;
  final double summe;

  const Ladenkosten({required this.laden, required this.summe});
}

/// „Dieser Zettel kostet bei Aldi 34 €, bei Rewe 39 €."
///
/// Das Preisgedächtnis weiß, wo was günstig war — nur sah man es bisher
/// nirgends. Die Rechnung ist einfach; schwierig ist, sie **nicht**
/// irreführend zu machen.
///
/// ## Die Falle: ungleiche Abdeckung
///
/// Kennt man von Aldi drei Preise und von Rewe fünfzehn, ist Aldis Summe
/// kleiner — nicht weil es billiger ist, sondern weil weniger drin steckt.
/// Nebeneinandergestellt sähe das aus wie ein Preisvorteil und wäre eine
/// Lüge aus wahren Zahlen.
///
/// Deshalb wird auf **gemeinsamer Grundlage** gerechnet: nur Posten, für
/// die JEDER verglichene Laden einen Preis hat. Was übrig bleibt, wird
/// gezählt und genannt, statt still unter den Tisch zu fallen.
///
/// ## Die zweite Grenze
///
/// Menge mal Preis stimmt nur, wenn der gemerkte Preis für ein Stück galt.
/// Stand er für „500 g", wird er hier trotzdem mit der Postenmenge
/// multipliziert — das Preisgedächtnis führt keine Einheiten mit, die sich
/// verlässlich umrechnen ließen. Ein Schätzwert, und er ist als solcher
/// gekennzeichnet.
class Preisvergleich {
  /// Je Laden die Summe, günstigster zuerst.
  final List<Ladenkosten> laeden;

  /// Auf wie vielen Posten die Rechnung steht.
  final int verglichen;

  /// Wie viele offene Posten die Liste hat.
  final int gesamt;

  /// Posten, für die kein Laden einen Preis kennt.
  final List<String> ohnePreis;

  /// Posten, die nur manche Läden führen — sie fielen aus der Rechnung,
  /// damit die Summen vergleichbar bleiben.
  final List<String> nichtUeberall;

  const Preisvergleich({
    required this.laeden,
    required this.verglichen,
    required this.gesamt,
    required this.ohnePreis,
    required this.nichtUeberall,
  });

  bool get leer => laeden.isEmpty || verglichen == 0;

  /// Wie viel der günstigste Laden spart.
  double get ersparnis =>
      laeden.length < 2 ? 0 : laeden.last.summe - laeden.first.summe;

  /// Rechnet den Vergleich.
  ///
  /// [preise] bildet die **kleingeschriebene** Bezeichnung auf die
  /// bekannten Preise ab — so, wie das Preisgedächtnis sie führt.
  static Preisvergleich rechne({
    required List<Einkaufsposition> positionen,
    required Map<String, List<Warenpreis>> preise,
  }) {
    final offen = positionen.where((p) => !p.erledigt).toList();

    final ohnePreis = <String>[];
    // Posten -> Laden -> Preis für genau diesen Posten.
    final bekannt = <Einkaufsposition, Map<String, double>>{};

    for (final posten in offen) {
      final zurWare = preise[posten.name.trim().toLowerCase()] ?? const [];
      if (zurWare.isEmpty) {
        ohnePreis.add(posten.name);
        continue;
      }
      final menge = posten.menge == null || posten.menge! <= 0
          ? 1.0
          : posten.menge!;
      // Bei mehreren Einträgen je Laden gewinnt der günstigste. Das
      // Gedächtnis liefert ohnehin nur den jüngsten je Laden, aber darauf
      // soll sich diese Rechnung nicht verlassen müssen.
      final jeLaden = <String, double>{};
      for (final p in zurWare) {
        final kosten = p.preis * menge;
        final bisher = jeLaden[p.shopName];
        if (bisher == null || kosten < bisher) jeLaden[p.shopName] = kosten;
      }
      bekannt[posten] = jeLaden;
    }

    if (bekannt.isEmpty) {
      return Preisvergleich(
        laeden: const [], verglichen: 0, gesamt: offen.length,
        ohnePreis: ohnePreis, nichtUeberall: const [],
      );
    }

    // Verglichen wird auf gemeinsamer Grundlage: nur Posten, für die JEDER
    // vorkommende Laden einen Preis hat. Alles andere fiele einem Laden zur
    // Last, der die Ware schlicht nicht im Gedächtnis hat — und das ist
    // kein Preisvorteil des anderen.
    //
    // Der Preis dieser Ehrlichkeit: ein einzelner exotischer Posten, den
    // nur ein Laden führt, verkleinert die Grundlage für alle. Deshalb wird
    // er in [nichtUeberall] genannt, statt zu verschwinden.
    final alleLaeden = <String>{for (final je in bekannt.values) ...je.keys};

    final gemeinsam = <Map<String, double>>[];
    final nichtUeberall = <String>[];
    for (final eintrag in bekannt.entries) {
      if (alleLaeden.every(eintrag.value.containsKey)) {
        gemeinsam.add(eintrag.value);
      } else {
        nichtUeberall.add(eintrag.key.name);
      }
    }

    if (gemeinsam.isEmpty) {
      return Preisvergleich(
        laeden: const [], verglichen: 0, gesamt: offen.length,
        ohnePreis: ohnePreis, nichtUeberall: nichtUeberall,
      );
    }

    return _summieren(
      gemeinsam, alleLaeden.toList(),
      verglichen: gemeinsam.length, gesamt: offen.length,
      ohnePreis: ohnePreis, nichtUeberall: nichtUeberall,
    );
  }

  static Preisvergleich _summieren(
    List<Map<String, double>> jePosten,
    List<String> laeden, {
    required int verglichen,
    required int gesamt,
    required List<String> ohnePreis,
    required List<String> nichtUeberall,
  }) {
    final summen = <String, double>{for (final l in laeden) l: 0};
    for (final posten in jePosten) {
      for (final laden in laeden) {
        summen[laden] = summen[laden]! + (posten[laden] ?? 0);
      }
    }
    final zeilen = [
      for (final e in summen.entries) Ladenkosten(laden: e.key, summe: e.value),
    ]..sort((a, b) => a.summe.compareTo(b.summe));

    return Preisvergleich(
      laeden: zeilen, verglichen: verglichen, gesamt: gesamt,
      ohnePreis: ohnePreis, nichtUeberall: nichtUeberall,
    );
  }
}
