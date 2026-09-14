/// Rohes PCM in eine WAV-Datei verpacken — und wieder heraus.
///
/// ## Warum das überhaupt nötig ist
///
/// Aufgenommen wurde bisher als AAC: klein, überall dekodierbar, für die
/// Transkription genau richtig. Für die Stimmerkennung ist es unbrauchbar
/// — sherpa-onnx will rohe Abtastwerte, und AAC lässt sich in Dart nicht
/// ohne weiteres aufmachen.
///
/// Zweimal aufzunehmen geht nicht: das Mikrofon gehört immer nur einem.
/// Also einmal roh aufnehmen und daraus beides bedienen — die Werte direkt
/// ans Modell, und für den Server dieselben Werte mit 44 Byte Kopf davor.
///
/// Whisper liest WAV ohne Umstand (`whisper.transcribe` nimmt alles, was
/// ffmpeg kann). Der Preis ist die Größe: 16 kHz mono 16 bit sind 32 kB je
/// Sekunde statt gut 2 kB bei AAC. Bei fünfzehn Sekunden über das eigene
/// WLAN fällt das nicht ins Gewicht.
library;

import 'dart:typed_data';

class Wav {
  Wav._();

  /// Die Rate, die beide Modelle erwarten — das Weckwort unter
  /// `assets/kws/` und der Sprecher unter `assets/sprecher/`. Eine andere
  /// liefert bei beiden Unsinn, keinen Fehler.
  static const int rate = 16000;

  /// Länge des kanonischen WAV-Kopfes: RIFF + fmt + data.
  static const int kopflaenge = 44;

  /// Packt 16-bit-PCM in eine WAV-Datei.
  ///
  /// [pcm] sind die rohen Bytes, wie sie der Rekorder liefert: little
  /// endian, ein Kanal.
  static Uint8List ausPcm16(Uint8List pcm,
      {int abtastrate = rate, int kanaele = 1}) {
    const bitsProWert = 16;
    final byteRate = abtastrate * kanaele * bitsProWert ~/ 8;
    final block = kanaele * bitsProWert ~/ 8;

    final kopf = ByteData(kopflaenge);
    void text(int pos, String s) {
      for (var i = 0; i < s.length; i++) {
        kopf.setUint8(pos + i, s.codeUnitAt(i));
      }
    }

    text(0, 'RIFF');
    // Alles nach diesem Feld: der Rest des Kopfes plus die Daten.
    kopf.setUint32(4, kopflaenge - 8 + pcm.length, Endian.little);
    text(8, 'WAVE');

    text(12, 'fmt ');
    kopf.setUint32(16, 16, Endian.little); // Länge des fmt-Blocks
    kopf.setUint16(20, 1, Endian.little); // 1 = unkomprimiertes PCM
    kopf.setUint16(22, kanaele, Endian.little);
    kopf.setUint32(24, abtastrate, Endian.little);
    kopf.setUint32(28, byteRate, Endian.little);
    kopf.setUint16(32, block, Endian.little);
    kopf.setUint16(34, bitsProWert, Endian.little);

    text(36, 'data');
    kopf.setUint32(40, pcm.length, Endian.little);

    final ganz = Uint8List(kopflaenge + pcm.length);
    ganz.setRange(0, kopflaenge, kopf.buffer.asUint8List());
    ganz.setRange(kopflaenge, ganz.length, pcm);
    return ganz;
  }

  /// Rechnet 16-bit-PCM in Gleitkommawerte zwischen -1 und 1 um.
  ///
  /// Das ist, was sherpa-onnx erwartet. Geteilt wird durch 32768 und nicht
  /// durch 32767: sonst läge der leiseste mögliche Wert (-32768) knapp
  /// außerhalb des Bereichs.
  ///
  /// Ein einzelnes übriges Byte am Ende wird verworfen — ein halber
  /// Abtastwert ist keiner.
  static Float32List zuFloat32(Uint8List pcm) {
    final werte = Float32List(pcm.length ~/ 2);
    final sicht = ByteData.sublistView(pcm);
    for (var i = 0; i < werte.length; i++) {
      werte[i] = sicht.getInt16(i * 2, Endian.little) / 32768.0;
    }
    return werte;
  }

  /// Wie lang die Aufnahme ist.
  ///
  /// Gebraucht, weil eine sehr kurze Aufnahme kein brauchbares
  /// Stimmprofil ergibt — und weil „zu kurz" eine Meldung verdient und
  /// nicht einen stillen Fehlschlag.
  static Duration dauer(Uint8List pcm, {int abtastrate = rate}) =>
      Duration(milliseconds: (pcm.length ~/ 2) * 1000 ~/ abtastrate);
}
