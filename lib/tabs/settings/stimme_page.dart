import 'dart:async';

import 'package:flutter/material.dart';
import 'package:productivity/dataservice/api_error.dart';
import 'package:productivity/dataservice/stimm_erkennung.dart';
import 'package:productivity/dataservice/stimm_service.dart';
import 'package:productivity/dataservice/transcription_service.dart';
import 'package:productivity/dataservice/wakeword_service.dart';
import 'package:productivity/dataservice/wav.dart';
import 'package:productivity/main.dart';
import 'package:productivity/provider/permission_provider.dart';
import 'package:productivity/provider/sprach_provider.dart';
import 'package:provider/provider.dart';

/// Die eigene Stimme einlernen — und der Schalter für den ganzen Haushalt.
///
/// Am Küchendashboard weiß Jarvis nicht, wer vor ihm steht. Wer hier drei
/// Sätze spricht, bekommt „was steht bei mir an" beantwortet, ohne seinen
/// Namen zu nennen.
///
/// ## Was die Seite sagen muss
///
/// Dass **keine Aufnahme gespeichert wird**. Was auf den Server geht, ist
/// ein Zahlenvektor; aus dem lässt sich das Gesprochene nicht
/// zurückrechnen. Wer das nicht weiß, spricht zu Recht nichts ein.
class StimmePage extends BasePage {
  const StimmePage({super.key}) : super(title: 'Stimme');

  @override
  Widget buildBody(BuildContext context) => const _Inhalt();
}

class _Inhalt extends StatefulWidget {
  const _Inhalt();

  @override
  State<_Inhalt> createState() => _InhaltState();
}

class _InhaltState extends State<_Inhalt> {
  /// Wie lange eine Probe dauert. Vier Sekunden sind genug für einen Satz
  /// und kurz genug, dass niemand ungeduldig wird.
  static const int _probensekunden = 4;

  /// Wie lange auf den Server gewartet wird, bevor es eine Meldung gibt.
  ///
  /// Der allgemeine Zeitrahmen der App ist 30 Sekunden zum Verbinden und
  /// fünf Minuten zum Empfangen — sinnvoll für einen Datei-Upload,
  /// unerträglich für einen Statusabruf, hinter dem jemand mit dem Finger
  /// über dem Knopf steht.
  static const Duration _geduld = Duration(seconds: 15);

  /// Was man sagen soll. Der Inhalt ist gleichgültig — es zählt der Klang.
  /// Ein vorgegebener Satz ist trotzdem besser als „sag irgendwas": davor
  /// steht man stumm.
  static const List<String> _saetze = [
    'Guten Morgen, wie wird das Wetter heute?',
    'Bitte setz Milch und Brot auf die Einkaufsliste.',
    'Was steht heute bei mir im Kalender an?',
  ];

  Stimmeinstellung _stand = Stimmeinstellung.aus;
  List<Stimmprobe> _meine = [];
  bool _laedt = true;
  bool _nimmtAuf = false;
  String? _fehler;
  int _satzNummer = 0;

  /// Was gerade läuft. Ein Rad, das sich dreht, ohne zu sagen warum, ist
  /// die schlechteste Rückmeldung überhaupt: nach zwanzig Sekunden weiß
  /// niemand, ob er warten oder neu anfangen soll.
  String _schritt = '';

  /// Sekunden, die noch aufgenommen werden. 0 heißt: läuft gerade nicht.
  int _rest = 0;
  Timer? _uhr;

  @override
  void initState() {
    super.initState();
    _laden();
  }

  @override
  void dispose() {
    _uhr?.cancel();
    super.dispose();
  }

  void _zeige(String was) {
    if (mounted) setState(() => _schritt = was);
  }

  Future<void> _laden() async {
    setState(() {
      _laedt = true;
      _fehler = null;
    });
    try {
      final stand = await StimmService.einstellungen();
      final meine = stand.aktiv ? await StimmService.proben() : <Stimmprobe>[];
      if (!mounted) return;
      setState(() {
        _stand = stand;
        _meine = meine;
        _laedt = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _laedt = false;
        _fehler = ApiFehler.text(e);
      });
    }
  }

  void _melde(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _schalten(bool an) async {
    try {
      final neu = await StimmService.setzen(aktiv: an);
      if (!mounted) return;
      setState(() => _stand = neu);
      await _laden();
    } catch (e) {
      _melde(ApiFehler.text(e));
    }
  }

  /// Eine Probe aufnehmen und als Vektor hinterlegen.
  ///
  /// Jeder Schritt sagt, was er tut, und jeder hat eine Obergrenze. Ein
  /// Rad, das sich dreht, ohne zu sagen warum, ist die schlechteste
  /// Rückmeldung überhaupt — und genau das stand hier vorher.
  ///
  /// Das Mikrofon gehört immer nur einem: solange das Weckwort lauscht,
  /// hält es den Audiostrom. Deshalb anhalten — und in `finally` wieder
  /// fortsetzen, sonst ist Jarvis nach dem ersten Fehler taub.
  Future<void> _einlernen() async {
    if (_nimmtAuf) return;
    setState(() {
      _nimmtAuf = true;
      _schritt = '';
      _rest = 0;
    });

    final sprache = context.read<SprachProvider>();
    var angehalten = false;

    try {
      // ── Modell ──────────────────────────────────────────────────
      // Beim ersten Mal werden 28 MB ausgepackt und die ONNX-Laufzeit
      // hochgefahren. Das dauert, und ohne Text sieht es nach Absturz aus.
      if (!StimmErkennung.bereit) {
        _zeige('Spracherkennung wird vorbereitet …');
        final ok = await StimmErkennung.modellLaden().timeout(
          _geduld,
          onTimeout: () => false,
        );
        if (!ok) {
          _melde(StimmErkennung.fehler ??
              'Die Spracherkennung ließ sich nicht vorbereiten. '
                  'Erreichst du den Server?');
          return;
        }
      }

      if (WakewordService.laeuft) {
        _zeige('Weckwort wird kurz angehalten …');
        await WakewordService.anhalten();
        angehalten = true;
      }

      _zeige('Mikrofon …');
      if (!await TranscriptionService.hasPermission()) {
        _melde('Ohne Mikrofon geht es nicht.');
        return;
      }

      // ── Aufnehmen ───────────────────────────────────────────────
      // Eine Sekunde Vorlauf: wer erst das Gerät zum Mund führt, verliert
      // sonst den Anfang -- und bekommt "das war zu kurz" für etwas, das
      // er richtig gemacht hat.
      _zeige('Gleich geht es los …');
      await Future<void>.delayed(const Duration(seconds: 1));

      await TranscriptionService.start();
      if (!mounted) return;

      // Der Countdown ist die eigentliche Verbesserung: man sieht, wie
      // lange man noch sprechen soll, statt ins Ungewisse zu reden.
      setState(() {
        _schritt = 'Sprich jetzt';
        _rest = _probensekunden;
      });
      _uhr?.cancel();
      _uhr = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) return;
        setState(() => _rest = _rest > 0 ? _rest - 1 : 0);
      });
      await Future<void>.delayed(const Duration(seconds: _probensekunden));
      _uhr?.cancel();

      _zeige('Wird ausgewertet …');
      final pcm = await TranscriptionService.stopNurAudio();

      if (pcm == null || pcm.isEmpty) {
        _melde('Es kam kein Ton an. Ist das Mikrofon belegt?');
        return;
      }
      final dauer = Wav.dauer(pcm);
      if (dauer < StimmErkennung.mindestdauer) {
        _melde('Nur ${(dauer.inMilliseconds / 1000).toStringAsFixed(1)} '
            'Sekunden angekommen. Nochmal, und sprich durch.');
        return;
      }

      final profil = StimmErkennung.embedding(pcm);
      if (profil == null) {
        _melde('Daraus ließ sich kein Stimmprofil rechnen.');
        return;
      }

      // ── Speichern ───────────────────────────────────────────────
      _zeige('Wird gespeichert …');
      await StimmService.probeAnlegen(profil.toList(), label: 'Probe')
          .timeout(_geduld);
      await sprache.stimmprofileNeuLaden();

      if (!mounted) return;
      setState(() => _satzNummer = (_satzNummer + 1) % _saetze.length);
      await _laden();
      _melde('Probe gespeichert — ${profil.length} Werte.');
    } on TimeoutException {
      _melde('Der Server hat nicht geantwortet. Nochmal versuchen?');
    } catch (e) {
      _melde(ApiFehler.text(e));
    } finally {
      _uhr?.cancel();
      if (angehalten) {
        unawaited(WakewordService.fortsetzen());
      }
      if (mounted) {
        setState(() {
          _nimmtAuf = false;
          _schritt = '';
          _rest = 0;
        });
      }
    }
  }

  Future<void> _vergessen() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Deine Stimme vergessen?'),
        content: const Text(
          'Alle deine Stimmproben werden gelöscht. Jarvis erkennt dich '
          'danach nicht mehr und fragt wieder nach, wer spricht.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Abbrechen')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Vergessen')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final sprache = context.read<SprachProvider>();
    try {
      final anzahl = await StimmService.eigeneVergessen();
      await sprache.stimmprofileNeuLaden();
      _melde('$anzahl ${anzahl == 1 ? "Probe" : "Proben"} gelöscht.');
      await _laden();
    } catch (e) {
      _melde(ApiFehler.text(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_laedt) return const Center(child: CircularProgressIndicator());

    final text = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    final darfSchalten =
        context.watch<PermissionProvider>().darf('admin:system');

    return RefreshIndicator(
      onRefresh: _laden,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          if (_fehler != null) ...[
            Card(
              color: colors.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(_fehler!,
                    style: TextStyle(color: colors.onErrorContainer)),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ── Der Schalter ──────────────────────────────────────────
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  value: _stand.aktiv,
                  title: const Text('Stimmen erkennen'),
                  subtitle: Text(
                    darfSchalten
                        ? 'Gilt für den ganzen Haushalt.'
                        : 'Das schaltet ein Administrator.',
                  ),
                  onChanged: darfSchalten ? _schalten : null,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Text(
                    'Gespeichert wird kein Ton, sondern eine Zahlenreihe. '
                    'Aus der lässt sich nicht zurückrechnen, was jemand '
                    'gesagt hat — wer die Daten liest, hört niemanden '
                    'sprechen.',
                    style: text.bodySmall
                        ?.copyWith(color: colors.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),

          if (!_stand.aktiv) ...[
            const SizedBox(height: 24),
            Text(
              'Solange das aus ist, fragt Jarvis nach, wer spricht — oder '
              'du sagst den Namen im Satz („was steht bei Lisa an").',
              style: text.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
            ),
          ] else ...[
            const SizedBox(height: 24),

            // ── Einlernen ───────────────────────────────────────────
            Text('Deine Stimme', style: text.titleMedium),
            const SizedBox(height: 8),
            Text(
              _meine.isEmpty
                  ? 'Noch keine Probe. Drei Stück reichen — ein einzelner '
                      'Schnipsel trägt Tagesform und Abstand zum Mikrofon '
                      'mit sich.'
                  : '${_meine.length} ${_meine.length == 1 ? "Probe" : "Proben"} '
                      'hinterlegt. Mehr hilft, besonders wenn Jarvis dich '
                      'verwechselt.',
              style: text.bodySmall?.copyWith(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 16),

            Card(
              color: colors.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(
                      _nimmtAuf ? 'Sprich jetzt:' : 'Sag beim Aufnehmen:',
                      style: text.labelLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _saetze[_satzNummer],
                      textAlign: TextAlign.center,
                      style: text.titleMedium?.copyWith(
                          fontStyle: FontStyle.italic, color: colors.primary),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Was du sagst, ist gleichgültig — es zählt der Klang.',
                      style: text.bodySmall
                          ?.copyWith(color: colors.onSurfaceVariant),
                    ),
                    const SizedBox(height: 20),
                    if (_nimmtAuf)
                      Column(
                        children: [
                          // Während der Aufnahme die Sekunden statt eines
                          // Rades: man sieht, wie lange man noch sprechen
                          // soll, statt ins Ungewisse zu reden.
                          if (_rest > 0)
                            Text(
                              '$_rest',
                              style: text.displayMedium?.copyWith(
                                color: colors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          else
                            const CircularProgressIndicator(),
                          const SizedBox(height: 12),
                          Text(
                            _schritt.isEmpty ? 'Einen Moment …' : _schritt,
                            style: _rest > 0
                                ? text.titleMedium
                                    ?.copyWith(color: colors.primary)
                                : text.bodyMedium,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      )
                    else
                      FilledButton.icon(
                        onPressed: _einlernen,
                        icon: const Icon(Icons.mic_rounded),
                        label: Text(_meine.isEmpty
                            ? 'Stimme einlernen'
                            : 'Noch eine Probe'),
                      ),
                  ],
                ),
              ),
            ),

            // ── Was hinterlegt ist ──────────────────────────────────
            if (_meine.isNotEmpty) ...[
              const SizedBox(height: 24),
              for (final p in _meine)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.graphic_eq_rounded),
                    title: Text(p.label ?? 'Probe'),
                    subtitle: Text('${p.dim} Werte', style: text.bodySmall),
                    trailing: IconButton(
                      icon: Icon(Icons.delete_outline, color: colors.error),
                      tooltip: 'Diese Probe löschen',
                      onPressed: () async {
                        // Den Provider VOR dem await greifen: danach ist
                        // nicht sicher, ob dieses Widget noch steht.
                        final sprache = context.read<SprachProvider>();
                        try {
                          await StimmService.probeLoeschen(p.id);
                          await sprache.stimmprofileNeuLaden();
                          await _laden();
                        } catch (e) {
                          _melde(ApiFehler.text(e));
                        }
                      },
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: _vergessen,
                icon: Icon(Icons.person_off_outlined, color: colors.error),
                label: Text('Meine Stimme vergessen',
                    style: TextStyle(color: colors.error)),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
