import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:productivity/dataclasses/task.dart';
import 'package:productivity/dataclasses/subtask.dart';
import 'package:productivity/dataclasses/User.dart';
import 'package:productivity/dataservice/login_service.dart';
import 'package:productivity/dataservice/task_service.dart';
import 'package:productivity/dataservice/subtask_service.dart';
import 'package:productivity/dataservice/user_service.dart';
import 'package:productivity/main.dart';

class TasksPage extends BasePage {
  const TasksPage({super.key}) : super(title: 'Tasks');

  @override
  Widget buildBody(BuildContext context) => const _TasksPageContent();
}

class _TasksPageContent extends StatefulWidget {
  const _TasksPageContent();

  @override
  State<_TasksPageContent> createState() => _TasksPageState();
}

class _TasksPageState extends State<_TasksPageContent> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime? _dueDate;
  String _priority = 'medium';

  List<Task> _tasks = [];
  List<User> _users = [];
  User? _currentUser;
  bool _isLoading = true;
  String? _error;

  // Map to store subtasks by taskId
  Map<String, List<SubTask>> _subtasksByTaskId = {};

  static const List<String> kanbanStates = ['todo', 'in_progress', 'done'];
  static const Map<String, String> stateLabels = {
    'todo': 'Zu tun',
    'in_progress': 'In Bearbeitung',
    'done': 'Fertig',
  };

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      final user = await LoginService.currentUser;
      final users = await UserService.getAllUsers();
      setState(() {
        _currentUser = user;
        _users = users;
      });
      _loadTasks();
    } catch (e) {
      _loadTasks();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadTasks() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final tasks = await TaskService.loadAll();

      // Load subtasks for all tasks in parallel
      final subtaskMap = <String, List<SubTask>>{};
      await Future.wait(
        tasks.map((task) async {
          try {
            final subtasks = await SubTaskService.loadByTaskId(task.id);
            subtaskMap[task.id] = subtasks;
          } catch (e) {
            subtaskMap[task.id] = [];
          }
        }),
      );

      setState(() {
        _tasks = tasks;
        _subtasksByTaskId = subtaskMap;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Fehler beim Laden: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _createTask() async {
    if (_titleController.text.isEmpty) {
      _showSnack('Bitte geben Sie einen Titel ein');
      return;
    }

    if (_currentUser == null) {
      _showSnack('User nicht geladen');
      return;
    }

    try {
      final newTask = Task(
        id: '',
        title: _titleController.text,
        description: _descriptionController.text.isEmpty
            ? null
            : _descriptionController.text,
        dueDate: _dueDate,
        priority: _priority,
        userId: _currentUser!.id,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final result = await TaskService.create(newTask);
      setState(() => _tasks.add(result));
      _resetForm();
      _showSnack('Task erstellt');
    } catch (e) {
      _showSnack('Fehler beim Erstellen: $e');
    }
  }

  Future<void> _updateTaskState(Task task, String newState) async {
    try {
      final updated = task.copyWith(kanbanState: newState);
      await TaskService.update(updated);
      setState(() {
        final idx = _tasks.indexWhere((t) => t.id == task.id);
        if (idx >= 0) _tasks[idx] = updated;
      });
    } catch (e) {
      _showSnack('Fehler beim Verschieben: $e');
    }
  }

  Future<void> _deleteTask(Task task) async {
    try {
      await TaskService.delete(task.id);
      setState(() => _tasks.removeWhere((t) => t.id == task.id));
      _showSnack('Task gelöscht');
    } catch (e) {
      _showSnack('Fehler beim Löschen: $e');
    }
  }

  Future<void> _changeTaskUser(Task task, User newUser) async {
    try {
      final updated = task.copyWith(userId: newUser.id);
      await TaskService.update(updated);
      setState(() {
        final idx = _tasks.indexWhere((t) => t.id == task.id);
        if (idx >= 0) _tasks[idx] = updated;
      });
      _showSnack('User geändert zu ${newUser.firstname}');
    } catch (e) {
      _showSnack('Fehler beim Ändern des Users: $e');
    }
  }

  String _getUserName(String userId) {
    try {
      final user = _users.firstWhere((u) => u.id == userId);
      return '${user.firstname} ${user.lastname}';
    } catch (e) {
      return 'Unbekannt';
    }
  }

  void _showTaskEditDialog(Task task) {
    final subTitleCtrl = TextEditingController();
    String subPriority = 'medium';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusLg),
        ),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final subtasks = _subtasksByTaskId[task.id] ?? [];

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 20,
              right: 20,
              top: 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SubTasks für: ${task.title}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 20),
                  // List of existing subtasks
                  if (subtasks.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Center(
                        child: Text(
                          'Keine SubTasks vorhanden',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ),
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SubTasks:',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 10),
                        ...subtasks.map(
                          (subTask) => _buildSubTaskItem(
                            subTask,
                            task.id,
                            () => setDialogState(() {}),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  // Add new subtask section
                  Text(
                    'Neue SubTask hinzufügen',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: subTitleCtrl,
                    decoration: InputDecoration(
                      labelText: 'SubTask Titel',
                      hintText: 'Titel eingeben...',
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: subPriority,
                    items: ['low', 'medium', 'high']
                        .map(
                          (p) => DropdownMenuItem(
                            value: p,
                            child: Text(
                              p == 'low'
                                  ? 'Niedrig'
                                  : p == 'medium'
                                  ? 'Mittel'
                                  : 'Hoch',
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) =>
                        setDialogState(() => subPriority = v ?? 'medium'),
                    decoration: InputDecoration(
                      labelText: 'Priorität',
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Schließen'),
                      ),
                      const Spacer(),
                      ElevatedButton.icon(
                        onPressed: () {
                          if (subTitleCtrl.text.isNotEmpty) {
                            _createSubTask(
                              task.id,
                              subTitleCtrl.text,
                              priority: subPriority,
                            ).then((_) {
                              setDialogState(() {
                                subTitleCtrl.clear();
                                subPriority = 'medium';
                              });
                            });
                          }
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Hinzufügen'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSubTaskItem(
    SubTask subTask,
    String taskId,
    VoidCallback onStateChanged,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Checkbox(
            value: subTask.completed,
            onChanged: (_) async {
              await _toggleSubTaskCompleted(subTask);
              onStateChanged();
            },
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subTask.title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    decoration: subTask.completed
                        ? TextDecoration.lineThrough
                        : null,
                    color: subTask.completed
                        ? Theme.of(context).colorScheme.onSurfaceVariant
                        : Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                if (subTask.dueDate != null)
                  Text(
                    DateFormat('dd.MM.yyyy').format(subTask.dueDate!),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete, size: 18),
            onPressed: () async {
              await _deleteSubTask(taskId, subTask.id);
              onStateChanged();
            },
            color: Theme.of(context).colorScheme.error,
          ),
        ],
      ),
    );
  }

  void _resetForm() {
    setState(() {
      _titleController.clear();
      _descriptionController.clear();
      _dueDate = null;
      _priority = 'medium';
    });
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _createSubTask(
    String taskId,
    String title, {
    String? description,
    DateTime? dueDate,
    String priority = 'medium',
  }) async {
    try {
      final newSubTask = SubTask(
        id: '',
        taskId: taskId,
        title: title,
        description: description,
        dueDate: dueDate,
        priority: priority,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final result = await SubTaskService.create(newSubTask);
      setState(() {
        if (_subtasksByTaskId[taskId] == null) {
          _subtasksByTaskId[taskId] = [];
        }
        _subtasksByTaskId[taskId]!.add(result);
      });
      _showSnack('SubTask erstellt');
    } catch (e) {
      _showSnack('Fehler beim Erstellen: $e');
    }
  }

  Future<void> _updateSubTask(SubTask subTask) async {
    try {
      await SubTaskService.update(subTask);
      setState(() {
        final taskId = subTask.taskId;
        if (_subtasksByTaskId[taskId] != null) {
          final idx = _subtasksByTaskId[taskId]!.indexWhere(
            (s) => s.id == subTask.id,
          );
          if (idx >= 0) {
            _subtasksByTaskId[taskId]![idx] = subTask;
          }
        }
      });
    } catch (e) {
      _showSnack('Fehler beim Aktualisieren: $e');
    }
  }

  Future<void> _deleteSubTask(String taskId, String subTaskId) async {
    try {
      await SubTaskService.delete(subTaskId);
      setState(() {
        if (_subtasksByTaskId[taskId] != null) {
          _subtasksByTaskId[taskId]!.removeWhere((s) => s.id == subTaskId);
        }
      });
      _showSnack('SubTask gelöscht');
    } catch (e) {
      _showSnack('Fehler beim Löschen: $e');
    }
  }

  Future<void> _toggleSubTaskCompleted(SubTask subTask) async {
    try {
      final result = await SubTaskService.toggleCompleted(subTask.id);
      setState(() {
        final taskId = subTask.taskId;
        if (_subtasksByTaskId[taskId] != null) {
          final idx = _subtasksByTaskId[taskId]!.indexWhere(
            (s) => s.id == subTask.id,
          );
          if (idx >= 0) {
            _subtasksByTaskId[taskId]![idx] = result;
          }
        }
      });
    } catch (e) {
      _showSnack('Fehler beim Umschalten: $e');
    }
  }

  List<Task> _getTasksByState(String state) {
    return _tasks.where((task) => task.kanbanState == state).toList();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SingleChildScrollView(
          child: Card(
            color: colors.surfaceContainerHighest,
            margin: const EdgeInsets.all(16),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: colors.outline.withValues(alpha: 0.2)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Neue Task', style: text.titleLarge),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _titleController,
                    style: TextStyle(color: colors.onSurface),
                    decoration: InputDecoration(
                      labelText: 'Titel *',
                      hintText: 'Task Titel eingeben...',
                      filled: true,
                      fillColor: colors.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: colors.outline.withValues(alpha: 0.3),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: colors.outline.withValues(alpha: 0.2),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _descriptionController,
                    style: TextStyle(color: colors.onSurface),
                    decoration: InputDecoration(
                      labelText: 'Beschreibung',
                      hintText: 'Optionale Beschreibung...',
                      filled: true,
                      fillColor: colors.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: colors.outline.withValues(alpha: 0.3),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: colors.outline.withValues(alpha: 0.2),
                        ),
                      ),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _dueDate ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2100),
                            );
                            if (picked != null)
                              setState(() => _dueDate = picked);
                          },
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'Fälligkeitsdatum',
                              filled: true,
                              fillColor: colors.surface,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: colors.outline.withValues(alpha: 0.3),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: colors.outline.withValues(alpha: 0.2),
                                ),
                              ),
                            ),
                            child: Text(
                              _dueDate != null
                                  ? DateFormat('dd.MM.yyyy').format(_dueDate!)
                                  : 'Optional',
                              style: TextStyle(
                                color: _dueDate != null
                                    ? colors.onSurface
                                    : colors.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _priority,
                          items: ['low', 'medium', 'high']
                              .map(
                                (p) => DropdownMenuItem(
                                  value: p,
                                  child: Text(
                                    p == 'low'
                                        ? 'Niedrig'
                                        : p == 'medium'
                                        ? 'Mittel'
                                        : 'Hoch',
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _priority = v ?? 'medium'),
                          decoration: InputDecoration(
                            labelText: 'Priorität',
                            filled: true,
                            fillColor: colors.surface,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: colors.outline.withValues(alpha: 0.3),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: colors.outline.withValues(alpha: 0.2),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _createTask,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Task erstellen'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_isLoading)
          Expanded(
            child: Center(
              child: CircularProgressIndicator(color: colors.primary),
            ),
          )
        else if (_error != null)
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.cloud_off_rounded,
                    size: 48,
                    color: colors.onSurfaceVariant,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: text.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _loadTasks,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Erneut versuchen'),
                  ),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final state in kanbanStates)
                    _buildKanbanColumn(colors, text, state),
                  const SizedBox(width: 16),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildKanbanColumn(ColorScheme colors, TextTheme text, String state) {
    final tasks = _getTasksByState(state);
    return DragTarget<Task>(
      onAcceptWithDetails: (draggedTask) {
        _updateTaskState(draggedTask as Task, state);
      },
      builder: (context, candidateData, rejectedData) {
        return Container(
          width: 340,
          margin: const EdgeInsets.only(left: 16),
          decoration: BoxDecoration(
            color: colors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
            border: candidateData.isNotEmpty
                ? Border.all(color: colors.primary, width: 2)
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildListHeader(colors, text, state, tasks.length),
              const SizedBox(height: 12),
              Expanded(
                child: tasks.isEmpty
                    ? Center(
                        child: Text(
                          'Keine Tasks',
                          style: text.bodyMedium?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        itemCount: tasks.length,
                        itemBuilder: (context, index) {
                          return _buildDraggableTaskCard(
                            colors,
                            text,
                            tasks[index],
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildListHeader(
    ColorScheme colors,
    TextTheme text,
    String state,
    int count,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _getStateColor(colors, state).withValues(alpha: 0.1),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        border: Border(
          bottom: BorderSide(
            color: _getStateColor(colors, state).withValues(alpha: 0.3),
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            stateLabels[state]!,
            style: text.titleMedium?.copyWith(
              color: colors.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _getStateColor(colors, state),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              count.toString(),
              style: text.bodySmall?.copyWith(
                color: colors.onPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDraggableTaskCard(
    ColorScheme colors,
    TextTheme text,
    Task task,
  ) {
    return GestureDetector(
      onTap: () => _showTaskEditDialog(task),
      child: _buildTaskCard(colors, text, task),
    );
  }

  Widget _buildTaskCard(ColorScheme colors, TextTheme text, Task task) {
    // Drag handle wrapped in Draggable
    final dragHandle = Draggable<Task>(
      data: task,
      feedback: Material(
        child: Container(
          width: 304,
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: colors.shadow.withValues(alpha: 0.2),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: _buildTaskCardContent(colors, text, task),
        ),
      ),
      childWhenDragging: const SizedBox.shrink(),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: colors.surfaceContainerHighest,
        ),
        child: Icon(
          Icons.drag_handle,
          size: 20,
          color: colors.onSurfaceVariant,
        ),
      ),
    );

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outline.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                  color: _getPriorityColor(colors, task.priority),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  task.title,
                  style: text.bodyLarge?.copyWith(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              dragHandle,
            ],
          ),
          const SizedBox(height: 12),
          // Rest der Karten-Details (Description, Dates, User, Actions)
          _buildTaskCardDetails(colors, text, task),
        ],
      ),
    );
  }

  Widget _buildTaskCardDetails(ColorScheme colors, TextTheme text, Task task) {
    final subtasks = _subtasksByTaskId[task.id] ?? [];
    final completedSubtasks = subtasks.where((s) => s.completed).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (task.description != null && task.description!.isNotEmpty) ...[
          Text(
            task.description!,
            style: text.bodySmall?.copyWith(color: colors.onSurfaceVariant),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 10),
        ],
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            if (task.dueDate != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: colors.surfaceContainer,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 12,
                      color: colors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      DateFormat('dd.MM').format(task.dueDate!),
                      style: text.labelSmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getPriorityColor(
                  colors,
                  task.priority,
                ).withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: _getPriorityColor(
                    colors,
                    task.priority,
                  ).withValues(alpha: 0.5),
                ),
              ),
              child: Text(
                _getPriorityLabel(task.priority),
                style: text.labelSmall?.copyWith(
                  color: _getPriorityColor(colors, task.priority),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (subtasks.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: colors.tertiaryContainer.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: colors.tertiary.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.checklist, size: 12, color: colors.tertiary),
                    const SizedBox(width: 4),
                    Text(
                      '$completedSubtasks/${subtasks.length}',
                      style: text.labelSmall?.copyWith(
                        color: colors.tertiary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: colors.primaryContainer.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              Icon(Icons.person_rounded, size: 14, color: colors.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _getUserName(task.userId),
                  style: text.labelSmall?.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              PopupMenuButton<User>(
                onSelected: (user) => _changeTaskUser(task, user),
                itemBuilder: (context) => _users
                    .map(
                      (user) => PopupMenuItem(
                        value: user,
                        child: Text('${user.firstname} ${user.lastname}'),
                      ),
                    )
                    .toList(),
                child: Icon(Icons.edit, size: 12, color: colors.primary),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            InkWell(
              onTap: () => _deleteTask(task),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: colors.errorContainer.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(Icons.close, size: 16, color: colors.error),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTaskCardContent(ColorScheme colors, TextTheme text, Task task) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 20,
              decoration: BoxDecoration(
                color: _getPriorityColor(colors, task.priority),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                task.title,
                style: text.bodyLarge?.copyWith(
                  color: colors.onSurface,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        if (task.description != null && task.description!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            task.description!,
            style: text.bodySmall?.copyWith(color: colors.onSurfaceVariant),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            if (task.dueDate != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: colors.surfaceContainer,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 12,
                      color: colors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      DateFormat('dd.MM').format(task.dueDate!),
                      style: text.labelSmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getPriorityColor(
                  colors,
                  task.priority,
                ).withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: _getPriorityColor(
                    colors,
                    task.priority,
                  ).withValues(alpha: 0.5),
                ),
              ),
              child: Text(
                _getPriorityLabel(task.priority),
                style: text.labelSmall?.copyWith(
                  color: _getPriorityColor(colors, task.priority),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: colors.primaryContainer.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              Icon(Icons.person_rounded, size: 14, color: colors.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _getUserName(task.userId),
                  style: text.labelSmall?.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              PopupMenuButton<User>(
                onSelected: (user) => _changeTaskUser(task, user),
                itemBuilder: (context) => _users
                    .map(
                      (user) => PopupMenuItem(
                        value: user,
                        child: Text('${user.firstname} ${user.lastname}'),
                      ),
                    )
                    .toList(),
                child: Icon(Icons.edit, size: 12, color: colors.primary),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            InkWell(
              onTap: () => _deleteTask(task),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: colors.errorContainer.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(Icons.close, size: 16, color: colors.error),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Color _getStateColor(ColorScheme colors, String state) {
    switch (state) {
      case 'todo':
        return colors.secondary;
      case 'in_progress':
        return colors.tertiary;
      case 'done':
        return colors.primary;
      default:
        return colors.secondary;
    }
  }

  Color _getPriorityColor(ColorScheme colors, String priority) {
    switch (priority) {
      case 'high':
        return colors.error;
      case 'medium':
        return colors.tertiary;
      case 'low':
        return colors.secondary;
      default:
        return colors.secondary;
    }
  }

  String _getPriorityLabel(String priority) {
    switch (priority) {
      case 'high':
        return 'Hoch';
      case 'medium':
        return 'Mittel';
      case 'low':
        return 'Niedrig';
      default:
        return priority;
    }
  }
}
