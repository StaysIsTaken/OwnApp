import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// Einen Link im Browser öffnen — und sagen, wenn es nicht ging.
///
/// An einer Stelle statt an jeder Aufrufstelle, weil der Fehlerfall
/// überall derselbe ist und überall vergessen wird: `launchUrl` gibt
/// `false` zurück, statt zu werfen. Wer nur `await launchUrl(...)`
/// schreibt, bekommt ein stilles Nichts — der Nutzer tippt, es passiert
/// nichts, und niemand erfährt warum.
///
/// Gründe dafür gibt es genug: kein Browser installiert, eine Umgebung
/// ohne Fenster (Küchentablet im Kioskmodus), ein blockierter Pop-up auf
/// Web. Deshalb kommt in dem Fall die Adresse in die Zwischenablage —
/// dann ist der Weg wenigstens kurz.
Future<void> linkOeffnen(BuildContext context, String url) async {
  final ziel = Uri.tryParse(url);
  final messenger = ScaffoldMessenger.of(context);

  var geklappt = false;
  if (ziel != null) {
    try {
      geklappt = await launchUrl(ziel, mode: LaunchMode.externalApplication);
    } catch (_) {
      geklappt = false;
    }
  }
  if (geklappt) return;

  await Clipboard.setData(ClipboardData(text: url));
  messenger.showSnackBar(
    const SnackBar(
      content: Text('Konnte den Browser nicht öffnen — Adresse kopiert.'),
    ),
  );
}
