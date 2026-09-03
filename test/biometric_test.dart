import 'package:flutter_test/flutter_test.dart';
import 'package:productivity/dataservice/biometric_service.dart';

void main() {
  const server = 'https://api.example.de/api';

  GemerkterZugang zugang({
    String benutzer = 'anna',
    String passwort = 'geheim',
    String s = server,
  }) =>
      GemerkterZugang(benutzername: benutzer, passwort: passwort, server: s);

  group('Wann der Anmeldeknopf erscheint', () {
    test('mit passenden gemerkten Daten', () {
      expect(
        BiometricService.anbieten(
            gemerkt: zugang(), aktuellerServer: server),
        isTrue,
      );
    });

    test('ohne gemerkte Daten nicht', () {
      expect(
        BiometricService.anbieten(gemerkt: null, aktuellerServer: server),
        isFalse,
      );
    });

    test('nach einem Serverwechsel nicht', () {
      // Die Zugangsdaten gehören zum alten Server. Sie dort stillschweigend
      // zu probieren wäre das Falsche – und der Knopf wäre ein Versprechen,
      // das er nicht halten kann.
      expect(
        BiometricService.anbieten(
          gemerkt: zugang(s: 'https://anderer.de/api'),
          aktuellerServer: server,
        ),
        isFalse,
      );
    });

    test('bei leerem Eintrag nicht', () {
      // Kann passieren, wenn die Keychain zurückgesetzt wurde.
      expect(
        BiometricService.anbieten(
            gemerkt: zugang(passwort: ''), aktuellerServer: server),
        isFalse,
      );
      expect(
        BiometricService.anbieten(
            gemerkt: zugang(benutzer: ''), aktuellerServer: server),
        isFalse,
      );
    });

    test('ein alter Eintrag ohne Serververmerk zählt nicht', () {
      // Aus einer früheren Fassung: dann lieber einmal tippen, als raten.
      expect(
        BiometricService.anbieten(
            gemerkt: zugang(s: ''), aktuellerServer: server),
        isFalse,
      );
    });
  });

  group('Plattform', () {
    test('im Browser gibt es das nicht', () {
      // Die Tests laufen auf der VM, nicht im Browser – hier geht es nur
      // darum, dass die Abfrage nicht wirft.
      expect(() => BiometricService.plattformTauglich, returnsNormally);
    });
  });
}
