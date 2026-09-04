import 'package:flutter_test/flutter_test.dart';
import 'package:productivity/dataservice/api_client.dart';
import 'package:productivity/dataservice/server_config.dart';

void main() {
  group('Adresse aus dem, was jemand eintippt', () {
    String n(String s) => ServerConfig.normalisieren(s);

    test('nur der Rechnername genügt', () {
      // Das ist, was Leute wirklich eingeben.
      expect(n('meinserver.de'), 'https://meinserver.de/api');
    });

    test('https wird ergänzt, http bleibt stehen', () {
      // http nur, wenn es dasteht – sonst liefe eine Adresse unbemerkt
      // unverschlüsselt.
      expect(n('meinserver.de'), startsWith('https://'));
      expect(n('http://192.168.1.10:8000'), 'http://192.168.1.10:8000/api');
    });

    test('ein vorhandener Pfad bleibt unangetastet', () {
      // Hinter einem Reverse-Proxy kann die API woanders hängen.
      expect(n('https://haus.de/backend'), 'https://haus.de/backend');
      expect(n('https://haus.de/api/v2'), 'https://haus.de/api/v2');
    });

    test('/api wird nicht doppelt angehängt', () {
      expect(n('https://haus.de/api'), 'https://haus.de/api');
    });

    test('Schrägstriche am Ende fallen weg', () {
      expect(n('https://haus.de/api///'), 'https://haus.de/api');
      expect(n('https://haus.de/'), 'https://haus.de/api');
    });

    test('Leerzeichen drumherum stören nicht', () {
      expect(n('  meinserver.de  '), 'https://meinserver.de/api');
    });

    test('leere Eingabe bleibt leer', () {
      expect(n(''), '');
      expect(n('   '), '');
    });

    test('ein Port bleibt erhalten', () {
      expect(n('192.168.1.10:8000'), 'https://192.168.1.10:8000/api');
    });
  });

  group('Welche Adresse gilt', () {
    test('ohne Einstellung gilt die eingebaute Vorgabe', () {
      // Ein fertiges Bild muss ohne jede Einstellung brauchbar sein.
      expect(ServerConfig.vorgabe, isNotEmpty);
      expect(ServerConfig.vorgabe, startsWith('http'));
    });

    test('WebSocket-Adresse behält den Port', () {
      // Genau hier lag ein Fehler: der Chat hat den Port weggelassen, die
      // Benachrichtigungen nicht. Mit fester Domain (Port 443, implizit)
      // fiel das nie auf.
      final vorher = ApiClient.baseUrl;
      ApiClient.setBaseUrl('http://192.168.1.10:8000/api');
      expect(ApiClient.websocketUrl('/chat/ws/42'),
          'ws://192.168.1.10:8000/api/chat/ws/42');
      ApiClient.setBaseUrl(vorher);
    });

    test('https wird zu wss', () {
      final vorher = ApiClient.baseUrl;
      ApiClient.setBaseUrl('https://haus.de/api');
      expect(ApiClient.websocketUrl('/chat/ws/notifications'),
          'wss://haus.de/api/chat/ws/notifications');
      ApiClient.setBaseUrl(vorher);
    });

    test('ein abweichender Pfad bleibt erhalten', () {
      final vorher = ApiClient.baseUrl;
      ApiClient.setBaseUrl('https://haus.de/backend');
      expect(ApiClient.websocketUrl('/chat/ws/1'),
          'wss://haus.de/backend/chat/ws/1');
      ApiClient.setBaseUrl(vorher);
    });

    test('setBaseUrl wirkt auf den Dio-Client mit', () {
      // Die WebSockets leiten ihre Adresse daraus ab – bliebe der Client
      // stehen, liefen Anfragen und Chat auf verschiedene Server.
      final vorher = ApiClient.baseUrl;
      ApiClient.setBaseUrl('https://anderer.de/api');
      expect(ApiClient.baseUrl, 'https://anderer.de/api');
      expect(ApiClient.dio.options.baseUrl, 'https://anderer.de/api');
      ApiClient.setBaseUrl(vorher);
    });
  });
}
