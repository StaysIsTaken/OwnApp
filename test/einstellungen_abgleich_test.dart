import 'package:flutter_test/flutter_test.dart';
import 'package:productivity/dataclasses/einstellungen.dart';
import 'package:productivity/dataservice/einstellungs_abgleich.dart';

/// Die Übergabe vom Gerät ans Konto.
///
/// Der Fall, der hier schiefgehen kann, ist nicht der erste, sondern der
/// zweite: ein weiteres Gerät, das sich anmeldet und dabei die
/// Einstellungen überschreibt, die auf dem ersten schon jemand gesetzt
/// hat. Deshalb steht dieser Test gleich oben mit dabei.

Map<String, dynamic> uebergabe({
  bool schonUebertragen = false,
  Einstellungen vomServer = const Einstellungen(),
  bool use24h = true,
  String ort = '',
  String modell = '',
  double temperatur = 0.7,
  int maxTokens = 500,
}) =>
    Einstellungsabgleich.uebergabe(
      schonUebertragen: schonUebertragen,
      vomServer: vomServer,
      geraetUse24h: use24h,
      geraetWetterOrt: ort,
      geraetKiModell: modell,
      geraetKiTemperatur: temperatur,
      geraetKiMaxTokens: maxTokens,
    );

void main() {
  group('Erstes Gerät', () {
    test('gibt weiter, was der Server nicht weiß', () {
      final daten = uebergabe(
        vomServer: const Einstellungen(),
        ort: 'Kiel',
        modell: 'llama3',
        temperatur: 0.4,
        maxTokens: 800,
      );

      expect(daten['weather_city'], 'Kiel');
      expect(daten['ai_model'], 'llama3');
      expect(daten['ai_temperature'], 0.4);
      expect(daten['ai_max_tokens'], 800);
    });

    test('schickt die Zeitanzeige nur, wenn sie abweicht', () {
      expect(uebergabe(use24h: true).containsKey('use_24h'), isFalse);
      expect(uebergabe(use24h: false)['use_24h'], isFalse);
    });

    test('schickt einen leeren Wetterort nicht mit', () {
      // Sonst stünde auf dem Server ein Ort, den es nicht gibt.
      expect(uebergabe(ort: '').containsKey('weather_city'), isFalse);
    });
  });

  group('Zweites Gerät', () {
    test('überschreibt nicht, was dort schon steht', () {
      final daten = uebergabe(
        vomServer: const Einstellungen(
          use24h: true,
          wetterOrt: 'Hamburg',
          kiModell: 'mixtral',
          kiTemperatur: 0.2,
          kiMaxTokens: 1200,
        ),
        // Dieses Gerät hat ganz andere Werte im Speicher.
        ort: 'Kiel',
        modell: 'llama3',
        temperatur: 0.9,
        maxTokens: 300,
      );

      expect(daten.containsKey('weather_city'), isFalse);
      expect(daten.containsKey('ai_model'), isFalse);
      expect(daten.containsKey('ai_temperature'), isFalse);
      expect(daten.containsKey('ai_max_tokens'), isFalse);
    });

    test('ergänzt aber, was dort fehlt', () {
      final daten = uebergabe(
        vomServer: const Einstellungen(wetterOrt: 'Hamburg'),
        ort: 'Kiel',
        modell: 'llama3',
      );

      expect(daten.containsKey('weather_city'), isFalse);
      expect(daten['ai_model'], 'llama3');
    });
  });

  group('Danach', () {
    test('passiert nichts mehr', () {
      // Ohne diesen Merker schöbe jede Anmeldung den Gerätestand wieder
      // hoch — und machte kaputt, was man anderswo geändert hat.
      final daten = uebergabe(
        schonUebertragen: true,
        vomServer: const Einstellungen(),
        ort: 'Kiel',
        modell: 'llama3',
        use24h: false,
      );

      expect(daten, isEmpty);
    });
  });
}
