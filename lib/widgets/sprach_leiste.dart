import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:productivity/provider/sprach_provider.dart';

/// Die Sprachbedienung der Küchenansicht: ein großer Knopf und eine Karte,
/// die zeigt, was gerade passiert.
///
/// Der Zustand muss sichtbar sein. Ohne die Rückmeldung redet man ins Leere
/// und weiß nicht, ob das Gerät zugehört hat — das ist der Unterschied
/// zwischen „funktioniert" und „fühlt sich kaputt an".
class SprachLeiste extends StatelessWidget {
  const SprachLeiste({super.key});

  @override
  Widget build(BuildContext context) {
    final sprache = context.watch<SprachProvider>();
    final zeigeKarte = sprache.aktiv ||
        sprache.antwort.isNotEmpty ||
        sprache.fehler != null ||
        sprache.wakewordFehler != null ||
        sprache.offeneAktionen.isNotEmpty;

    return Positioned(
      right: 20,
      bottom: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (zeigeKarte)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _Karte(sprache: sprache),
            ),
          _Knopf(sprache: sprache),
        ],
      ),
    );
  }
}

class _Knopf extends StatelessWidget {
  final SprachProvider sprache;
  const _Knopf({required this.sprache});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    final (IconData icon, Color grund, String hinweis) =
        switch (sprache.zustand) {
      SprachZustand.hoert => (Icons.stop_rounded, colors.error, 'Fertig'),
      SprachZustand.denkt => (
          Icons.more_horiz_rounded,
          colors.secondaryContainer,
          'Einen Moment'
        ),
      SprachZustand.spricht => (
          Icons.volume_up_rounded,
          colors.tertiaryContainer,
          'Antwort'
        ),
      SprachZustand.ruht => (
          Icons.mic_rounded,
          colors.primaryContainer,
          'Sprechen'
        ),
    };

    // Absichtlich groß: in der Küche trifft man mit nassen oder mehligen
    // Fingern, und dieser Knopf ist der Ersatz fürs Wakeword, solange es
    // noch nicht da ist.
    return Tooltip(
      message: hinweis,
      child: Material(
        color: grund,
        shape: const CircleBorder(),
        elevation: 4,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => switch (sprache.zustand) {
            SprachZustand.ruht => sprache.starten(),
            SprachZustand.hoert => sprache.jetztStoppen(),
            _ => sprache.abbrechen(),
          },
          child: SizedBox(
            width: 88,
            height: 88,
            child: sprache.zustand == SprachZustand.denkt
                ? const Padding(
                    padding: EdgeInsets.all(28),
                    child: CircularProgressIndicator(strokeWidth: 3),
                  )
                : Icon(icon, size: 40),
          ),
        ),
      ),
    );
  }
}

class _Karte extends StatelessWidget {
  final SprachProvider sprache;
  const _Karte({required this.sprache});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final texte = Theme.of(context).textTheme;

    final status = switch (sprache.zustand) {
      SprachZustand.hoert => 'Ich höre …',
      SprachZustand.denkt => 'Einen Moment …',
      SprachZustand.spricht => 'Antwort',
      SprachZustand.ruht => sprache.fehler != null ? 'Hm' : 'Erledigt',
    };

    // Fällt das Weckwort aus, muss das dranstehen. Sonst ruft man durch die
    // Küche und hält ein stilles Gerät für kaputt, obwohl nur der Schlüssel
    // abgelaufen ist.
    final wakewordFehler = sprache.wakewordFehler;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Card(
        elevation: 6,
        color: colors.surfaceContainerHigh,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(status,
                  style: texte.labelLarge?.copyWith(color: colors.primary)),
              if (sprache.verstanden.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text('„${sprache.verstanden}"',
                    style: texte.bodyMedium
                        ?.copyWith(fontStyle: FontStyle.italic)),
              ],
              if (sprache.antwort.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(sprache.antwort, style: texte.bodyLarge),
              ],
              if (sprache.fehler != null) ...[
                const SizedBox(height: 8),
                Text(sprache.fehler!,
                    style: texte.bodyMedium?.copyWith(color: colors.error)),
              ],
              if (wakewordFehler != null) ...[
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.hearing_disabled_rounded,
                        size: 18, color: colors.error),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '$wakewordFehler Der Knopf funktioniert weiter.',
                        style:
                            texte.bodySmall?.copyWith(color: colors.error),
                      ),
                    ),
                  ],
                ),
              ],
              // Alles, was löscht oder sonst wehtut, wird nicht auf Zuruf
              // ausgeführt — hier steht es und wartet auf einen Tipp.
              for (final aktion in sprache.offeneAktionen)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Row(
                    children: [
                      Expanded(
                          child: Text(aktion.label,
                              style: texte.bodyMedium)),
                      TextButton(
                        onPressed: () => sprache.verwerfe(aktion),
                        child: const Text('Nein'),
                      ),
                      FilledButton(
                        onPressed: () => sprache.bestaetige(aktion),
                        child: const Text('Ja'),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
