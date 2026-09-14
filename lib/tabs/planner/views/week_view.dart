import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:productivity/dataclasses/planner_entry.dart';
import 'package:productivity/provider/planner_provider.dart';
import 'package:productivity/provider/settings_provider.dart';
import 'package:productivity/widgets/platform_draggable.dart';
import 'package:productivity/tabs/planner/widgets/planner_edit_dialog.dart';

class WeekView extends StatefulWidget {
  final DateTime selectedDate;

  /// Termin, der nach einem Tipp auf die Mitteilung hervorgehoben wird.
  final int? hervorgehoben;

  /// Wird gerufen, sobald der Nutzer selbst etwas antippt — dann hat die
  /// Hervorhebung ihren Zweck erfüllt.
  final VoidCallback? beiAuswahl;

  const WeekView({
    super.key,
    required this.selectedDate,
    this.hervorgehoben,
    this.beiAuswahl,
  });

  @override
  State<WeekView> createState() => _WeekViewState();
}

/// Welche Stunde beim Öffnen oben stehen soll.
///
/// Eigene Funktion, damit sie sich prüfen lässt: das Springen selbst
/// braucht einen Scroll-Controller mit echter Ausdehnung, die Entscheidung
/// dahinter ist reine Rechnung.
///
/// Zeigt die Ansicht eine andere Woche, sagt „jetzt" nichts über sie aus —
/// dann lieber beim Vormittag anfangen als bei Mitternacht. Mitternacht
/// wäre die schlechtere Antwort: man sähe sechs leere Stunden und müsste
/// erst scrollen.
double zielStunde({required DateTime jetzt, required DateTime wochenStart}) {
  final ende = wochenStart.add(const Duration(days: 7));
  final inDieserWoche = !jetzt.isBefore(wochenStart) && jetzt.isBefore(ende);
  return inDieserWoche ? jetzt.hour + jetzt.minute / 60.0 : 8.0;
}

class _WeekViewState extends State<WeekView> {
  static const double _hourHeight = 64.0;
  static const double _timeColumnWidth = 54.0;
  static const double _headerHeight = 64.0;
  static const int _snapMinutes = 15;

  late DateTime _weekStart;
  /// Wird in [initState] mit dem Zielversatz erzeugt — siehe dort, warum
  /// das nicht dasselbe ist wie „einmal hinspringen".
  late final ScrollController _scrollController;
  final List<GlobalKey> _dayKeys = List.generate(7, (_) => GlobalKey());

  /// Ob schon einmal zur passenden Stelle gesprungen wurde.
  ///
  /// Nur beim ersten Zeichnen: wer danach scrollt, will dort bleiben. Eine
  /// Ansicht, die beim naechsten Neuzeichnen zur Uhrzeit zurueckspringt,
  /// waere unbenutzbar.
  bool _gesprungen = false;

  /// Wo die Ansicht beginnen soll, in Pixeln.
  ///
  /// Eine Stunde Vorlauf, damit auch der eben vergangene Termin noch zu
  /// sehen ist; sonst klebt „jetzt" am oberen Rand.
  double _startVersatz() =>
      ((zielStunde(jetzt: DateTime.now(), wochenStart: _weekStart) - 1) *
              _hourHeight)
          .clamp(0.0, double.infinity);

  @override
  void initState() {
    super.initState();
    _weekStart = _getWeekStart(widget.selectedDate);
    // Der Versatz gehört an den Controller, nicht in einen einmaligen
    // Sprung. Grund: der Consumer tauscht das Raster gegen einen
    // Fortschrittskreis, sobald `loadEntries()` läuft — und damit
    // verschwindet die Scroll-Ansicht aus dem Baum. Ihre Position wird
    // verworfen, die nächste beginnt bei null.
    //
    // Ein Riegel im State hat sein Pulver dann längst verschossen: es wurde
    // ja gesprungen, nur ist das Ergebnis mit der alten Position gestorben.
    // Genau das war der gemeldete Fehler, und genau deshalb trat er in der
    // Küchenansicht nicht auf: die bekommt ihre Termine als Parameter und
    // kennt keinen Ladezustand.
    //
    // `initialScrollOffset` gilt dagegen für JEDE neu erzeugte Position.
    _scrollController = ScrollController(initialScrollOffset: _startVersatz());
  }

  @override
  void didUpdateWidget(WeekView alt) {
    super.didUpdateWidget(alt);
    // Kommt das Datum von aussen (Tipp auf eine Mitteilung), muss die
    // Ansicht mitwandern -- und dort auch wieder zur Uhrzeit springen.
    if (alt.selectedDate != widget.selectedDate) {
      _weekStart = _getWeekStart(widget.selectedDate);
      _gesprungen = false;
    }
  }

  /// Springt so, dass die aktuelle Stunde im Blick ist.
  ///
  /// Vorher stand hier eine feste 7 — und selbst die kam meist nicht an:
  /// der Sprung lag in `initState`, und im `TabBarView` hat der
  /// Scroll-Controller beim ersten Frame oft noch keine Ausdehnung.
  /// `maxScrollExtent` war dann 0, das `clamp` machte daraus 0, und die
  /// Ansicht begann bei Mitternacht. Deshalb steht der Aufruf jetzt in
  /// `build`: dort kommt er bei jedem Neuzeichnen wieder vorbei, bis er
  /// einmal geglueckt ist.
  ///
  /// Eine Stunde Vorlauf, damit auch der eben vergangene Termin noch zu
  /// sehen ist; sonst klebt „jetzt" am oberen Rand.
  /// Springt, wenn das Datum von aussen gewechselt hat.
  ///
  /// Den Normalfall erledigt `initialScrollOffset` (siehe [initState]).
  /// Hier geht es nur um den Wechsel im laufenden Betrieb — etwa nach
  /// einem Tipp auf eine Terminbenachrichtigung, der auf eine andere Woche
  /// führt. Dabei bleibt die Position bestehen, also muss von Hand
  /// gesprungen werden.
  void _springeZurUhrzeit() {
    if (_gesprungen) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final maximum = _scrollController.position.maxScrollExtent;
      // Noch nicht ausgemessen: beim naechsten Zeichnen erneut versuchen,
      // statt den Versuch zu verbrauchen.
      if (maximum <= 0) return;
      _gesprungen = true;
      _scrollController.jumpTo(_startVersatz().clamp(0.0, maximum));
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  DateTime _getWeekStart(DateTime date) {
    final d = date.subtract(Duration(days: date.weekday - 1));
    // Auf Mitternacht normalisieren, sonst fallen Termine, die früher als die
    // aktuelle Uhrzeit am Montag liegen, aus dem Wochenfilter heraus.
    return DateTime(d.year, d.month, d.day);
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    return Consumer2<PlannerProvider, SettingsProvider>(
      builder: (context, plannerProvider, settingsProvider, child) {
        if (plannerProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final theme = Theme.of(context);
        final alle = plannerProvider.getEntriesForWeek(_weekStart);
        // Ganztaegige gehoeren nicht ins Stundenraster: dort fuellten sie
        // die komplette Tagesspalte und draengten alles Uebrige an den
        // Rand. Genau so kommen Muellabfuhr, Feiertage und Ferien herein.
        final ganztags = alle.where((e) => e.istGanztaegig).toList();
        final entries = alle.where((e) => !e.istGanztaegig).toList();
        final daysOfWeek = List.generate(
          7,
          (i) => _weekStart.add(Duration(days: i)),
        );
        final use24h = settingsProvider.use24hFormat;
        final weekEnd = _weekStart.add(const Duration(days: 6));
        final now = DateTime.now();

        _springeZurUhrzeit();

        return Column(
          children: [
            _buildNavHeader(theme, weekEnd),
            _buildDayHeaders(theme, daysOfWeek, now),
            // Ueber dem Raster und ausserhalb des Scrollbereichs: ein
            // Feiertag soll auch dann zu sehen sein, wenn man beim
            // Nachmittag steht.
            if (ganztags.isNotEmpty)
              _ganztagsStreifen(context, theme, daysOfWeek, ganztags),
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                child: SizedBox(
                  height: 24 * _hourHeight,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTimeColumn(theme, use24h),
                      ...List.generate(daysOfWeek.length, (index) {
                        final day = daysOfWeek[index];
                        final dayEntries =
                            entries
                                .where((e) => _isSameDay(e.scheduledAt, day))
                                .toList()
                              ..sort(
                                (a, b) =>
                                    a.scheduledAt.compareTo(b.scheduledAt),
                              );
                        return Expanded(
                          child: _buildDayColumn(
                            context,
                            theme,
                            day,
                            index,
                            dayEntries,
                            now,
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Ganztägige Termine über dem Raster.
  ///
  /// Anders als die Kachelfassung zeigt dieser **alle** eines Tages, nicht
  /// nur den ersten. Feiertag und Schulferien fallen regelmäßig zusammen —
  /// dort verschwand dann einer von beiden, ohne Hinweis.
  ///
  /// Die Höhe wächst mit dem vollsten Tag, damit nichts abgeschnitten wird.
  Widget _ganztagsStreifen(BuildContext context, ThemeData theme,
      List<DateTime> tage, List<PlannerEntry> ganztags) {
    const zeilenHoehe = 22.0;

    final jeTag = [
      for (final tag in tage)
        ganztags.where((e) => _ueberlappt(e, tag)).toList(),
    ];
    final meiste = jeTag.fold<int>(0, (m, l) => l.length > m ? l.length : m);

    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: theme.dividerColor.withValues(alpha: 0.5)),
        ),
      ),
      child: SizedBox(
        height: meiste * zeilenHoehe + 6,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: _timeColumnWidth,
              child: Padding(
                padding: const EdgeInsets.only(top: 5, right: 4),
                child: Text(
                  'ganztags',
                  textAlign: TextAlign.right,
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: theme.hintColor, fontSize: 9),
                ),
              ),
            ),
            for (var i = 0; i < tage.length; i++)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final e in jeTag[i])
                      GestureDetector(
                        onTap: () {
                          widget.beiAuswahl?.call();
                          _showEditEntryDialog(context, e);
                        },
                        child: Container(
                          height: zeilenHoehe - 4,
                          margin: const EdgeInsets.symmetric(
                              horizontal: 1, vertical: 2),
                          padding:
                              const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            color: _getColorFromHex(e.color)
                                .withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          alignment: Alignment.centerLeft,
                          child: Text(
                            e.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 10, color: Colors.white),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Liegt der mehrtägige Termin auf diesem Tag?
  ///
  /// Nicht nur der Anfangstag: Schulferien fangen einmal an und dauern zwei
  /// Wochen. Wer nur `scheduledAt` vergleicht, sieht sie am Montag und
  /// danach nie wieder.
  bool _ueberlappt(PlannerEntry e, DateTime tag) {
    final beginn = DateTime(tag.year, tag.month, tag.day);
    final ende = beginn.add(const Duration(days: 1));
    return e.scheduledAt.isBefore(ende) && e.endsAt.isAfter(beginn);
  }

  Widget _buildNavHeader(ThemeData theme, DateTime weekEnd) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            style: IconButton.styleFrom(
              backgroundColor: theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.4),
            ),
            onPressed: () => setState(() {
              _weekStart = _weekStart.subtract(const Duration(days: 7));
            }),
            icon: const Icon(Icons.chevron_left),
          ),
          Column(
            children: [
              Text(
                '${_weekStart.day}. ${_monthShort(_weekStart.month)} – ${weekEnd.day}. ${_monthShort(weekEnd.month)}',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'KW ${_weekNumber(_weekStart)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.hintColor,
                ),
              ),
            ],
          ),
          IconButton(
            style: IconButton.styleFrom(
              backgroundColor: theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.4),
            ),
            onPressed: () => setState(() {
              _weekStart = _weekStart.add(const Duration(days: 7));
            }),
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }

  Widget _buildDayHeaders(
    ThemeData theme,
    List<DateTime> daysOfWeek,
    DateTime now,
  ) {
    return Container(
      height: _headerHeight,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: theme.dividerColor.withValues(alpha: 0.4)),
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: _timeColumnWidth),
          ...daysOfWeek.map((day) {
            final dayIndex = day.weekday - 1;
            final dayName = [
              'MO',
              'DI',
              'MI',
              'DO',
              'FR',
              'SA',
              'SO',
            ][dayIndex];
            final isToday = _isSameDay(day, now);
            final isWeekend = day.weekday >= 6;
            return Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      dayName,
                      style: TextStyle(
                        color: isToday
                            ? theme.colorScheme.primary
                            : (isWeekend
                                  ? theme.hintColor.withValues(alpha: 0.7)
                                  : theme.hintColor),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isToday ? theme.colorScheme.primary : null,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        day.day.toString(),
                        style: TextStyle(
                          color: isToday
                              ? theme.colorScheme.onPrimary
                              : theme.textTheme.titleMedium?.color,
                          fontSize: 18,
                          fontWeight: isToday
                              ? FontWeight.bold
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTimeColumn(ThemeData theme, bool use24h) {
    return SizedBox(
      width: _timeColumnWidth,
      child: Column(
        children: List.generate(24, (index) {
          return SizedBox(
            height: _hourHeight,
            child: index == 0
                ? null
                : Align(
                    alignment: Alignment.topRight,
                    child: Transform.translate(
                      offset: const Offset(0, -7),
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Text(
                          _formatHour(index, use24h),
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.hintColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
          );
        }),
      ),
    );
  }

  Widget _buildDayColumn(
    BuildContext context,
    ThemeData theme,
    DateTime day,
    int dayIndex,
    List<PlannerEntry> dayEntries,
    DateTime now,
  ) {
    final isToday = _isSameDay(day, now);
    final lineColor = theme.dividerColor.withValues(alpha: 0.25);

    return DragTarget<PlannerEntry>(
      onAcceptWithDetails: (details) =>
          _handleDrop(context, day, dayIndex, details.data, details.offset),
      builder: (context, candidate, rejected) {
        return Container(
          key: _dayKeys[dayIndex],
          decoration: BoxDecoration(
            color: candidate.isNotEmpty
                ? theme.colorScheme.primary.withValues(alpha: 0.10)
                : (isToday
                      ? theme.colorScheme.primary.withValues(alpha: 0.04)
                      : null),
            border: Border(left: BorderSide(color: lineColor)),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final laid = _layoutDay(dayEntries);
              return Stack(
                children: [
                  Column(
                    children: List.generate(24, (hour) {
                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _showCreateEntryDialog(
                          context,
                          DateTime(day.year, day.month, day.day, hour, 0),
                        ),
                        child: Container(
                          height: _hourHeight,
                          decoration: BoxDecoration(
                            border: Border(top: BorderSide(color: lineColor)),
                          ),
                        ),
                      );
                    }),
                  ),
                  ...laid.map(
                    (l) => _buildEntryCard(
                        context, theme, l, constraints.maxWidth),
                  ),
                  if (isToday) _buildNowIndicator(now),
                ],
              );
            },
          ),
        );
      },
    );
  }

  /// Berechnet Spalten für überlappende Termine (inkl. Parent/Child zur selben
  /// Zeit), damit sie nebeneinander statt übereinander liegen.
  List<_LaidOut> _layoutDay(List<PlannerEntry> entries) {
    final sorted = [...entries]..sort((a, b) {
        final s = a.scheduledAt.compareTo(b.scheduledAt);
        if (s != 0) return s;
        return b.endsAt.compareTo(a.endsAt);
      });

    final result = <_LaidOut>[];
    var cluster = <PlannerEntry>[];
    DateTime? clusterEnd;

    void flush() {
      if (cluster.isEmpty) return;
      final colEnds = <DateTime>[];
      final assign = <PlannerEntry, int>{};
      for (final e in cluster) {
        var placed = -1;
        for (var i = 0; i < colEnds.length; i++) {
          if (!e.scheduledAt.isBefore(colEnds[i])) {
            placed = i;
            colEnds[i] = e.endsAt;
            break;
          }
        }
        if (placed == -1) {
          placed = colEnds.length;
          colEnds.add(e.endsAt);
        }
        assign[e] = placed;
      }
      final cols = colEnds.length;
      for (final e in cluster) {
        result.add(_LaidOut(e, assign[e]!, cols));
      }
      cluster = [];
      clusterEnd = null;
    }

    for (final e in sorted) {
      if (cluster.isNotEmpty &&
          clusterEnd != null &&
          !e.scheduledAt.isBefore(clusterEnd!)) {
        flush();
      }
      cluster.add(e);
      clusterEnd = (clusterEnd == null || e.endsAt.isAfter(clusterEnd!))
          ? e.endsAt
          : clusterEnd;
    }
    flush();
    return result;
  }

  void _handleDrop(
    BuildContext context,
    DateTime day,
    int dayIndex,
    PlannerEntry entry,
    Offset globalOffset,
  ) {
    final box =
        _dayKeys[dayIndex].currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final local = box.globalToLocal(globalOffset);
    var minutes = (local.dy / _hourHeight * 60).round();
    minutes = (minutes / _snapMinutes).round() * _snapMinutes;
    minutes = minutes.clamp(0, 24 * 60 - _snapMinutes);

    final newStart = DateTime(
      day.year,
      day.month,
      day.day,
    ).add(Duration(minutes: minutes));
    final duration = entry.endsAt.difference(entry.scheduledAt);
    final newEnd = newStart.add(duration);

    context.read<PlannerProvider>().moveEntry(
      entry.id,
      scheduledAt: newStart,
      endsAt: newEnd,
    );
  }

  Widget _buildEntryCard(
    BuildContext context,
    ThemeData theme,
    _LaidOut laid,
    double dayWidth,
  ) {
    final entry = laid.entry;
    final isChild = entry.parentId != null;
    final color = _getColorFromHex(entry.color);
    final start = entry.scheduledAt;
    final top = (start.hour + start.minute / 60.0) * _hourHeight;
    final durationMin = entry.endsAt.difference(start).inMinutes;
    final height = ((durationMin / 60.0) * _hourHeight).clamp(
      22.0,
      double.infinity,
    );
    final isCompact = height < 40;

    // Spaltenbreite bei Überlappung
    const gap = 2.0;
    final colWidth = dayWidth / laid.columns;
    final left = laid.column * colWidth + gap;
    final width = (colWidth - gap * 1.5).clamp(8.0, double.infinity);
    // Bei sehr schmalen Karten Icons/Padding reduzieren, sonst Overflow.
    final showIcons = width > 36;
    final hPad = width < 26 ? 2.0 : 6.0;

    // Nach einem Tipp auf die Mitteilung: der gemeinte Termin bekommt einen
    // Rahmen ringsum. Der farbige Balken links traegt schon den Kalender --
    // ihn nur dicker zu machen waere zu leise, um den Blick zu lenken.
    final gesucht = widget.hervorgehoben != null &&
        entry.id == widget.hervorgehoben;

    final cardContent = Container(
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: color.withValues(alpha: gesucht ? 0.42 : (isChild ? 0.16 : 0.22)),
        borderRadius: BorderRadius.circular(7),
        border: gesucht
            ? Border.all(color: theme.colorScheme.primary, width: 2.5)
            : Border(
                left: BorderSide(color: color, width: isChild ? 2.5 : 3.5),
              ),
      ),
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (showIcons && isChild)
                Padding(
                  padding: const EdgeInsets.only(right: 2),
                  child: Icon(
                    Icons.subdirectory_arrow_right,
                    size: 11,
                    color: Color.lerp(color, Colors.white, 0.65),
                  ),
                ),
              if (showIcons && entry.recurrenceId != null)
                Padding(
                  padding: const EdgeInsets.only(right: 3),
                  child: Icon(
                    Icons.repeat,
                    size: 11,
                    color: Color.lerp(color, Colors.white, 0.65),
                  ),
                ),
              Expanded(
                child: Text(
                  entry.title,
                  style: TextStyle(
                    color: Color.lerp(color, Colors.white, 0.65),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    height: 1.1,
                  ),
                  maxLines: isCompact ? 1 : 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (!isCompact) ...[
            const SizedBox(height: 2),
            Text(
              '${_formatClock(start)} – ${_formatClock(entry.endsAt)}',
              style: TextStyle(
                color: Color.lerp(color, Colors.white, 0.4),
                fontSize: 9,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );

    return Positioned(
      top: top + 1,
      left: left,
      width: width,
      height: height - 2,
      child: platformDraggable<PlannerEntry>(
        data: entry,
        feedback: Material(
          color: Colors.transparent,
          child: Opacity(
            opacity: 0.9,
            child: SizedBox(
              width: width,
              height: height - 2,
              child: cardContent,
            ),
          ),
        ),
        childWhenDragging: Opacity(opacity: 0.3, child: cardContent),
        child: GestureDetector(
          onTap: () {
            // Wer selbst etwas antippt, braucht den Wegweiser nicht mehr.
            widget.beiAuswahl?.call();
            _showEditEntryDialog(context, entry);
          },
          child: cardContent,
        ),
      ),
    );
  }

  Widget _buildNowIndicator(DateTime now) {
    final top = (now.hour + now.minute / 60.0) * _hourHeight;
    return Positioned(
      top: top - 4,
      left: 0,
      right: 0,
      child: Row(
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: const BoxDecoration(
              color: Color(0xFFE53935),
              shape: BoxShape.circle,
            ),
          ),
          Expanded(child: Container(height: 2, color: const Color(0xFFE53935))),
        ],
      ),
    );
  }

  String _formatHour(int hour, bool use24h) {
    if (use24h) return '${hour.toString().padLeft(2, '0')}:00';
    final h = hour % 12 == 0 ? 12 : hour % 12;
    final period = hour < 12 ? 'AM' : 'PM';
    return '$h $period';
  }

  String _formatClock(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  String _monthShort(int month) {
    const m = [
      'Jan',
      'Feb',
      'Mär',
      'Apr',
      'Mai',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Okt',
      'Nov',
      'Dez',
    ];
    return m[month - 1];
  }

  int _weekNumber(DateTime date) {
    final dayOfYear = DateTime(
      date.year,
      date.month,
      date.day,
    ).difference(DateTime(date.year, 1, 1)).inDays;
    return ((dayOfYear - date.weekday + 10) / 7).floor();
  }

  Color _getColorFromHex(String hexColor) {
    hexColor = hexColor.replaceFirst('#', '');
    return Color(int.parse('FF$hexColor', radix: 16));
  }

  void _showCreateEntryDialog(BuildContext context, DateTime scheduledAt) {
    showDialog(
      context: context,
      builder: (context) => PlannerEditDialog(
        initialScheduledAt: scheduledAt,
        initialEndsAt: scheduledAt.add(const Duration(hours: 1)),
        onSubmit: (result, scope) =>
            _submitNew(context.read<PlannerProvider>(), result),
      ),
    );
  }

  void _showEditEntryDialog(BuildContext context, PlannerEntry entry) {
    final provider = context.read<PlannerProvider>();
    showDialog(
      context: context,
      builder: (context) => PlannerEditDialog(
        entry: entry,
        onDelete: (scope) {
          if (entry.recurrenceId != null) {
            provider.deleteSeriesEntry(entry.id, scope ?? 'single');
          } else {
            provider.deleteEntry(entry.id);
          }
        },
        onSubmit: (result, scope) {
          if (entry.recurrenceId != null) {
            provider.updateSeriesEntry(
              entry.id,
              scope ?? 'single',
              title: result.title,
              description: result.description,
              typeId: result.typeId,
              scheduledAt: result.scheduledAt,
              endsAt: result.endsAt,
              notifyMinBefore: result.notifyMinBefore,
              color: result.color,
            );
          } else {
            provider.updateEntry(
              entry.id,
              title: result.title,
              description: result.description,
              typeId: result.typeId,
              scheduledAt: result.scheduledAt,
              endsAt: result.endsAt,
              notifyMinBefore: result.notifyMinBefore,
              color: result.color,
            );
          }
        },
      ),
    );
  }

  void _submitNew(PlannerProvider provider, PlannerFormResult result) {
    if (result.recurrence != null) {
      provider.createRecurringEntry(
        title: result.title,
        description: result.description,
        typeId: result.typeId,
        scheduledAt: result.scheduledAt,
        endsAt: result.endsAt,
        notifyMinBefore: result.notifyMinBefore,
        color: result.color,
        recurrence: result.recurrence!.toJson(),
      );
    } else {
      provider.createEntry(
        title: result.title,
        description: result.description,
        typeId: result.typeId,
        scheduledAt: result.scheduledAt,
        endsAt: result.endsAt,
        notifyMinBefore: result.notifyMinBefore,
        color: result.color,
        participantIds: result.participantIds,
        calendarId: result.calendarId,
      );
    }
  }
}

/// Termin mit zugewiesener Spalte für das Überlappungs-Layout.
class _LaidOut {
  final PlannerEntry entry;
  final int column;
  final int columns;
  _LaidOut(this.entry, this.column, this.columns);
}
