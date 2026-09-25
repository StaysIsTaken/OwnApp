import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'package:productivity/dataclasses/planner_entry.dart';
import 'package:productivity/dataclasses/task.dart';
import 'package:productivity/dataservice/widget_stand.dart';

/// Reicht den Stand an das Widget auf dem iOS-Startbildschirm weiter.
///
/// Was darin steht, rechnet [WidgetStand]. Hier geht es nur um den Weg:
/// in die App Group schreiben, die sich App und Widget teilen, und das
/// Widget neu zeichnen lassen.
///
/// **Nur iOS.** Ein Android-Widget gibt es noch nicht, im Browser gibt es
/// keinen Startbildschirm. Ohne diese Weiche liefe jeder Aufruf dort in
/// eine `MissingPluginException`.
///
/// **Wirft nie.** Ein Widget, das nicht aktualisiert wird, zeigt den
/// letzten Stand samt Uhrzeit. Das ist kein Grund, einen Erinnerungs-
/// Abgleich scheitern zu lassen.
class WidgetBruecke {
  WidgetBruecke._();

  /// Muss mit `appGroup` in `ios/OwnAppWidget/OwnAppWidget.swift` und
  /// mit beiden `.entitlements`-Dateien übereinstimmen.
  static const String appGroup = 'group.de.jpanft.homeapp';

  /// Der `kind` des Widgets in Swift.
  static const String iosName = 'OwnAppWidget';

  /// Der Schlüssel in der App Group.
  static const String schluessel = 'ownapp_widget_stand';

  static bool get _aktiv =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  static Future<void> aktualisieren({
    required List<Task> aufgaben,
    required List<PlannerEntry> termine,
  }) =>
      _schreiben(WidgetStand.baue(
        aufgaben: aufgaben,
        termine: termine,
        jetzt: DateTime.now(),
      ));

  /// Nach dem Abmelden: sonst stünden die Termine des vorigen Kontos
  /// weiter auf dem Startbildschirm — auch für den, der sich als
  /// Nächstes anmeldet.
  static Future<void> leeren() => _schreiben(WidgetStand.leer(DateTime.now()));

  static Future<void> _schreiben(Map<String, dynamic> stand) async {
    if (!_aktiv) return;
    try {
      await HomeWidget.setAppGroupId(appGroup);
      await HomeWidget.saveWidgetData<String>(schluessel, jsonEncode(stand));
      await HomeWidget.updateWidget(iOSName: iosName);
    } catch (e) {
      debugPrint('Widget nicht aktualisiert: $e');
    }
  }
}
