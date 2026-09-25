import 'package:productivity/dataclasses/planner_entry.dart';
import 'package:productivity/dataclasses/task.dart';

/// Was das Widget auf dem Startbildschirm zeigt — als reine Rechnung.
///
/// **Das Widget fragt nie selbst beim Server.** Es läuft in einem eigenen
/// Prozess, den iOS startet, wann es will, und hätte dort weder ein
/// gültiges Token (das JWT hält 60 Minuten) noch einen Weg, eines zu
/// holen. Stattdessen legt die App bei jedem Erinnerungs-Abgleich einen
/// fertigen Stand in die gemeinsame App Group, und das Widget zeichnet
/// ihn. Derselbe Gedanke wie bei den Erinnerungen: das Gerät weiß vorher
/// Bescheid und braucht im Augenblick selbst kein Netz.
///
/// Weil der Stand veralten kann, trägt er **die nächsten Tage** und nicht
/// nur „jetzt": das Widget wirft Vergangenes selbst weg und rückt nach,
/// auch wenn die App tagelang zu war. Und es zeigt, von wann er ist.
///
/// Zeiten stehen als Sekunden seit 1970, nicht als Text. Ein
/// `toIso8601String()` einer lokalen Zeit hat keine Zone — Swift müsste
/// raten, und ein Termin um neun stünde im Sommer um zehn da.
class WidgetStand {
  WidgetStand._();

  /// Erhöhen, wenn sich die Form ändert. Das Widget zeigt bei einer
  /// Fassung, die es nicht kennt, lieber „App öffnen" als Unsinn.
  static const int fassung = 1;

  /// So weit schaut der Stand voraus.
  static const Duration vorschau = Duration(days: 7);

  /// Mehr passt auch ins mittlere Widget nicht; der Rest wäre Ballast in
  /// jedem Abgleich.
  static const int hoechstensTermine = 12;
  static const int hoechstensAufgaben = 6;

  static Map<String, dynamic> baue({
    required List<Task> aufgaben,
    required List<PlannerEntry> termine,
    required DateTime jetzt,
  }) {
    final bis = jetzt.add(vorschau);

    // Nur Haupttermine: Untertermine sind Punkte eines Termins, keine
    // eigenen — dieselbe Regel wie bei den Erinnerungen. Was schon vorbei
    // ist, fällt weg; was gerade läuft, bleibt stehen.
    final kommende = termine
        .where((t) => t.parentId == null)
        .where((t) => t.endsAt.isAfter(jetzt) && t.scheduledAt.isBefore(bis))
        .toList()
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

    final offen = aufgaben.where((a) => !a.completed).toList()
      ..sort(_nachFaelligkeit);

    return {
      'fassung': fassung,
      'stand': _sekunden(jetzt),
      'termine': [
        for (final t in kommende.take(hoechstensTermine))
          {
            'titel': t.title,
            'beginn': _sekunden(t.scheduledAt),
            'ende': _sekunden(t.endsAt),
            'ganztag': t.istGanztaegig,
            'farbe': t.color,
          },
      ],
      'aufgaben': [
        for (final a in offen.take(hoechstensAufgaben))
          {
            'titel': a.title,
            // Als Tag, nicht als Zeitpunkt: „fällig am Dienstag" ist ein
            // Kalendertag und soll es in jeder Zone bleiben.
            'faellig': a.dueDate == null ? null : _tag(a.dueDate!),
            'prioritaet': a.priority,
          },
      ],
      'aufgabenOffen': offen.length,
    };
  }

  /// Was nach dem Abmelden dasteht — kein Stand des vorigen Kontos.
  static Map<String, dynamic> leer(DateTime jetzt) => {
        'fassung': fassung,
        'stand': _sekunden(jetzt),
        'abgemeldet': true,
        'termine': const [],
        'aufgaben': const [],
        'aufgabenOffen': 0,
      };

  /// Mit Datum vor ohne, früheres vor späterem. Ohne Datum bleibt die
  /// Reihenfolge des Servers.
  static int _nachFaelligkeit(Task a, Task b) {
    final da = a.dueDate, db = b.dueDate;
    if (da == null && db == null) return 0;
    if (da == null) return 1;
    if (db == null) return -1;
    return da.compareTo(db);
  }

  static int _sekunden(DateTime d) => d.millisecondsSinceEpoch ~/ 1000;

  static String _tag(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
