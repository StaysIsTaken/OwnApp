import 'package:flutter/foundation.dart';
import 'package:productivity/dataservice/login_service.dart';
import 'package:productivity/dataservice/notification_scheduler.dart';
import 'package:productivity/dataservice/planner_service.dart';
import 'package:productivity/dataservice/task_service.dart';

/// Holt Aufgaben und Termine und meldet die Erinnerungen neu beim
/// Betriebssystem an.
///
/// **Warum es das als eigene Stelle gibt.** Eine Erinnerung entsteht nicht
/// auf dem Server, sondern auf dem Gerät: die App sagt einmal „am Dienstag
/// um neun bitte klingeln", und ab da erledigt das Betriebssystem den Rest —
/// ohne Netz, ohne laufenden Server. Der Preis dafür ist, dass jedes Gerät
/// seinen eigenen Vorrat an vorgemerkten Mitteilungen führt und ihn
/// auffüllen muss.
///
/// Vorher tat das nur der Hintergrundlauf, alle sechs Stunden. Auf Android
/// geht das; auf iOS ist der Hintergrundlauf eine Bitte und kein
/// Versprechen — er kann tagelang ausbleiben. Ein Termin, den ein anderes
/// Gerät angelegt hat, rutschte dann unbemerkt durch.
///
/// Deshalb hängt derselbe Abgleich jetzt an vier Auslösern:
///
/// * Start der App
/// * Rückkehr in den Vordergrund
/// * Meldung `planner_changed` über den WebSocket
/// * der Hintergrundlauf wie bisher
class ErinnerungsAbgleich {
  ErinnerungsAbgleich._();

  /// Kürzester Abstand zwischen zwei Abgleichen.
  ///
  /// Ohne das liefe bei jedem Wechsel zwischen zwei Apps ein Serverabruf —
  /// wer zwischen Kalender und Nachrichten hin- und herspringt, löst sonst
  /// im Minutentakt zwei Abfragen aus. Zwei Minuten sind kurz genug, dass
  /// ein eben angelegter Termin trotzdem ankommt, und lang genug, dass das
  /// Hin und Her nichts kostet.
  static const Duration ruhe = Duration(minutes: 2);

  static DateTime? _zuletzt;
  static Future<int>? _laufend;

  /// Für Tests: den Merker zurücksetzen.
  @visibleForTesting
  static void vergessen() {
    _zuletzt = null;
    _laufend = null;
  }

  @visibleForTesting
  static DateTime? get zuletzt => _zuletzt;

  /// Plant neu ein und gibt zurück, wie viele Mitteilungen angemeldet wurden.
  ///
  /// [erzwingen] übergeht die Ruhezeit — für Auslöser, die einen konkreten
  /// Anlass haben (der Server meldet eine Änderung, der Hintergrundlauf ist
  /// ohnehin selten). Der Rückkehr-in-den-Vordergrund-Fall erzwingt nicht:
  /// er kommt oft und meist ohne Neuigkeit.
  ///
  /// Wirft nie. Ein fehlgeschlagener Abgleich ist kein Grund, dem Nutzer
  /// etwas anzuzeigen — beim nächsten Auslöser wird es erneut versucht, und
  /// die bereits vorgemerkten Mitteilungen bleiben ja bestehen.
  static Future<int> jetzt({bool erzwingen = false}) {
    // Läuft schon einer: auf dessen Ergebnis warten, statt einen zweiten
    // daneben zu stellen. Zwei gleichzeitige Läufe würden sich beim
    // Abräumen und Neusetzen gegenseitig in die Quere kommen.
    final laufend = _laufend;
    if (laufend != null) return laufend;

    final letzter = _zuletzt;
    if (!erzwingen &&
        letzter != null &&
        DateTime.now().difference(letzter) < ruhe) {
      return Future.value(0);
    }

    // Der Merker zeigt auf GENAU das Future, das die Aufrufer bekommen.
    // Vorher stand hier das unverpackte — der erste Aufrufer bekam dann ein
    // anderes Objekt als alle folgenden. Dasselbe Ergebnis, aber ein
    // Unterschied, auf den sich niemand verlassen kann.
    late final Future<int> lauf;
    lauf = _lauf().whenComplete(() {
      if (identical(_laufend, lauf)) _laufend = null;
    });
    _laufend = lauf;
    return lauf;
  }

  static Future<int> _lauf() async {
    try {
      if (!await LoginService.isLoggedIn()) return 0;

      final tasks = await TaskService.loadAll(limit: 200);
      final termine = await PlannerService.loadAll();
      final angemeldet = await NotificationScheduler.rescheduleAll(
        tasks: tasks,
        plannerEntries: termine,
      );
      // Erst nach Erfolg merken: sonst sperrte ein fehlgeschlagener Lauf
      // den nächsten für zwei Minuten aus.
      _zuletzt = DateTime.now();
      return angemeldet;
    } catch (_) {
      return 0;
    }
  }
}
