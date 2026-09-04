import 'package:productivity/dataclasses/journal_entry.dart';
import 'package:productivity/dataservice/feed_service.dart';
import 'package:productivity/dataclasses/note.dart';
import 'package:productivity/dataclasses/planner_entry.dart';
import 'package:productivity/main.dart';
import 'package:productivity/tabs/dashboard/custom/filter_fields.dart';
import 'package:productivity/tabs/dashboard/custom/tile_data.dart';
import 'package:productivity/tabs/dashboard/custom/tile_filter.dart';
import 'package:productivity/tabs/dashboard/custom/tile_spec.dart';

/// Quellen für die Blöcke über der Übersicht.
///
/// Das meiste kommt vom Nutzer selbst oder aus Daten, die die App ohnehin
/// geladen hat. Zwei Quellen fallen heraus — Nachrichten und Witze: sie
/// kommen von draußen, aber **über die eigene API** und nicht aus dem
/// Browser heraus. Sonst sähe der Anbieter jede Adresse im Haushalt
/// einzeln, und im Web scheiterte der Aufruf an CORS. Sie tragen deshalb
/// ein [TileSource.extra] und werden nur geholt, wenn eine Kachel sie
/// wirklich braucht.
class KopfQuellen {
  KopfQuellen._();

  static const _text = TileParam.mehrzeilig(
    key: 'text',
    label: 'Text',
    platzhalter: 'Was soll hier stehen?',
  );

  static const _datum = TileParam.datum(key: 'datum', label: 'Zieldatum');

  static const _meldungen = TileParam(
    key: 'anzahl',
    label: 'Wie viele Meldungen',
    min: 1,
    max: 10,
    standard: 3,
  );

  static const _jahre = TileParam(
    key: 'jahre',
    label: 'Jahre zurück',
    min: 1,
    max: 10,
    standard: 1,
  );

  static final List<TileSource> sources = [
    // ── Selbst geschrieben ───────────────────────────────────────────────
    TileSource(
      key: 'kopf.text',
      label: 'Eigener Text',
      group: 'Eigenes',
      shape: TileShape.text,
      params: const [_text],
      build: (d, p, f) => TileData.text(
        p['text']?.toString(),
        emptyHint: 'Noch nichts geschrieben — auf den Stift tippen.',
      ),
    ),

    TileSource(
      key: 'kopf.countdown',
      label: 'Countdown',
      group: 'Eigenes',
      shape: TileShape.scalar,
      params: const [_datum],
      build: (d, p, f) {
        final roh = p['datum']?.toString();
        final ziel = roh == null ? null : DateTime.tryParse(roh);
        if (ziel == null) return const TileData.scalar(null);
        final heute = DateTime.now();
        final tage = DateTime(ziel.year, ziel.month, ziel.day)
            .difference(DateTime(heute.year, heute.month, heute.day))
            .inDays;
        return TileData.scalar(
          tage.abs().toDouble(),
          unit: tage == 0
              ? 'Heute!'
              : tage > 0
                  ? (tage == 1 ? 'Tag noch' : 'Tage noch')
                  : (tage == -1 ? 'Tag her' : 'Tage her'),
        );
      },
    ),

    // ── Aus den eigenen Daten ────────────────────────────────────────────
    TileSource(
      key: 'kopf.next_entry',
      route: AppRoutes.planner,
      fields: FilterFields.termine,
      label: 'Nächster Termin, groß',
      group: 'Planer',
      shape: TileShape.text,
      build: (d, p, f) {
        final jetzt = DateTime.now();
        final kommende = applyFilters(
                d.plannerEntries.cast<PlannerEntry>(), f, FilterFields.termine)
            .where((e) => e.parentId == null && e.scheduledAt.isAfter(jetzt))
            .toList()
          ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
        if (kommende.isEmpty) {
          return const TileData.text(null, emptyHint: 'Nichts mehr geplant');
        }
        final n = kommende.first;
        return TileData.text(n.title, footnote: _wannLang(n.scheduledAt));
      },
    ),

    TileSource(
      key: 'kopf.random_note',
      route: AppRoutes.notes,
      fields: FilterFields.notizen,
      label: 'Zufällige Notiz',
      group: 'Notizen',
      shape: TileShape.text,
      build: (d, p, f) {
        final notizen =
            applyFilters(d.notes.cast<Note>(), f, FilterFields.notizen)
                .where((n) => n.text.trim().isNotEmpty)
                .toList();
        if (notizen.isEmpty) {
          return const TileData.text(null, emptyHint: 'Keine Notizen');
        }
        // Nach Tag ausgewählt, nicht wirklich zufällig: sonst springt der
        // Text bei jedem Neuzeichnen und man kann ihn nicht zu Ende lesen.
        final n = notizen[_tagesZahl() % notizen.length];
        return TileData.text(_kuerzen(n.text, 280), footnote: n.title);
      },
    ),

    TileSource(
      key: 'kopf.journal_flashback',
      route: AppRoutes.journal,
      label: 'Journal-Rückblick',
      group: 'Journal',
      shape: TileShape.text,
      params: const [_jahre],
      build: (d, p, f) {
        final jahre = (p['jahre'] as num?)?.toInt() ?? 1;
        final heute = DateTime.now();
        final gesucht = DateTime(heute.year - jahre, heute.month, heute.day);
        for (final e in d.journalEntries.cast<JournalEntry>()) {
          if (e.date.year == gesucht.year &&
              e.date.month == gesucht.month &&
              e.date.day == gesucht.day) {
            return TileData.text(
              _kuerzen(e.content, 300),
              footnote: 'Vor $jahre ${jahre == 1 ? "Jahr" : "Jahren"}, '
                  '${e.date.day}.${e.date.month}.${e.date.year}',
            );
          }
        }
        return TileData.text(null,
            emptyHint: 'Vor $jahre ${jahre == 1 ? "Jahr" : "Jahren"} '
                'stand hier nichts');
      },
    ),

    TileSource(
      key: 'kopf.today',
      label: 'Der Tag in einer Zeile',
      group: 'Eigenes',
      shape: TileShape.text,
      build: (d, p, f) {
        final heute = DateTime.now();
        final termine = d.plannerEntries
            .cast<PlannerEntry>()
            .where((e) =>
                e.parentId == null &&
                e.scheduledAt.year == heute.year &&
                e.scheduledAt.month == heute.month &&
                e.scheduledAt.day == heute.day)
            .length;
        final offen =
            d.tasks.where((t) => t.kanbanState != 'done').length;
        final teile = <String>[
          termine == 0
              ? 'keine Termine'
              : '$termine ${termine == 1 ? "Termin" : "Termine"}',
          offen == 0
              ? 'keine offenen Aufgaben'
              : '$offen offene ${offen == 1 ? "Aufgabe" : "Aufgaben"}',
        ];
        return TileData.text('Heute: ${teile.join(", ")}.');
      },
    ),

    // ── Von draußen, über die eigene API ─────────────────────────────────
    TileSource(
      key: 'kopf.nachrichten',
      label: 'Nachrichten',
      group: 'Von draußen',
      shape: TileShape.list,
      extra: TileExtras.nachrichten,
      params: const [_meldungen],
      build: (d, p, f) {
        final wieViele = (p['anzahl'] as num?)?.toInt() ?? 3;
        final meldungen = d.nachrichten.cast<Meldung>();
        return TileData.list(
          meldungen.take(wieViele).map((m) => TileListItem(
                m.titel,
                subtitle: m.text.isEmpty ? m.quelle : _kuerzen(m.text, 140),
              )).toList(),
          emptyHint: 'Gerade keine Meldungen zu bekommen',
        );
      },
    ),

    TileSource(
      key: 'kopf.schlagzeile',
      label: 'Eine Schlagzeile, groß',
      group: 'Von draußen',
      shape: TileShape.text,
      extra: TileExtras.nachrichten,
      build: (d, p, f) {
        final meldungen = d.nachrichten.cast<Meldung>();
        if (meldungen.isEmpty) {
          return const TileData.text(null,
              emptyHint: 'Gerade keine Meldungen zu bekommen');
        }
        final m = meldungen.first;
        return TileData.text(m.titel,
            footnote: [m.ressort, m.quelle]
                .where((t) => t.isNotEmpty)
                .join(' · '));
      },
    ),

    TileSource(
      key: 'kopf.witz',
      label: 'Witz',
      group: 'Von draußen',
      shape: TileShape.text,
      extra: TileExtras.witz,
      build: (d, p, f) => TileData.text(
        d.witz,
        emptyHint: 'Der Witzanbieter schweigt gerade',
      ),
    ),

    // ── Sammlung im Programm ─────────────────────────────────────────────
    TileSource(
      key: 'kopf.quote',
      label: 'Spruch des Tages',
      group: 'Eigenes',
      shape: TileShape.text,
      build: (d, p, f) {
        final (spruch, wer) = _sprueche[_tagesZahl() % _sprueche.length];
        return TileData.text(spruch, footnote: wer);
      },
    ),
  ];
}

/// Eine Zahl, die sich täglich ändert und über den Tag gleich bleibt.
int _tagesZahl() {
  final h = DateTime.now();
  return h.year * 10000 + h.month * 100 + h.day;
}

String _kuerzen(String s, int max) {
  final t = s.trim().replaceAll(RegExp(r'\s+'), ' ');
  return t.length <= max ? t : '${t.substring(0, max)}…';
}

String _wannLang(DateTime d) {
  const tage = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];
  String zwei(int n) => n.toString().padLeft(2, '0');
  final heute = DateTime.now();
  final gleicherTag =
      d.year == heute.year && d.month == heute.month && d.day == heute.day;
  if (gleicherTag) return 'Heute um ${zwei(d.hour)}:${zwei(d.minute)}';
  return '${tage[d.weekday - 1]}, ${d.day}.${d.month}. um '
      '${zwei(d.hour)}:${zwei(d.minute)}';
}

/// Eine kleine Sammlung im Programm — kein Aufruf ins Internet, keine
/// Abhängigkeit von einem Dienst, der irgendwann verschwindet.
const List<(String, String)> _sprueche = [
  ('Es ist nicht wenig Zeit, die wir haben, sondern es ist viel Zeit, die wir nicht nutzen.', 'Seneca'),
  ('Der Weg entsteht, indem man ihn geht.', 'Franz Kafka'),
  ('Wer ein Warum zu leben hat, erträgt fast jedes Wie.', 'Friedrich Nietzsche'),
  ('Ordnung ist die Verbindung des Vielen nach einer Regel.', 'Immanuel Kant'),
  ('Man muss das Unmögliche versuchen, um das Mögliche zu erreichen.', 'Hermann Hesse'),
  ('Das Bessere ist der Feind des Guten.', 'Voltaire'),
  ('Wer nichts weiß, muss alles glauben.', 'Marie von Ebner-Eschenbach'),
  ('Erfahrung ist der Name, den jeder seinen Fehlern gibt.', 'Oscar Wilde'),
  ('Ein Tag ohne Lächeln ist ein verlorener Tag.', 'Charlie Chaplin'),
  ('Wo kein Wille ist, ist auch kein Weg.', 'Sprichwort'),
  ('Vertrauen ist gut, Nachrechnen ist besser.', 'Sprichwort'),
  ('Auch aus Steinen, die einem in den Weg gelegt werden, kann man Schönes bauen.', 'Johann Wolfgang von Goethe'),
  ('Der beste Zeitpunkt, einen Baum zu pflanzen, war vor zwanzig Jahren. Der zweitbeste ist jetzt.', 'Sprichwort'),
  ('Nicht weil es schwer ist, wagen wir es nicht, sondern weil wir es nicht wagen, ist es schwer.', 'Seneca'),
];
