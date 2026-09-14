// Rohes PCM in eine WAV-Datei verpacken -- und wieder heraus.
//
// Aufgenommen wurde bisher als AAC. Fuer die Stimmerkennung ist das
// unbrauchbar: sherpa-onnx will rohe Abtastwerte, und AAC laesst sich in
// Dart nicht ohne weiteres aufmachen. Zweimal aufnehmen geht nicht -- das
// Mikrofon gehoert immer nur einem. Also einmal roh, und daraus beides.
//
// Der Kopf muss dabei stimmen, und zwar byteweise: Whisper liest ihn mit
// ffmpeg, und ein falsches Feld heisst nicht "Fehler", sondern "Rauschen".
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:productivity/dataservice/wav.dart';

/// Ein paar Abtastwerte als rohes PCM16, little endian.
Uint8List pcm(List<int> werte) {
  final b = ByteData(werte.length * 2);
  for (var i = 0; i < werte.length; i++) {
    b.setInt16(i * 2, werte[i], Endian.little);
  }
  return b.buffer.asUint8List();
}

String text(Uint8List d, int von, int laenge) =>
    String.fromCharCodes(d.sublist(von, von + laenge));

void main() {
  group('Der Kopf', () {
    final datei = Wav.ausPcm16(pcm([0, 1000, -1000, 32767]));
    final sicht = ByteData.sublistView(datei);

    test('faengt mit RIFF an und nennt sich WAVE', () {
      expect(text(datei, 0, 4), 'RIFF');
      expect(text(datei, 8, 4), 'WAVE');
    });

    test('hat die beiden Bloecke fmt und data', () {
      expect(text(datei, 12, 4), 'fmt ');
      expect(text(datei, 36, 4), 'data');
    });

    test('sagt: unkomprimiertes PCM, ein Kanal, 16 Bit', () {
      expect(sicht.getUint16(20, Endian.little), 1, reason: 'Format PCM');
      expect(sicht.getUint16(22, Endian.little), 1, reason: 'Kanaele');
      expect(sicht.getUint16(34, Endian.little), 16, reason: 'Bits');
    });

    test('nennt 16 kHz -- die Rate, die beide Modelle erwarten', () {
      // Eine andere liefert bei Weckwort UND Sprecher Unsinn, keinen Fehler.
      expect(sicht.getUint32(24, Endian.little), 16000);
      expect(Wav.rate, 16000);
    });

    test('rechnet die Byterate passend dazu aus', () {
      // 16000 * 1 Kanal * 2 Byte
      expect(sicht.getUint32(28, Endian.little), 32000);
      expect(sicht.getUint16(32, Endian.little), 2, reason: 'Blockgroesse');
    });

    test('die Laengenangaben passen zu den Daten', () {
      // Das RIFF-Feld zaehlt alles nach ihm selbst, das data-Feld nur die
      // Nutzdaten. Verwechselt man die beiden, liest ffmpeg acht Byte
      // Muell als Abtastwerte.
      expect(sicht.getUint32(40, Endian.little), 8, reason: 'data = 4 Werte');
      expect(sicht.getUint32(4, Endian.little), Wav.kopflaenge - 8 + 8);
    });

    test('ist 44 Byte lang, dann kommen die Daten', () {
      expect(Wav.kopflaenge, 44);
      expect(datei.length, 44 + 8);
    });
  });

  group('Die Daten bleiben unveraendert', () {
    test('was hineingeht, steht hinter dem Kopf wieder da', () {
      final roh = pcm([0, 1000, -1000, 32767]);
      final datei = Wav.ausPcm16(roh);
      expect(datei.sublist(Wav.kopflaenge), roh);
    });

    test('auch eine leere Aufnahme ergibt eine gueltige Datei', () {
      final leer = Wav.ausPcm16(Uint8List(0));
      expect(leer.length, 44);
      expect(text(leer, 0, 4), 'RIFF');
      expect(ByteData.sublistView(leer).getUint32(40, Endian.little), 0);
    });
  });

  group('PCM zu Gleitkomma', () {
    test('Stille bleibt Stille', () {
      expect(Wav.zuFloat32(pcm([0, 0, 0])), [0.0, 0.0, 0.0]);
    });

    test('der Vollausschlag liegt knapp unter eins', () {
      final w = Wav.zuFloat32(pcm([32767]));
      expect(w.first, closeTo(1.0, 0.0001));
      expect(w.first, lessThan(1.0));
    });

    test('der leiseste Wert liegt genau auf minus eins', () {
      // Geteilt wird durch 32768 und nicht durch 32767 -- sonst laege
      // -32768 knapp ausserhalb des Bereichs, den das Modell erwartet.
      expect(Wav.zuFloat32(pcm([-32768])).first, -1.0);
    });

    test('die Haelfte ist die Haelfte', () {
      expect(Wav.zuFloat32(pcm([16384])).first, closeTo(0.5, 0.0001));
    });

    test('ein halber Abtastwert am Ende wird verworfen', () {
      // Sonst laese man ein einzelnes Byte als ganzen Wert -- und der
      // waere zufaellig.
      final krumm = Uint8List.fromList([0, 0, 0, 0, 7]);
      expect(Wav.zuFloat32(krumm).length, 2);
    });

    test('nichts hinein, nichts heraus', () {
      expect(Wav.zuFloat32(Uint8List(0)), isEmpty);
    });
  });

  group('Wie lang ist die Aufnahme', () {
    test('eine Sekunde sind 16000 Werte', () {
      expect(Wav.dauer(Uint8List(16000 * 2)), const Duration(seconds: 1));
    });

    test('eine halbe Sekunde auch richtig', () {
      expect(Wav.dauer(Uint8List(8000 * 2)), const Duration(milliseconds: 500));
    });

    test('nichts dauert nichts', () {
      expect(Wav.dauer(Uint8List(0)), Duration.zero);
    });
  });
}
