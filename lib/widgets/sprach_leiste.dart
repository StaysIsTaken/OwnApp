import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:productivity/provider/permission_provider.dart';
import 'package:productivity/provider/sprach_provider.dart';

/// Die Sprachbedienung der Küchenansicht: ein großer Knopf und eine Karte,
/// die zeigt, was gerade passiert.
///
/// Der Zustand muss sichtbar sein. Ohne die Rückmeldung redet man ins Leere
/// und weiß nicht, ob das Gerät zugehört hat — das ist der Unterschied
/// zwischen „funktioniert" und „fühlt sich kaputt an".
///
/// **Und das gilt auch dafür, dass es sie gar nicht gibt.** Ohne die
/// Rechte verschwand hier alles spurlos: kein Knopf, keine Karte, kein
/// Satz. Wer dann in die Küche ruft, bekommt keine Antwort und hat
/// nichts, woran er sähe, warum — das Gerät wirkt kaputt, obwohl es
/// genau das tut, was seine Rolle erlaubt.
///
/// Deshalb bleibt ein stiller Hinweis stehen. Er nennt das fehlende
/// Recht, denn das ist die einzige Angabe, mit der ein Administrator
/// etwas anfangen kann.
class SprachLeiste extends StatelessWidget {
  const SprachLeiste({super.key});

  @override
  Widget build(BuildContext context) {
    // Zurufen braucht beides: erkennen lassen (`ai:use`) und die erkannte
    // Bitte ausführen (`chat:use`). Fehlt eines, wäre der Knopf ein Weg in
    // eine Fehlermeldung — dann zeigt die Küchenansicht eben nur.
    final rechte = context.watch<PermissionProvider>();
    if (!rechte.darfSprache) {
      return _OhneRecht(
        fehlt: [
          if (!rechte.darfKi) 'ai:use',
          if (!rechte.darfChat) 'chat:use',
        ],
      );
    }

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
    // Fingern. Er bleibt auch neben dem Weckwort nützlich -- wer davor
    // steht, drückt lieber, als zu rufen.
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
    // Küche und hält ein stilles Gerät für kaputt, obwohl nur das Modell
    // fehlt oder das Mikrofon verweigert wurde.
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

/// Was statt der Sprachbedienung dasteht, wenn ein Recht fehlt.
///
/// Klein und am Rand, nicht als Fehlermeldung: an der Küchenwand hängt
/// das Gerät den ganzen Tag, und eine rote Kachel, die nie weggeht, liest
/// nach dem zweiten Tag niemand mehr. Es genügt, dass die Frage „warum
/// antwortet Jarvis nicht" eine Antwort findet, wenn jemand sie stellt.
class _OhneRecht extends StatelessWidget {
  final List<String> fehlt;

  const _OhneRecht({required this.fehlt});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Positioned(
      right: 20,
      bottom: 20,
      child: Tooltip(
        message: 'Diesem Konto fehlt ${fehlt.join(" und ")}. '
            'Ein Administrator kann es der Rolle geben.',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: colors.outlineVariant),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.mic_off_outlined,
                  size: 20, color: colors.onSurfaceVariant),
              const SizedBox(width: 8),
              Text(
                'Zuruf aus — ${fehlt.join(" und ")} fehlt',
                style: TextStyle(
                    fontSize: 13, color: colors.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
