import 'package:flutter_test/flutter_test.dart';
import 'package:productivity/dataservice/mcp_anleitung.dart';

/// Die Adresse des Zugangs und die Anleitungen dazu.
///
/// Die Adresse ist die Stelle, an der man sich vertut: die App kennt den
/// Server unter `…/api`, der MCP hängt aber **daneben**. Wer das `/api`
/// stehen lässt, schickt jeden Client auf eine Route, die es nicht gibt
/// — und bekommt ein 404, das nach einem falschen Schlüssel aussieht.

void main() {
  group('Adresse', () {
    test('lässt das /api der API-Adresse weg', () {
      expect(
        McpAnleitung.adresse('https://api.home-anft.de/api', 'k7f3x9q2'),
        'https://api.home-anft.de/mcp/k7f3x9q2',
      );
    });

    test('kommt auch mit einem Schrägstrich am Ende zurecht', () {
      expect(
        McpAnleitung.adresse('https://api.home-anft.de/api/', 'abc'),
        'https://api.home-anft.de/mcp/abc',
      );
    });

    test('lässt eine Adresse ohne /api in Ruhe', () {
      expect(
        McpAnleitung.adresse('https://beispiel.de', 'abc'),
        'https://beispiel.de/mcp/abc',
      );
    });

    test('erzeugt nie zwei Schrägstriche hintereinander', () {
      for (final basis in [
        'https://a.de/api',
        'https://a.de/api/',
        'https://a.de/',
        'https://a.de',
      ]) {
        final adresse = McpAnleitung.adresse(basis, 'abc');
        expect(adresse.contains('//mcp'), isFalse, reason: basis);
        expect(adresse.endsWith('/mcp/abc'), isTrue, reason: basis);
      }
    });

    test('ohne Slug gibt es keine Adresse', () {
      // Sonst stünde dort „https://…/mcp/" und jemand kopierte es.
      expect(McpAnleitung.adresse('https://a.de/api', null), '');
      expect(McpAnleitung.adresse('https://a.de/api', ''), '');
    });
  });

  group('Befehl für Claude Code', () {
    test('trägt Adresse und Schlüssel', () {
      final befehl = McpAnleitung.claudeCodeBefehl(
        'https://a.de/mcp/abc',
        schluessel: 'mcp_geheim',
      );

      expect(befehl, contains('https://a.de/mcp/abc'));
      expect(befehl, contains('Authorization: Bearer mcp_geheim'));
      expect(befehl, contains('--transport http'));
    });

    test('ohne Schlüssel steht ein Platzhalter darin', () {
      // Nach dem Erzeugen haben wir ihn nicht mehr — nur seinen Hash.
      final befehl = McpAnleitung.claudeCodeBefehl('https://a.de/mcp/abc');

      expect(befehl, contains('DEIN_SCHLUESSEL'));
      expect(befehl, isNot(contains('Bearer mcp_')));
    });
  });

  group('Die Anbieter', () {
    test('mindestens einer nimmt den Schlüssel entgegen', () {
      // Wäre das einmal nicht mehr so, ist der Zugang für niemanden
      // benutzbar, und die Seite muss etwas anderes sagen als eine
      // Liste von Wegen.
      expect(McpAnleitung.gibtEsEinenWegMitSchluessel(), isTrue);
    });

    test('der erste ist einer, der ihn entgegennimmt', () {
      // Wer die Seite von oben liest, soll zuerst den Weg sehen, der
      // heute funktioniert.
      expect(McpAnleitung.clients.first.nimmtSchluessel, isTrue);
    });

    test('jeder hat Schritte und eine Anleitung', () {
      for (final client in McpAnleitung.clients) {
        expect(client.name.trim(), isNotEmpty);
        expect(client.schritte, isNotEmpty, reason: client.name);
        expect(client.doku, startsWith('https://'), reason: client.name);
      }
    });

    test('wer den Schlüssel nicht nimmt, sagt auch warum', () {
      // Ohne diesen Satz sieht das 404 wie ein Fehler dieser App aus.
      for (final client in McpAnleitung.clients) {
        if (!client.nimmtSchluessel) {
          expect(client.hinweis, isNotNull, reason: client.name);
          expect(client.hinweis!.trim(), isNotEmpty, reason: client.name);
        }
      }
    });
  });
}
