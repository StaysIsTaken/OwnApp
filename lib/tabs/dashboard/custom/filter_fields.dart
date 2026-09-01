import 'package:productivity/dataclasses/note.dart';
import 'package:productivity/dataclasses/pantry_extras.dart';
import 'package:productivity/dataclasses/pantry_item.dart';
import 'package:productivity/dataclasses/planner_entry.dart';
import 'package:productivity/dataclasses/task.dart';
import 'package:productivity/dataclasses/time_entry.dart';
import 'package:productivity/tabs/dashboard/custom/tile_filter.dart';

/// Welche Felder je Datenart gefiltert werden können.
///
/// Bewusst nicht jede Spalte: interne Schlüssel (userId, ids) helfen niemandem
/// beim Filtern und würden die Auswahl unübersichtlich machen. Ein Feld
/// ergänzen heißt: eine Zeile hier.
class FilterFields {
  FilterFields._();

  static Map<String, FilterField> _map(List<FilterField> felder) =>
      {for (final f in felder) f.key: f};

  // ── Zeiterfassung ────────────────────────────────────────────────────────
  static final zeiten = _map([
    FilterField(
      key: 'date', label: 'Datum', type: FieldType.date,
      read: (e) => (e as TimeEntry).date,
    ),
    FilterField(
      key: 'duration', label: 'Dauer in Stunden', type: FieldType.number,
      read: (e) {
        final t = e as TimeEntry;
        if (t.endTime == null) return null;
        return t.endTime!.difference(t.startTime).inMinutes / 60.0;
      },
    ),
    FilterField(
      key: 'description', label: 'Beschreibung', type: FieldType.text,
      read: (e) => (e as TimeEntry).description,
    ),
    FilterField(
      key: 'running', label: 'Läuft noch', type: FieldType.boolean,
      read: (e) => (e as TimeEntry).endTime == null,
    ),
  ]);

  // ── Aufgaben ─────────────────────────────────────────────────────────────
  static final aufgaben = _map([
    FilterField(
      key: 'title', label: 'Titel', type: FieldType.text,
      read: (e) => (e as Task).title,
    ),
    FilterField(
      key: 'priority', label: 'Priorität', type: FieldType.choice,
      choices: const ['low', 'medium', 'high'],
      read: (e) => (e as Task).priority,
    ),
    FilterField(
      key: 'kanbanState', label: 'Spalte', type: FieldType.choice,
      choices: const ['todo', 'in_progress', 'done'],
      read: (e) => (e as Task).kanbanState,
    ),
    FilterField(
      key: 'category', label: 'Kategorie', type: FieldType.text,
      read: (e) => (e as Task).category,
    ),
    FilterField(
      key: 'completed', label: 'Erledigt', type: FieldType.boolean,
      read: (e) => (e as Task).completed,
    ),
    FilterField(
      key: 'dueDate', label: 'Fällig am', type: FieldType.date,
      read: (e) => (e as Task).dueDate,
    ),
  ]);

  // ── Termine ──────────────────────────────────────────────────────────────
  static final termine = _map([
    FilterField(
      key: 'title', label: 'Titel', type: FieldType.text,
      read: (e) => (e as PlannerEntry).title,
    ),
    FilterField(
      key: 'description', label: 'Beschreibung', type: FieldType.text,
      read: (e) => (e as PlannerEntry).description,
    ),
    FilterField(
      key: 'scheduledAt', label: 'Beginn', type: FieldType.date,
      read: (e) => (e as PlannerEntry).scheduledAt,
    ),
    FilterField(
      key: 'durationMin', label: 'Dauer in Minuten', type: FieldType.number,
      read: (e) => (e as PlannerEntry).durationMin,
    ),
    FilterField(
      key: 'type', label: 'Typ', type: FieldType.text,
      read: (e) => (e as PlannerEntry).type,
    ),
  ]);

  // ── Vorrat ───────────────────────────────────────────────────────────────
  static final vorrat = _map([
    FilterField(
      key: 'amount', label: 'Bestand', type: FieldType.number,
      read: (e) => (e as PantryItem).amount,
    ),
    FilterField(
      key: 'minAmount', label: 'Mindestbestand', type: FieldType.number,
      read: (e) => (e as PantryItem).minAmount,
    ),
    FilterField(
      key: 'expiryDate', label: 'Läuft ab am', type: FieldType.date,
      read: (e) => (e as PantryItem).expiryDate,
    ),
  ]);

  // ── Einkaufsliste ────────────────────────────────────────────────────────
  static final einkauf = _map([
    FilterField(
      key: 'amount', label: 'Menge', type: FieldType.number,
      read: (e) => (e as ShoppingListItem).amount,
    ),
    FilterField(
      key: 'isBought', label: 'Gekauft', type: FieldType.boolean,
      read: (e) => (e as ShoppingListItem).isBought,
    ),
    FilterField(
      key: 'note', label: 'Notiz', type: FieldType.text,
      read: (e) => (e as ShoppingListItem).note,
    ),
  ]);

  // ── Notizen ──────────────────────────────────────────────────────────────
  static final notizen = _map([
    FilterField(
      key: 'title', label: 'Titel', type: FieldType.text,
      read: (e) => (e as Note).title,
    ),
    FilterField(
      key: 'text', label: 'Inhalt', type: FieldType.text,
      read: (e) => (e as Note).text,
    ),
    FilterField(
      key: 'updatedAt', label: 'Zuletzt geändert', type: FieldType.date,
      read: (e) => (e as Note).updatedAt ?? (e).createdAt,
    ),
  ]);
}
