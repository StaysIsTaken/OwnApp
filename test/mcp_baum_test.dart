import 'package:flutter_test/flutter_test.dart';
import 'package:productivity/dataclasses/mcp_zugang.dart';
import 'package:productivity/dataservice/mcp_baum.dart';

/// Der Baum der MCP-Einstellungen.
///
/// Zwei Dinge werden hier festgehalten, und beide sind der Grund, warum
/// die Regel überhaupt aus der Seite herausgezogen wurde: dass jede Ebene
/// erst erscheint, wenn die darüber an ist, und dass Ausschalten den
/// Unterbaum mitnimmt. Das zweite ist das wichtigere — ohne es wäre das
/// Schreiben still wieder da, wenn man einen Bereich Monate später
/// erneut anschaltet.

McpZugang zugang({bool an = false, Map<String, bool> schalter = const {}}) =>
    McpZugang(an: an, schalter: schalter);

void main() {
  group('Was sichtbar ist', () {
    test('ohne Hauptschalter steht nichts darunter', () {
      final z = zugang(an: false, schalter: {'mcp_rezepte': true});

      expect(McpBaum.zeigtBereiche(z), isFalse);
      expect(McpBaum.zeigtSchreiben(z, 'mcp_rezepte'), isFalse);
      expect(McpBaum.zeigtHaushalt(z, imHaushalt: true), isFalse);
    });

    test('mit Hauptschalter erscheinen die Bereiche', () {
      expect(McpBaum.zeigtBereiche(zugang(an: true)), isTrue);
    });

    test('Schreiben erscheint erst unter einem angehakten Bereich', () {
      final aus = zugang(an: true, schalter: {'mcp_rezepte': false});
      final an = zugang(an: true, schalter: {'mcp_rezepte': true});

      expect(McpBaum.zeigtSchreiben(aus, 'mcp_rezepte'), isFalse);
      expect(McpBaum.zeigtSchreiben(an, 'mcp_rezepte'), isTrue);
    });

    test('ohne Haushalt gibt es den Haushalts-Ast nicht', () {
      // Sonst stünde dort ein Ast über etwas, das es nicht gibt --
      // dieselbe Regel wie bei „Meins / Unseres".
      final z = zugang(an: true, schalter: {'mcp_haushalt': true});

      expect(McpBaum.zeigtHaushalt(z, imHaushalt: false), isFalse);
      expect(McpBaum.zeigtHaushaltsbereiche(z, imHaushalt: false), isFalse);
    });

    test('der Haushalts-Ast klappt erst auf, wenn er an ist', () {
      final zu = zugang(an: true, schalter: {'mcp_haushalt': false});
      final auf = zugang(an: true, schalter: {'mcp_haushalt': true});

      expect(McpBaum.zeigtHaushaltsbereiche(zu, imHaushalt: true), isFalse);
      expect(McpBaum.zeigtHaushaltsbereiche(auf, imHaushalt: true), isTrue);
    });
  });

  group('Was beim Ausschalten mitgeht', () {
    test('ein Bereich nimmt sein Schreiben mit', () {
      expect(McpBaum.beimAusschalten('mcp_finanzen'), ['mcp_finanzen_w']);
    });

    test('das Schreiben selbst nimmt nichts mit', () {
      expect(McpBaum.beimAusschalten('mcp_finanzen_w'), isEmpty);
    });

    test('der Haushalts-Ast nimmt seine Bereiche mit', () {
      final felder = McpBaum.beimAusschalten('mcp_haushalt');

      expect(felder, contains('mcp_h_einkauf'));
      expect(felder, contains('mcp_h_einkauf_w'));
      expect(felder, isNot(contains('mcp_einkauf')));
    });

    test('der Stamm nimmt wirklich alles mit', () {
      final felder = McpBaum.beimAusschalten('mcp_an');

      expect(felder, contains('mcp_haushalt'));
      for (final b in McpBaum.bereiche) {
        expect(felder, contains(b.feld));
        expect(felder, contains(b.schreibfeld));
      }
      for (final b in McpBaum.haushaltsbereiche) {
        expect(felder, contains(b.feld));
      }
    });
  });

  group('Der Katalog', () {
    test('kennt den Chat nicht', () {
      // Dort hängen fremde Nachrichten dran, und die eigene Zustimmung
      // reicht dafür nicht. Deshalb gibt es ihn nicht einmal als
      // ausgeschalteten Schalter.
      expect(
        McpBaum.bereiche.any((b) => b.feld.contains('chat')),
        isFalse,
      );
    });

    test('erklärt jeden Bereich', () {
      // „Journal" und „Finanzen" ohne den Satz darunter wären ein Haken,
      // den man setzt, ohne zu wissen, was hinausgeht.
      for (final b in McpBaum.bereiche) {
        expect(b.erklaerung.trim(), isNotEmpty, reason: b.feld);
        expect(b.name.trim(), isNotEmpty, reason: b.feld);
      }
    });

    test('hat für jeden Haushaltsbereich ein mcp_h_-Feld', () {
      for (final b in McpBaum.haushaltsbereiche) {
        expect(b.feld, startsWith('mcp_h_'));
      }
    });
  });
}
