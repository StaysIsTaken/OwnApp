import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:productivity/dataservice/api_client.dart';

/// Anmelden per Face ID, Touch ID oder Fingerabdruck.
///
/// **Was hier wirklich passiert**, damit niemand sich täuscht: Face ID ist
/// keine Anmeldung gegenüber dem Server. Es ist eine Prüfung auf dem Gerät —
/// „ist das der Besitzer dieses Telefons?". Der Server erfährt davon nichts.
///
/// Deshalb: die Zugangsdaten liegen in der Keychain (iOS) bzw. im Keystore
/// (Android), und erst wenn die Prüfung zustimmt, werden sie herausgegeben
/// und ganz normal an `/auth/login` geschickt. Face ID ersetzt also das
/// **Tippen**, nicht das Passwort.
///
/// Bewusst so und nicht mit einem gespeicherten Token: das Zugriffstoken
/// läuft nach einer Stunde ab: die Anmeldung per Gesicht hielte damit genau
/// eine Stunde. Langlebige Sitzungen bräuchten ein Refresh-Token im Backend
/// — das ist ein eigenes Vorhaben.
class BiometricService {
  BiometricService._();

  static const _speicher = FlutterSecureStorage(
    iOptions: IOSOptions(
      // Nur auf diesem Gerät, und erst nach dem ersten Entsperren. Ohne
      // `ThisDeviceOnly` wanderten die Zugangsdaten in die iCloud-Keychain
      // und damit auf Geräte, die der Nutzer hier nie freigegeben hat.
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const _schluessel = 'biometrie_zugang';
  static final _auth = LocalAuthentication();

  /// Gibt es das auf dieser Plattform überhaupt?
  static bool get plattformTauglich {
    if (kIsWeb) return false;
    return Platform.isIOS || Platform.isAndroid;
  }

  /// Ist ein Verfahren eingerichtet (Gesicht, Finger, notfalls Geräte-Code)?
  static Future<bool> verfuegbar() async {
    if (!plattformTauglich) return false;
    try {
      return await _auth.isDeviceSupported() &&
          await _auth.canCheckBiometrics;
    } catch (_) {
      return false;
    }
  }

  /// „Face ID", „Touch ID", „Fingerabdruck" – für die Beschriftung.
  static Future<String> bezeichnung() async {
    if (!plattformTauglich) return 'Biometrie';
    try {
      final arten = await _auth.getAvailableBiometrics();
      if (arten.contains(BiometricType.face)) {
        return Platform.isIOS ? 'Face ID' : 'Gesichtserkennung';
      }
      if (arten.contains(BiometricType.fingerprint) ||
          arten.contains(BiometricType.strong)) {
        return Platform.isIOS ? 'Touch ID' : 'Fingerabdruck';
      }
    } catch (_) {}
    return 'Biometrie';
  }

  /// Fragt das Gerät. `true` heißt: der Besitzer hat zugestimmt.
  static Future<bool> pruefen(String grund) async {
    if (!plattformTauglich) return false;
    try {
      return await _auth.authenticate(
        localizedReason: grund,
        options: const AuthenticationOptions(
          // Geräte-Code als Rückweg: sonst kommt niemand mehr hinein, dessen
          // Gesichtserkennung gerade nicht mitspielt (Maske, Dunkelheit).
          biometricOnly: false,
          stickyAuth: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }

  // ── Gespeicherte Zugangsdaten ──────────────────────────────────────────

  static Future<void> merken({
    required String benutzername,
    required String passwort,
  }) async {
    await _speicher.write(
      key: _schluessel,
      value: jsonEncode({
        'benutzername': benutzername,
        'passwort': passwort,
        // Der Server gehört dazu: Zugangsdaten für den einen Server sind bei
        // einem anderen wertlos, und stillschweigend dort zu probieren wäre
        // das Falsche.
        'server': ApiClient.baseUrl,
      }),
    );
  }

  static Future<GemerkterZugang?> gemerkt() async {
    try {
      final roh = await _speicher.read(key: _schluessel);
      if (roh == null) return null;
      final d = jsonDecode(roh) as Map<String, dynamic>;
      return GemerkterZugang(
        benutzername: d['benutzername'] as String,
        passwort: d['passwort'] as String,
        server: d['server'] as String? ?? '',
      );
    } catch (_) {
      // Unlesbar (Keychain zurückgesetzt, Format geändert): dann gilt eben
      // der normale Weg über das Passwort.
      return null;
    }
  }

  static Future<void> vergessen() async {
    try {
      await _speicher.delete(key: _schluessel);
    } catch (_) {}
  }

  /// Ob der Anmeldebildschirm den Knopf zeigen soll.
  ///
  /// Als eigene Funktion, weil hier die Entscheidung steckt – die lässt sich
  /// prüfen, ohne Keychain und Sensor zu haben.
  static bool anbieten({
    required GemerkterZugang? gemerkt,
    required String aktuellerServer,
  }) {
    if (gemerkt == null) return false;
    if (gemerkt.benutzername.isEmpty || gemerkt.passwort.isEmpty) return false;
    // Nach einem Serverwechsel gehören die Daten woanders hin.
    return gemerkt.server == aktuellerServer;
  }
}

class GemerkterZugang {
  final String benutzername;
  final String passwort;
  final String server;

  const GemerkterZugang({
    required this.benutzername,
    required this.passwort,
    required this.server,
  });
}
