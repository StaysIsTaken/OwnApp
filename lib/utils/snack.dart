import 'package:flutter/material.dart';

/// Kurze Statusmeldung aus einem [State] heraus.
///
/// Nach einem `await` kann das Widget bereits aus dem Baum entfernt sein –
/// `ScaffoldMessenger.of(context)` wirft dann. Der `mounted`-Check hier macht
/// den Aufruf in dem Fall zu einem No-op, statt jede Aufrufstelle einzeln
/// absichern zu müssen.
extension SnackMessenger on State {
  void showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  /// Wie [showSnack], aber in der Fehlerfarbe des Themes.
  void showErrorSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }
}
