// Warum nach "Hey Jarvis" nur 80 ms Ton ankamen.
//
// `record` fordert beim Start einer Aufnahme den Audio-Fokus an und haelt
// sie an, sobald jemand anderes ihn nimmt -- still, ohne Fehler, und mit
// der Vorgabe `pause` fuer immer. Genau das tat das Bestaetigungs-Pling,
// das direkt nach dem Start der Aufnahme abgespielt wird. Die Aufnahme
// bekam ein einziges Stueck und dann nichts mehr.
//
// Auf dem Geraet sieht man davon nur "Nichts verstanden". Dieser Test
// haelt fest, dass die Aufnahme den Fokus gar nicht erst beansprucht.
import 'package:flutter_test/flutter_test.dart';
import 'package:productivity/dataservice/transcription_service.dart';
import 'package:record/record.dart';

void main() {
  test('eine Aufnahme laesst sich von keinem Ton anhalten', () {
    expect(TranscriptionService.aufnahmeOhneFokus, AudioInterruptionMode.none);
  });
}
