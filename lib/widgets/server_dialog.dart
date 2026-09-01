import 'package:flutter/material.dart';
import 'package:productivity/dataservice/api_client.dart';
import 'package:productivity/dataservice/login_service.dart';
import 'package:productivity/dataservice/server_config.dart';

/// Serveradresse eintragen und prüfen.
///
/// Geprüft wird vor dem Speichern, weil eine falsche Adresse sonst erst
/// beim Anmelden auffällt — und dann sieht es aus wie ein falsches
/// Passwort.
///
/// Gibt `true` zurück, wenn die Adresse geändert wurde.
class ServerDialog extends StatefulWidget {
  const ServerDialog({super.key});

  @override
  State<ServerDialog> createState() => _ServerDialogState();
}

class _ServerDialogState extends State<ServerDialog> {
  late final TextEditingController _feld =
      TextEditingController(text: ApiClient.baseUrl);

  bool _prueft = false;
  ServerPruefung? _ergebnis;
  String? _geprueft; // welche Adresse das Ergebnis betrifft

  @override
  void dispose() {
    _feld.dispose();
    super.dispose();
  }

  String get _adresse => ServerConfig.normalisieren(_feld.text);

  Future<void> _pruefen() async {
    final url = _adresse;
    if (url.isEmpty) return;
    setState(() {
      _prueft = true;
      _ergebnis = null;
    });
    final ergebnis = await ServerConfig.pruefen(url);
    if (!mounted) return;
    setState(() {
      _prueft = false;
      _ergebnis = ergebnis;
      _geprueft = url;
    });
  }

  Future<void> _speichern() async {
    final url = _adresse;
    if (url == ApiClient.baseUrl) {
      Navigator.pop(context, false);
      return;
    }
    // Die Anmeldung gilt beim alten Server. Ein Token dorthin mitzunehmen
    // wäre bestenfalls wirkungslos und schlimmstenfalls verwirrend, weil
    // die App kurz angemeldet aussähe.
    await LoginService.logout();
    await ServerConfig.speichern(url);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final url = _adresse;
    final passt = _ergebnis != null && _geprueft == url;

    return AlertDialog(
      title: const Text('Serveradresse'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Wo läuft deine API? Ohne https:// davor wird es ergänzt, '
              'und ohne Pfad wird /api angehängt.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _feld,
              autocorrect: false,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'Adresse',
                hintText: 'meinserver.de',
              ),
              onChanged: (_) => setState(() => _ergebnis = null),
              onSubmitted: (_) => _pruefen(),
            ),
            if (url.isNotEmpty && url != _feld.text.trim()) ...[
              const SizedBox(height: 8),
              // Zeigen, was daraus wird – geraten wird nichts im Verborgenen.
              Text('Verwendet wird: $url',
                  style: TextStyle(fontSize: 12, color: scheme.outline)),
            ],
            const SizedBox(height: 16),
            if (_prueft)
              const Row(
                children: [
                  SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                  SizedBox(width: 12),
                  Text('Wird geprüft …'),
                ],
              )
            else if (passt && _ergebnis!.erreichbar)
              Row(
                children: [
                  const Icon(Icons.check_circle_outline,
                      color: Color(0xFF34C759), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _ergebnis!.registrierungOffen
                          ? 'Erreichbar. Registrierung ist offen.'
                          : 'Erreichbar. Registrierung ist geschlossen — '
                              'du brauchst ein Konto von der Verwaltung.',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              )
            else if (passt)
              Row(
                children: [
                  Icon(Icons.error_outline, color: scheme.error, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_ergebnis!.meldung ?? 'Nicht erreichbar.',
                        style: TextStyle(fontSize: 13, color: scheme.error)),
                  ),
                ],
              )
            else
              OutlinedButton.icon(
                onPressed: url.isEmpty ? null : _pruefen,
                icon: const Icon(Icons.wifi_tethering, size: 18),
                label: const Text('Verbindung prüfen'),
              ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                TextButton(
                  onPressed: () {
                    _feld.text = ServerConfig.vorgabe;
                    setState(() => _ergebnis = null);
                  },
                  style: TextButton.styleFrom(padding: EdgeInsets.zero),
                  child: const Text('Auf Vorgabe zurücksetzen'),
                ),
                // Im Browser der haeufigste Fall: die App liegt auf
                // derselben Domain wie die API. Ein Klick statt Tippen.
                if (ServerConfig.dieseSeite != null)
                  TextButton(
                    onPressed: () {
                      _feld.text = ServerConfig.dieseSeite!;
                      setState(() => _ergebnis = null);
                    },
                    style: TextButton.styleFrom(padding: EdgeInsets.zero),
                    child: const Text('Diese Seite verwenden'),
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          // Speichern erst nach erfolgreicher Prüfung: eine Adresse, die
          // nicht antwortet, hilft niemandem.
          onPressed: (passt && _ergebnis!.erreichbar) ? _speichern : null,
          child: const Text('Übernehmen'),
        ),
      ],
    );
  }
}
