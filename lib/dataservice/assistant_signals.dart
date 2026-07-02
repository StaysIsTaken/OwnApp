import 'package:flutter/foundation.dart';

/// App-weiter Signalkanal, um von außen (z.B. Notification-Tap) den Assistenten
/// zu öffnen. Der Zähler wird erhöht; das Overlay lauscht darauf.
class AssistantSignals {
  AssistantSignals._();
  static final AssistantSignals instance = AssistantSignals._();

  /// Wird bei jeder Anforderung eines Journal-Check-ins erhöht.
  final ValueNotifier<int> journalCheckin = ValueNotifier<int>(0);

  void requestJournalCheckin() => journalCheckin.value++;
}
