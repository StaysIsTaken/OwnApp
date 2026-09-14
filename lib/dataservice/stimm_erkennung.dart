/// Wer spricht — erkannt am Klang, nicht am Wortlaut.
///
/// Am Küchendashboard steht kein Konto vor dem Gerät, sondern ein Mensch.
/// „Was steht bei mir an" hat ohne einen Sprecher keine Antwort; bisher
/// half nur die Rückfrage „Wer bist du?" oder ein Name im Satz. Das hier
/// ist der Weg, der niemanden etwas tun lässt.
///
/// ## Wo gerechnet wird
///
/// Auf dem Gerät. Das Audio liegt hier ohnehin, und ein Embedding über das
/// Netz zu schicken, nur um es zurückzubekommen, würde die Antwort
/// verlangsamen, ohne etwas zu gewinnen. Der Server verwahrt die Proben
/// und sagt, ob die Funktion an ist.
///
/// ## Was gespeichert wird
///
/// Ein Zahlenvektor, keine Aufnahme. Aus einem Embedding lässt sich das
/// Gesprochene nicht zurückrechnen — wer die Tabelle auf dem Server liest,
/// hört niemanden sprechen.
///
/// ## Das Mikrofon gehört immer nur einem
///
/// Deshalb nimmt dieser Dienst **nicht selbst auf**. Er bekommt die
/// Abtastwerte derselben Aufnahme, die zur Transkription geht — sonst
/// müsste jemand zweimal sprechen, oder das Weckwort ginge verloren.
library;

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import 'package:productivity/dataservice/stimm_service.dart';
import 'package:productivity/dataservice/wav.dart';

class StimmErkennung {
  StimmErkennung._();

  /// Die Modelldatei im Asset-Bündel. Umbenannt aus
  /// `wespeaker_en_voxceleb_CAM++_LM.onnx`; woher sie kommt und warum
  /// gerade diese, steht in `assets/sprecher/HERKUNFT.md`.
  static const String _datei = 'sprecher.onnx';

  /// Wie lang eine Äußerung mindestens sein muss, um etwas auszusagen.
  ///
  /// Unter einer Sekunde trägt ein Schnipsel mehr Raumklang als Stimme.
  /// Lieber nichts erkennen als jemand Falschen — eine Rückfrage kostet
  /// zwei Sekunden, ein falsch vorgelesener Kalender das Vertrauen.
  static const Duration mindestdauer = Duration(milliseconds: 1000);

  static sherpa.SpeakerEmbeddingExtractor? _rechner;
  static sherpa.SpeakerEmbeddingManager? _verzeichnis;
  static String? _fehler;

  /// Wie viele Personen im Verzeichnis stehen. 0 heißt: es kann niemanden
  /// erkennen, egal wie gut die Aufnahme ist.
  static int _bekannte = 0;

  /// Ab welcher Ähnlichkeit ein Treffer zählt. Kommt beim [starten] vom
  /// Server, damit sie sich ohne neues App-Bündel nachziehen lässt: zu
  /// niedrig heißt „hält jeden für Lisa", zu hoch „erkennt niemanden".
  static double _schwelle = 0.6;

  static bool get bereit => _rechner != null;
  static int get bekannte => _bekannte;

  /// Was zuletzt schiefging — für die Oberfläche, nicht für den Ablauf.
  static String? get fehler => _fehler;

  /// Die Vektorlänge des geladenen Modells (512 bei diesem hier).
  ///
  /// Wird beim Hinterlegen einer Probe mitgeschickt: tauscht jemand das
  /// Modell, sind die alten Proben nicht falsch, sondern unvergleichbar —
  /// und das soll auffallen, statt still niemanden mehr zu erkennen.
  static int get dim => _rechner?.dim ?? 0;

  static Future<String> _ausgepackt() async {
    // Dieselbe Sache wie beim Weckwort: die ONNX-Laufzeit öffnet echte
    // Dateien und kann mit einem Flutter-Asset nichts anfangen.
    final ordner = await getApplicationSupportDirectory();
    final ziel = File('${ordner.path}/sprecher/$_datei');
    final daten = await rootBundle.load('assets/sprecher/$_datei');
    final bytes =
        daten.buffer.asUint8List(daten.offsetInBytes, daten.lengthInBytes);

    if (!await ziel.exists() || await ziel.length() != bytes.length) {
      await ziel.parent.create(recursive: true);
      await ziel.writeAsBytes(bytes, flush: true);
    }
    return ziel.path;
  }

  /// Lädt nur das Modell — genug, um die **eigene** Stimme einzulernen.
  ///
  /// Bewusst getrennt von [starten]: zum Rechnen eines Stimmprofils
  /// braucht es das Modell und sonst nichts. Die Profile der anderen
  /// braucht nur, wer vergleichen will, und die gibt es ausschließlich
  /// gegen `tablet:use` — das auf einem Telefon niemand hat. Hingen beide
  /// an einem Aufruf, könnte man seine Stimme nur am Küchentablet
  /// einlernen, und das wäre genau verkehrt herum.
  ///
  /// Gibt false zurück, wenn es nicht geht — abgeschaltet, kein Modell,
  /// Browser. Das ist **kein Fehler im Ablauf**: ohne Stimmerkennung fragt
  /// Jarvis eben „Wer bist du?", und das funktioniert.
  static Future<bool> modellLaden() async {
    if (kIsWeb) {
      // Ein 28-MB-Modell über das Netz zu laden wäre keine gute Idee, und
      // die Tablet-Ansicht läuft ohnehin nicht im Browser.
      _fehler = 'Im Browser gibt es keine Stimmerkennung.';
      return false;
    }

    try {
      final einstellungen = await StimmService.einstellungen();
      if (!einstellungen.aktiv) {
        _fehler = 'Die Stimmerkennung ist ausgeschaltet.';
        await beenden();
        return false;
      }
      _schwelle = einstellungen.schwelle;

      if (_rechner == null) {
        sherpa.initBindings();
        _rechner = sherpa.SpeakerEmbeddingExtractor(
          config: sherpa.SpeakerEmbeddingExtractorConfig(
            model: await _ausgepackt(),
            debug: false,
          ),
        );
      }
      _fehler = null;
      return true;
    } catch (e) {
      _fehler = 'Stimmerkennung nicht verfügbar: $e';
      return false;
    }
  }

  /// Lädt das Modell **und** die Stimmprofile — zum Erkennen.
  ///
  /// Verlangt `tablet:use`, denn nur damit gibt der Server die Vektoren
  /// heraus. Auf einem Telefon schlägt das fehl, und das ist richtig so:
  /// dort wird eingelernt, nicht erkannt.
  static Future<bool> starten() async {
    if (!await modellLaden()) return false;
    await profileNeuLaden();
    return true;
  }

  /// Holt die Profile neu — nach dem Einlernen einer Stimme.
  ///
  /// Still, wenn der Server sie nicht herausgibt: auf einem Telefon ohne
  /// `tablet:use` ist das der Normalfall und kein Grund für eine Meldung.
  static Future<void> profileNeuLaden() async {
    final rechner = _rechner;
    if (rechner == null) return;

    final List<Stimme> leute;
    try {
      leute = await StimmService.stimmen();
    } catch (_) {
      // Kein `tablet:use` — dann wird hier nicht verglichen. Die
      // vorhandenen Profile bleiben, wie sie sind.
      return;
    }

    // Erst hier tauschen, nach dem geglückten Abruf: sonst erkennt ein
    // Netzaussetzer plötzlich niemanden mehr. Und ein frisches
    // Verzeichnis statt eines gepflegten — gelöschte Proben müssten sonst
    // einzeln herausgenommen werden, und eine übersehene hieße, dass
    // jemand erkannt wird, der sich gerade austragen wollte.
    _verzeichnis?.free();
    final verzeichnis = sherpa.SpeakerEmbeddingManager(rechner.dim);
    _bekannte = 0;

    for (final person in leute) {
      final passend = person.embeddings
          .where((e) => e.length == rechner.dim)
          .map(Float32List.fromList)
          .toList();
      if (passend.isEmpty) continue;
      if (verzeichnis.addMulti(name: person.userName, embeddingList: passend)) {
        _bekannte++;
      }
    }
    _verzeichnis = verzeichnis;
  }

  /// Rechnet eine Aufnahme in ein Stimmprofil um.
  ///
  /// [pcm] sind rohe 16-bit-Abtastwerte bei 16 kHz — dieselben, die als
  /// WAV zur Transkription gehen.
  static Float32List? embedding(Uint8List pcm) {
    final rechner = _rechner;
    if (rechner == null) return null;
    if (Wav.dauer(pcm) < mindestdauer) return null;

    final strom = rechner.createStream();
    try {
      strom.acceptWaveform(samples: Wav.zuFloat32(pcm), sampleRate: Wav.rate);
      // Dem Modell sagen, dass nichts mehr kommt: ohne das wartet es auf
      // weitere Werte und wird nie fertig.
      strom.inputFinished();
      if (!rechner.isReady(strom)) return null;
      return rechner.compute(strom);
    } finally {
      strom.free();
    }
  }

  /// Wer hat das gesagt? Null, wenn es niemand sicher genug war.
  ///
  /// Im Zweifel niemand: eine Rückfrage kostet zwei Sekunden, ein falsch
  /// vorgelesener Kalender das Vertrauen.
  static String? erkenne(Uint8List pcm) {
    final verzeichnis = _verzeichnis;
    if (verzeichnis == null || _bekannte == 0) return null;

    final profil = embedding(pcm);
    if (profil == null) return null;

    final treffer = verzeichnis.search(embedding: profil, threshold: _schwelle);
    return treffer.isEmpty ? null : treffer;
  }

  static Future<void> beenden() async {
    _verzeichnis?.free();
    _verzeichnis = null;
    _rechner?.free();
    _rechner = null;
    _bekannte = 0;
  }
}
