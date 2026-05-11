import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:productivity/main.dart';
import 'package:productivity/dataclasses/task.dart';
import 'package:productivity/dataclasses/time_entry.dart';
import 'package:productivity/dataclasses/journal_entry.dart';
import 'package:productivity/dataclasses/meal_plan.dart';
import 'package:productivity/dataclasses/pantry_item.dart';
import 'package:productivity/dataclasses/ingredient.dart';
import 'package:productivity/dataservice/task_service.dart';
import 'package:productivity/dataservice/time_entry_service.dart';
import 'package:productivity/dataservice/journal_service.dart';
import 'package:productivity/dataservice/meal_plan_service.dart';
import 'package:productivity/dataservice/pantry_service.dart';
import 'package:productivity/dataservice/ingredient_service.dart';

class CalendarPage extends BasePage {
  const CalendarPage({super.key}) : super(title: 'Kalender');

  @override
  Widget buildBody(BuildContext context) => const _CalendarPageContent();
}

class _CalendarPageContent extends StatefulWidget {
  const _CalendarPageContent();

  @override
  State<_CalendarPageContent> createState() => _CalendarPageContentState();
}

class _CalendarPageContentState extends State<_CalendarPageContent> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  CalendarFormat _calendarFormat = CalendarFormat.month;
  bool _isLoading = true;

  List<Task> _tasks = [];
  List<TimeEntry> _timeEntries = [];
  List<JournalEntry> _journals = [];
  List<MealPlanEntry> _mealPlans = [];
  List<PantryItem> _pantryItems = [];
  Map<String, String> _ingredientNames = {};

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);

    try {
      final results = await Future.wait([
        TaskService.loadAll(),
        TimeEntryService.loadAll(),
        JournalService.loadAll(),
        MealPlanService.loadAll(),
        PantryService.loadAll(),
        IngredientService.loadAll(),
      ]);

      final ingredients = results[5] as List<Ingredient>;
      final nameMap = <String, String>{};
      for (final i in ingredients) {
        nameMap[i.id] = i.name;
      }

      setState(() {
        _tasks = results[0] as List<Task>;
        _timeEntries = results[1] as List<TimeEntry>;
        _journals = results[2] as List<JournalEntry>;
        _mealPlans = results[3] as List<MealPlanEntry>;
        _pantryItems = results[4] as List<PantryItem>;
        _ingredientNames = nameMap;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler beim Laden: $e')),
        );
      }
    }
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  List<_CalendarEvent> _getEventsForDay(DateTime day) {
    final events = <_CalendarEvent>[];

    for (final task in _tasks) {
      if (task.dueDate != null && _isSameDay(task.dueDate!, day)) {
        events.add(_CalendarEvent(
          title: task.title,
          type: _EventType.task,
          subtitle: task.completed ? 'Erledigt' : 'Offen – ${task.priority}',
          completed: task.completed,
        ));
      }
    }

    for (final entry in _timeEntries) {
      if (_isSameDay(entry.date, day)) {
        events.add(_CalendarEvent(
          title: entry.description.isEmpty ? 'Zeiterfassung' : entry.description,
          type: _EventType.time,
          subtitle: entry.formattedDuration,
        ));
      }
    }

    for (final journal in _journals) {
      if (_isSameDay(journal.date, day)) {
        final preview = journal.content.length > 60
            ? '${journal.content.substring(0, 60)}...'
            : journal.content;
        events.add(_CalendarEvent(
          title: 'Journal',
          type: _EventType.journal,
          subtitle: preview,
        ));
      }
    }

    for (final meal in _mealPlans) {
      if (_isSameDay(meal.date, day)) {
        events.add(_CalendarEvent(
          title: meal.mealType ?? 'Gericht',
          type: _EventType.meal,
          subtitle: '${meal.servings} Portionen',
        ));
      }
    }

    for (final item in _pantryItems) {
      if (item.expiryDate != null && _isSameDay(item.expiryDate!, day)) {
        final name = _ingredientNames[item.ingredientId] ?? 'Vorrat';
        events.add(_CalendarEvent(
          title: name,
          type: _EventType.pantry,
          subtitle: 'Läuft ab',
        ));
      }
    }

    return events;
  }

  Map<DateTime, List<_CalendarEvent>> _buildEventMap() {
    final map = <DateTime, List<_CalendarEvent>>{};

    void addToMap(DateTime date, _CalendarEvent event) {
      final key = DateTime(date.year, date.month, date.day);
      map.putIfAbsent(key, () => []).add(event);
    }

    for (final task in _tasks) {
      if (task.dueDate != null) {
        addToMap(task.dueDate!, _CalendarEvent(
          title: task.title,
          type: _EventType.task,
          completed: task.completed,
        ));
      }
    }
    for (final entry in _timeEntries) {
      addToMap(entry.date, _CalendarEvent(title: '', type: _EventType.time));
    }
    for (final journal in _journals) {
      addToMap(journal.date, _CalendarEvent(title: '', type: _EventType.journal));
    }
    for (final meal in _mealPlans) {
      addToMap(meal.date, _CalendarEvent(title: '', type: _EventType.meal));
    }
    for (final item in _pantryItems) {
      if (item.expiryDate != null) {
        addToMap(item.expiryDate!, _CalendarEvent(title: '', type: _EventType.pantry));
      }
    }

    return map;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: colors.primary));
    }

    final eventMap = _buildEventMap();
    final selectedEvents = _getEventsForDay(_selectedDay);

    return RefreshIndicator(
      onRefresh: _loadAllData,
      child: ListView(
        children: [
          TableCalendar<_CalendarEvent>(
            locale: 'de_DE',
            firstDay: DateTime(2020),
            lastDay: DateTime(2030),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => _isSameDay(day, _selectedDay),
            calendarFormat: _calendarFormat,
            onFormatChanged: (format) {
              setState(() => _calendarFormat = format);
            },
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            onPageChanged: (focusedDay) {
              _focusedDay = focusedDay;
            },
            eventLoader: (day) {
              final key = DateTime(day.year, day.month, day.day);
              return eventMap[key] ?? [];
            },
            calendarStyle: CalendarStyle(
              markerDecoration: BoxDecoration(
                color: colors.primary,
                shape: BoxShape.circle,
              ),
              markerSize: 6,
              markersMaxCount: 4,
              todayDecoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              selectedDecoration: BoxDecoration(
                color: colors.primary,
                shape: BoxShape.circle,
              ),
              outsideDaysVisible: false,
            ),
            headerStyle: HeaderStyle(
              formatButtonVisible: true,
              titleCentered: true,
              formatButtonDecoration: BoxDecoration(
                border: Border.all(color: colors.outline),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Legende
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 12,
              runSpacing: 4,
              children: _EventType.values.map((type) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(type.icon, size: 14, color: type.color),
                    const SizedBox(width: 4),
                    Text(type.label, style: text.labelSmall),
                  ],
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          Divider(height: 1, color: colors.outline.withValues(alpha: 0.2)),
          // Tages-Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              DateFormat('EEEE, d. MMMM yyyy', 'de_DE').format(_selectedDay),
              style: text.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          // Events
          if (selectedEvents.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.event_busy, size: 48, color: colors.onSurfaceVariant),
                    const SizedBox(height: 8),
                    Text(
                      'Keine Einträge',
                      style: text.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            )
          else
            ...selectedEvents.map((event) => _buildEventTile(event, colors, text)),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildEventTile(_CalendarEvent event, ColorScheme colors, TextTheme text) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      color: colors.surfaceContainerHighest,
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: event.type.color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(event.type.icon, color: event.type.color, size: 20),
        ),
        title: Text(
          event.title,
          style: text.titleSmall?.copyWith(
            decoration: event.completed ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: event.subtitle != null
            ? Text(
                event.subtitle!,
                style: text.bodySmall?.copyWith(color: colors.onSurfaceVariant),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              )
            : null,
        trailing: Chip(
          label: Text(event.type.label),
          labelStyle: text.labelSmall?.copyWith(color: event.type.color),
          side: BorderSide(color: event.type.color.withValues(alpha: 0.3)),
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
        ),
      ),
    );
  }
}

enum _EventType {
  task(Icons.task_alt, Colors.blue, 'Task'),
  time(Icons.schedule, Colors.orange, 'Zeit'),
  journal(Icons.book, Colors.purple, 'Journal'),
  meal(Icons.restaurant, Colors.green, 'Gericht'),
  pantry(Icons.warning_amber, Colors.red, 'Ablauf');

  final IconData icon;
  final Color color;
  final String label;

  const _EventType(this.icon, this.color, this.label);
}

class _CalendarEvent {
  final String title;
  final _EventType type;
  final String? subtitle;
  final bool completed;

  const _CalendarEvent({
    required this.title,
    required this.type,
    this.subtitle,
    this.completed = false,
  });
}
