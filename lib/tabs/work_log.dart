import 'package:flutter/material.dart';
import 'package:productivity/dataservice/work_task_service.dart';
import 'package:productivity/main.dart';
import 'package:productivity/models/work_task.dart';

// ─────────────────────────────────────────────
//  Date / Time helpers
// ─────────────────────────────────────────────
String _fmtDateTime(DateTime dt) {
  final d = dt.day.toString().padLeft(2, '0');
  final mo = dt.month.toString().padLeft(2, '0');
  final y = dt.year.toString();
  final h = dt.hour.toString().padLeft(2, '0');
  final mi = dt.minute.toString().padLeft(2, '0');
  return '$d.$mo.$y $h:$mi';
}

DateTime? _parseDateTime(String s) {
  try {
    final parts = s.trim().split(' ');
    if (parts.length != 2) return null;
    final dp = parts[0].split('.');
    final tp = parts[1].split(':');
    if (dp.length != 3 || tp.length != 2) return null;
    return DateTime(
      int.parse(dp[2]),
      int.parse(dp[1]),
      int.parse(dp[0]),
      int.parse(tp[0]),
      int.parse(tp[1]),
    );
  } catch (_) {
    return null;
  }
}

String _fmtDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  if (h > 0) return '${h}h ${m}min';
  return '${m}min';
}

// ─────────────────────────────────────────────
//  WorkLogPage
// ─────────────────────────────────────────────
class WorkLogPage extends StatefulWidget {
  const WorkLogPage({super.key});

  @override
  State<WorkLogPage> createState() => _WorkLogPageState();
}

class _WorkLogPageState extends State<WorkLogPage> {
  List<WorkTask> _tasks = [];
  String _filter = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final tasks = await WorkTaskService.loadAll();
    if (!mounted) return;
    setState(() {
      _tasks = tasks;
      _loading = false;
    });
  }

  List<WorkTask> get _filtered {
    var list = List<WorkTask>.from(_tasks);
    if (_filter.isNotEmpty) {
      final q = _filter.toLowerCase();
      list = list.where((t) => t.description.toLowerCase().contains(q)).toList();
    }
    // Newest first
    list.sort((a, b) => b.startTime.compareTo(a.startTime));
    return list;
  }

  void _openCreate() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusLg),
        ),
      ),
      builder: (_) => _TaskForm(
        onSave: (task) async {
          await WorkTaskService.save(task);
          await _load();
        },
      ),
    );
  }

  Future<void> _confirmDelete(WorkTask task) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Task löschen?'),
        content: Text('„${task.description}" wirklich löschen?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await WorkTaskService.delete(task.id);
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final filtered = _filtered;

    return Scaffold(
      appBar: AppBar(title: const Text('Arbeitsprotokoll')),
      body: SafeArea(
        child: Column(
          children: [
            // ── Filter bar ────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Nach Beschreibung filtern…',
                  prefixIcon: const Icon(Icons.search_outlined),
                  suffixIcon: _filter.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => setState(() => _filter = ''),
                        )
                      : null,
                ),
                onChanged: (v) => setState(() => _filter = v),
              ),
            ),

            // ── Result count ──────────────────────────────
            if (!_loading)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${filtered.length} Task${filtered.length != 1 ? 's' : ''}',
                    style: text.bodySmall?.copyWith(color: colors.outline),
                  ),
                ),
              ),

            // ── List ──────────────────────────────────────
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : filtered.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.assignment_outlined,
                                size: 64,
                                color: colors.outlineVariant,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _filter.isEmpty
                                    ? 'Noch keine Tasks protokolliert'
                                    : 'Keine Tasks gefunden',
                                style: text.bodyMedium?.copyWith(
                                  color: colors.outline,
                                ),
                              ),
                              if (_filter.isEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  'Tippe auf „Neuer Task" um zu starten',
                                  style: text.bodySmall?.copyWith(
                                    color: colors.outlineVariant,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 88),
                          itemCount: filtered.length,
                          itemBuilder: (_, i) => _TaskCard(
                            task: filtered[i],
                            onDelete: () => _confirmDelete(filtered[i]),
                          ),
                        ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreate,
        icon: const Icon(Icons.add),
        label: const Text('Neuer Task'),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Task Card
// ─────────────────────────────────────────────
class _TaskCard extends StatelessWidget {
  final WorkTask task;
  final VoidCallback onDelete;

  const _TaskCard({required this.task, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final dur = task.duration;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ───────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  ),
                  child: Icon(
                    Icons.work_outline_rounded,
                    size: 18,
                    color: colors.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    task.description,
                    style: text.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: Icon(Icons.delete_outline, color: colors.error, size: 20),
                  onPressed: onDelete,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ── Times ────────────────────────────
            _TimeRow(
              icon: Icons.play_arrow_rounded,
              label: 'Start',
              value: _fmtDateTime(task.startTime),
              color: colors.primary,
            ),
            const SizedBox(height: 4),
            _TimeRow(
              icon: Icons.stop_rounded,
              label: 'Ende',
              value: task.endTime != null
                  ? _fmtDateTime(task.endTime!)
                  : 'Laufend…',
              color: task.endTime != null ? colors.secondary : colors.error,
            ),

            // ── Duration chip ─────────────────────
            if (dur != null) ...[
              const SizedBox(height: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: colors.secondaryContainer,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.timer_outlined,
                      size: 14,
                      color: colors.onSecondaryContainer,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _fmtDuration(dur),
                      style: text.bodySmall?.copyWith(
                        color: colors.onSecondaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TimeRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _TimeRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(
          '$label: ',
          style: text.bodySmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        Text(value, style: text.bodySmall),
      ],
    );
  }
}

// ─────────────────────────────────────────────
//  Task Creation Form (Modal Bottom Sheet)
// ─────────────────────────────────────────────
class _TaskForm extends StatefulWidget {
  final Future<void> Function(WorkTask) onSave;

  const _TaskForm({required this.onSave});

  @override
  State<_TaskForm> createState() => _TaskFormState();
}

class _TaskFormState extends State<_TaskForm> {
  final _formKey = GlobalKey<FormState>();
  final _startCtrl = TextEditingController();
  final _endCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _startCtrl.dispose();
    _endCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  void _setNow(TextEditingController ctrl) {
    setState(() => ctrl.text = _fmtDateTime(DateTime.now()));
  }

  Future<void> _pickDateTime(TextEditingController ctrl) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now),
    );
    if (time == null || !mounted) return;
    setState(() {
      ctrl.text = _fmtDateTime(
        DateTime(date.year, date.month, date.day, time.hour, time.minute),
      );
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final start = _parseDateTime(_startCtrl.text);
    if (start == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ungültiges Format für Startzeit (TT.MM.JJJJ HH:MM)'),
        ),
      );
      return;
    }

    DateTime? end;
    if (_endCtrl.text.trim().isNotEmpty) {
      end = _parseDateTime(_endCtrl.text);
      if (end == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ungültiges Format für Endzeit (TT.MM.JJJJ HH:MM)'),
          ),
        );
        return;
      }
    }

    setState(() => _saving = true);

    final task = WorkTask(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      startTime: start,
      endTime: end,
      description: _descCtrl.text.trim(),
    );

    await widget.onSave(task);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Handle ─────────────────────────────
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              Text('Neuer Task', style: text.titleLarge),
              const SizedBox(height: 20),

              // ── Startzeit ──────────────────────────
              Text(
                'Startzeit *',
                style: text.bodySmall?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _startCtrl,
                      readOnly: true,
                      onTap: () => _pickDateTime(_startCtrl),
                      decoration: const InputDecoration(
                        hintText: 'Datum & Uhrzeit wählen',
                        prefixIcon: Icon(Icons.play_arrow_rounded),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty)
                              ? 'Startzeit eingeben'
                              : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _NowButton(onTap: () => _setNow(_startCtrl)),
                ],
              ),
              const SizedBox(height: 16),

              // ── Endzeit ────────────────────────────
              Text(
                'Endzeit (optional)',
                style: text.bodySmall?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _endCtrl,
                      readOnly: true,
                      onTap: () => _pickDateTime(_endCtrl),
                      decoration: const InputDecoration(
                        hintText: 'Datum & Uhrzeit wählen',
                        prefixIcon: Icon(Icons.stop_rounded),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _NowButton(onTap: () => _setNow(_endCtrl)),
                ],
              ),
              const SizedBox(height: 16),

              // ── Beschreibung ───────────────────────
              Text(
                'Beschreibung *',
                style: text.bodySmall?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _descCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Was hast du gemacht?',
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty)
                        ? 'Beschreibung eingeben'
                        : null,
              ),
              const SizedBox(height: 24),

              // ── Speichern ──────────────────────────
              ElevatedButton(
                onPressed: _saving ? null : _submit,
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Task speichern'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  „Jetzt"-Button
// ─────────────────────────────────────────────
class _NowButton extends StatelessWidget {
  final VoidCallback onTap;

  const _NowButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      height: 52,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: colors.primary),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        child: Text(
          'Jetzt',
          style: TextStyle(
            color: colors.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
