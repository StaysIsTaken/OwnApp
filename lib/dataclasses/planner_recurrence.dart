/// Eine ausgelassene Serien-Ausnahme (z.B. einzeln gelöschter Termin).
class PlannerException {
  final int id;
  final DateTime excludedAt;

  PlannerException({required this.id, required this.excludedAt});

  factory PlannerException.fromJson(Map<String, dynamic> json) {
    return PlannerException(
      id: json['id'] ?? 0,
      excludedAt: DateTime.parse(json['excluded_at']),
    );
  }
}

/// Eingabe-Werte für eine Wiederholungsregel (an das Backend gesendet).
class RecurrenceInput {
  final String freq; // 'DAILY' | 'WEEKLY' | 'MONTHLY' | 'YEARLY'
  final int interval;
  final String? byweekday; // 'MO,WE,FR'
  final int? bymonthday;
  final DateTime? untilDate;
  final int? countN;

  const RecurrenceInput({
    required this.freq,
    this.interval = 1,
    this.byweekday,
    this.bymonthday,
    this.untilDate,
    this.countN,
  });

  Map<String, dynamic> toJson() {
    return {
      'freq': freq,
      'interval_n': interval,
      'byweekday': byweekday,
      'bymonthday': bymonthday,
      'until_date': untilDate == null
          ? null
          : '${untilDate!.year.toString().padLeft(4, '0')}-${untilDate!.month.toString().padLeft(2, '0')}-${untilDate!.day.toString().padLeft(2, '0')}',
      'count_n': countN,
    };
  }
}
