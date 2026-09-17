import 'dart:convert';

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

  group('Konfiguration für Claude Desktop', () {
    test('trägt Adresse und Schlüssel über die Umgebungsvariable', () {
      final konfig = McpAnleitung.claudeDesktopKonfig(
        'https://a.de/mcp/abc',
        schluessel: 'mcp_geheim',
      );

      expect(konfig, contains('"https://a.de/mcp/abc"'));
      expect(konfig, contains('"AUTH_HEADER": "Bearer mcp_geheim"'));
      expect(konfig, contains('mcp-remote'));
    });

    test('setzt kein Leerzeichen hinter den Doppelpunkt im Header', () {
      // Genau daran scheitert es sonst: Claude Desktop unter Windows
      // reicht Argumente mit Leerzeichen falsch an npx weiter und
      // zerlegt den Header dabei. Das Leerzeichen gehört deshalb in die
      // Variable, nicht ins Argument.
      final konfig = McpAnleitung.claudeDesktopKonfig('https://a.de/mcp/abc');

      expect(konfig, contains(r'"Authorization:${AUTH_HEADER}"'));
      expect(konfig, isNot(contains('"Authorization: ')));
    });

    test('ist gültiges JSON', () {
      final konfig = McpAnleitung.claudeDesktopKonfig(
          'https://a.de/mcp/abc', schluessel: 'mcp_x');

      // Der Platzhalter ${...} ist in JSON ein ganz normaler String --
      // wer ihn kopiert, soll keine kaputte Datei bekommen.
      expect(() => jsonDecode(konfig), returnsNormally);
      final d = jsonDecode(konfig) as Map<String, dynamic>;
      final server = (d['mcpServers'] as Map)['ownapp'] as Map;
      expect(server['command'], 'npx');
      expect((server['args'] as List), contains('mcp-remote'));
    });

    test('ohne Schlüssel steht auch hier ein Platzhalter', () {
      final konfig = McpAnleitung.claudeDesktopKonfig('https://a.de/mcp/abc');

      expect(konfig, contains(McpAnleitung.platzhalter));
      expect(konfig, isNot(contains('Bearer mcp_')));
    });
  });

  group('Schnipsel je Client', () {
    test('jeder Client, der den Schlüssel nimmt, hat auch einen', () {
      for (final client in McpAnleitung.clients) {
        final text = McpAnleitung.schnipselFuer(client, 'https://a.de/mcp/x');
        if (client.nimmtSchluessel) {
          expect(text, isNotNull, reason: client.name);
          expect(text, contains('https://a.de/mcp/x'), reason: client.name);
        } else {
          // Ein Schnipsel, in dem der Schlüssel nirgends unterkommt,
          // wäre eine Anleitung ins Leere.
          expect(text, isNull, reason: client.name);
        }
      }
    });
  });

  group('Die anderen Anbieter', () {
    test('Gemini CLI braucht keine Brücke', () {
      final konfig = McpAnleitung.geminiCliKonfig('https://a.de/mcp/x');

      expect(konfig, contains('"httpUrl": "https://a.de/mcp/x"'));
      expect(konfig, isNot(contains('mcp-remote')));
      expect(() => jsonDecode(konfig), returnsNormally);
    });

    test('Gemini CLI nimmt ohne Schlüssel die Umgebungsvariable', () {
      final konfig = McpAnleitung.geminiCliKonfig('https://a.de/mcp/x');

      expect(konfig, contains('\${${McpAnleitung.variable}}'));
    });

    test('Codex nennt nur den Namen der Variablen', () {
      // Das Format sieht keinen Platz für den Schlüssel vor -- also darf
      // auch der Dialog nach dem Erzeugen dort keinen hineinschreiben.
      final toml = McpAnleitung.codexKonfig('https://a.de/mcp/x');

      expect(toml, contains('[mcp_servers.ownapp]'));
      expect(toml, contains('bearer_token_env_var = "'
          '${McpAnleitung.variable}"'));
      expect(toml, isNot(contains('Bearer ')));
    });

    test('VS Code fragt den Schlüssel ab, statt ihn zu speichern', () {
      final konfig = McpAnleitung.vscodeKonfig('https://a.de/mcp/x');

      expect(() => jsonDecode(konfig), returnsNormally);
      final d = jsonDecode(konfig) as Map<String, dynamic>;
      expect((d['inputs'] as List).first['password'], isTrue);
      expect(d['servers']['ownapp']['type'], 'http');
      expect(konfig, isNot(contains('mcp_')));
    });

    test('kein Schnipsel verrät einen Schlüssel, wenn keiner da ist', () {
      // Die Seite zeigt sie ohne Schlüssel -- stünde dort einer, wäre er
      // aus einem früheren Aufruf hängengeblieben.
      for (final c in McpAnleitung.clients) {
        final text = McpAnleitung.schnipselFuer(c, 'https://a.de/mcp/x');
        if (text == null) continue;
        expect(text, isNot(contains('Bearer mcp_')), reason: c.name);
      }
    });
  });

  group('Wo ein Client läuft', () {
    test('die Trennlinie ist der Ort, nicht der Hersteller', () {
      // Jeder der drei Browser-Anbieter hat einen lokalen Bruder, der
      // geht -- sonst wäre die Liste eine Absage statt einer Anleitung.
      for (final c in McpAnleitung.an(McpOrt.browser)) {
        expect(c.nimmtSchluessel, isFalse, reason: c.name);
      }
      for (final c in McpAnleitung.an(McpOrt.lokal)) {
        expect(c.nimmtSchluessel, isTrue, reason: c.name);
      }
    });

    test('für jeden grossen Anbieter gibt es einen lokalen Weg', () {
      final lokal = McpAnleitung.an(McpOrt.lokal).map((c) => c.name).join(' ');

      expect(lokal, contains('Claude'));
      expect(lokal, contains('Gemini'));
      expect(lokal, contains('Codex'));
    });

    test('es gibt einen Sammelweg für alles andere', () {
      // Cursor, Windsurf, Cline, Zed -- die alle einzeln zu pflegen
      // hiesse, die Liste nie wieder aktuell zu haben.
      expect(
        McpAnleitung.clients.any((c) => c.schnipsel == McpSchnipsel.bruecke),
        isTrue,
      );
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
