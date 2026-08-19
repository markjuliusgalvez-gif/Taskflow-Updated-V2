import 'dart:async';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'models/assignment.dart';
import 'models/subject.dart';
import 'services/storage_service.dart';
import 'services/notification_service.dart';
import 'screens/notes_screen.dart';

void main() {
  runApp(const AssignmentTrackerApp());
}

class AssignmentTrackerApp extends StatefulWidget {
  const AssignmentTrackerApp({super.key});

  @override
  State<AssignmentTrackerApp> createState() => _AssignmentTrackerAppState();
}

class _AssignmentTrackerAppState extends State<AssignmentTrackerApp> {
  ThemeMode _themeMode = ThemeMode.system;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    // Simulate essential startup work.
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    setState(() => _initialized = true);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TaskFlow',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6366F1),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(centerTitle: true),
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6366F1),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
      themeMode: _themeMode,
      home: _initialized
          ? HomeScreen(
              onThemeToggle: () {
                setState(() {
                  _themeMode = _themeMode == ThemeMode.system
                      ? ThemeMode.light
                      : _themeMode == ThemeMode.light
                          ? ThemeMode.dark
                          : ThemeMode.system;
                });
              },
              themeMode: _themeMode,
            )
          : const SplashScreen(),
    );
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.15),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: Image.asset(
                  'lib/assets/ic_launcher.png',
                  width: 96,
                  height: 96,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'TaskFlow',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  final VoidCallback onThemeToggle;
  final ThemeMode themeMode;

  const HomeScreen({
    super.key,
    required this.onThemeToggle,
    required this.themeMode,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final StorageService _storage = StorageService();
  final NotificationService _notifications = NotificationService();
  final Uuid _uuid = const Uuid();
  List<Subject> _subjects = [];
  bool _loading = true;
  String _searchQuery = '';
  AssignmentStatus? _assignmentStatusFilter;
  int _currentIndex = 0;
  final GlobalKey<NotesScreenState> _notesScreenKey = GlobalKey<NotesScreenState>();
  Timer? _deadlineTimer;
  final Set<String> _notifiedAssignmentIds = {};

  @override
  void initState() {
    super.initState();
    _notifications.init();
    _loadData();
    _startDeadlineTimer();
  }

  void _startDeadlineTimer() {
    _deadlineTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted || _loading) return;
      _applyDeadlineChecks();
    });
  }

  Future<void> _applyDeadlineChecks() async {
    final now = DateTime.now();
    final unfinished = <String>[];
    final newIds = <String>[];

    for (final subject in _subjects) {
      for (final assignment in subject.assignments) {
        if (assignment.status == AssignmentStatus.pending &&
            assignment.deadline != null &&
            !_notifiedAssignmentIds.contains(assignment.id) &&
            (now.isAtSameMomentAs(assignment.deadline!) ||
                now.isAfter(assignment.deadline!))) {
          assignment.status = AssignmentStatus.unfinished;
          unfinished.add(assignment.title);
          newIds.add(assignment.id);
        }
      }
    }

    if (unfinished.isNotEmpty) {
      for (final id in newIds) {
        _notifiedAssignmentIds.add(id);
      }
      await _save();
      if (mounted) {
        setState(() {});
        await showDialog(
          context: context,
          barrierColor: Colors.black87,
          builder: (ctx) => AlertDialog(
            title: const Text('Assignment Update'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('The following assignment(s) have been marked as unfinished:'),
                  const SizedBox(height: 12),
                  ...unfinished.map(
                    (title) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text('• $title'),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> _loadData() async {
    final data = await _storage.loadSubjects();
    setState(() {
      _subjects = data;
      _loading = false;
    });
    await _applyDeadlineChecks();
  }

  Future<void> _save() async {
    await _storage.saveSubjects(_subjects);
  }

  // ---------- Subject actions ----------
  void _addSubject() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => AlertDialog(
        title: const Text('New Subject'),
        content: SingleChildScrollView(
          child: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'e.g. Mathematics, History...',
              border: OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.words,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              setState(() {
                _subjects.add(Subject(id: _uuid.v4(), name: name));
              });
              _save();
              Navigator.pop(ctx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _editSubject(Subject subject) {
    final controller = TextEditingController(text: subject.name);
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Subject'),
        content: SingleChildScrollView(
          child: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(border: OutlineInputBorder()),
            textCapitalization: TextCapitalization.words,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              setState(() => subject.name = name);
              _save();
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _deleteSubject(Subject subject) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Subject?'),
        content: Text(
          'This will permanently delete "${subject.name}" and all its assignments.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              setState(() => _subjects.removeWhere((s) => s.id == subject.id));
              _save();
              Navigator.pop(ctx);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _addNote(Subject subject) {
    // Notes are now standalone; this keeps the subject card action available.
    _notesScreenKey.currentState?.requestAddNote();
  }

  // ---------- Assignment actions ----------
  void _addAssignment(Subject subject) {
    final titleCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    DateTime? selectedDeadline;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      barrierColor: Colors.black87,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          left: 16,
          right: 16,
          top: 16,
        ),
        child: StatefulBuilder(
          builder: (context, setModalState) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'New Assignment • ${subject.name}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: titleCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Title *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Note (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () async {
                  final now = DateTime.now();
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: now.add(const Duration(days: 1)),
                    firstDate: now,
                    lastDate: DateTime(now.year + 5),
                   );
                   if (picked == null) return;
                   if (!context.mounted) return;
                   final time = await showTimePicker(
                     context: context,
                     initialTime: TimeOfDay.fromDateTime(
                       now.add(const Duration(hours: 1)),
                     ),
                   );
                   if (time == null) return;
                   final combined = DateTime(
                     picked.year,
                     picked.month,
                     picked.day,
                     time.hour,
                     time.minute,
                   );
                   setModalState(() => selectedDeadline = combined);
                 },
                 child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Deadline (optional)',
                    border: OutlineInputBorder(),
                  ),
                  child: Text(
                    selectedDeadline == null
                        ? 'No deadline set'
                        : '${selectedDeadline!.day}/${selectedDeadline!.month}/${selectedDeadline!.year} ${selectedDeadline!.hour}:${selectedDeadline!.minute.toString().padLeft(2, '0')}',
                  ),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () {
                  final title = titleCtrl.text.trim();
                  if (title.isEmpty) return;
                  final assignment = Assignment(
                    id: _uuid.v4(),
                    title: title,
                    note: noteCtrl.text.trim().isEmpty
                        ? null
                        : noteCtrl.text.trim(),
                    deadline: selectedDeadline,
                  );
                  setState(() {
                    subject.assignments.insert(0, assignment);
                  });
                  _save();
                  if (assignment.deadline != null) {
                    _notifications.scheduleDeadlineReminder(
                      assignmentId: assignment.id,
                      title: assignment.title,
                      deadline: assignment.deadline!,
                    );
                  }
                  Navigator.pop(ctx);
                },
                child: const Text('Add Assignment'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _editAssignment(Subject subject, Assignment assignment) {
    final titleCtrl = TextEditingController(text: assignment.title);
    final noteCtrl = TextEditingController(text: assignment.note ?? '');
    DateTime? selectedDeadline = assignment.deadline;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      barrierColor: Colors.black87,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          left: 16,
          right: 16,
          top: 16,
        ),
        child: StatefulBuilder(
          builder: (context, setModalState) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Edit Assignment',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Title *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Note (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () async {
                  final now = DateTime.now();
                  DateTime initial = selectedDeadline ?? now.add(const Duration(days: 1));
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: initial,
                    firstDate: now,
                    lastDate: DateTime(now.year + 5),
                  );
                   if (picked == null) return;
                   if (!context.mounted) return;
                   final time = await showTimePicker(
                     context: context,
                     initialTime: TimeOfDay.fromDateTime(initial),
                   );
                   if (time == null) return;
                   final combined = DateTime(
                     picked.year,
                     picked.month,
                     picked.day,
                     time.hour,
                     time.minute,
                   );
                   setModalState(() => selectedDeadline = combined);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Deadline (optional)',
                    border: OutlineInputBorder(),
                  ),
                  child: Text(
                    selectedDeadline == null
                        ? 'No deadline set'
                        : '${selectedDeadline!.day}/${selectedDeadline!.month}/${selectedDeadline!.year} ${selectedDeadline!.hour}:${selectedDeadline!.minute.toString().padLeft(2, '0')}',
                  ),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () {
                  final title = titleCtrl.text.trim();
                  if (title.isEmpty) return;
                  final previousDeadline = assignment.deadline;
                  setState(() {
                    assignment.title = title;
                    assignment.note = noteCtrl.text.trim().isEmpty
                        ? null
                        : noteCtrl.text.trim();
                    assignment.deadline = selectedDeadline;
                  });
                  _save();
                  if (assignment.deadline != null &&
                      assignment.deadline != previousDeadline) {
                    _notifications.cancelReminder(assignment.id);
                    _notifications.scheduleDeadlineReminder(
                      assignmentId: assignment.id,
                      title: assignment.title,
                      deadline: assignment.deadline!,
                    );
                  } else if (assignment.deadline == null) {
                    _notifications.cancelReminder(assignment.id);
                  }
                  Navigator.pop(ctx);
                },
                child: const Text('Save Changes'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _pickStatus(Assignment assignment) {
    showModalBottomSheet(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final status in const [AssignmentStatus.pending, AssignmentStatus.finished])
              ListTile(
                leading: Icon(_statusIcon(status), color: _statusColor(status)),
                title: Text(_statusLabel(status)),
                onTap: () {
                  setState(() => assignment.status = status);
                  _save();
                  Navigator.pop(ctx);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _deleteAssignment(Subject subject, Assignment assignment) {
    _notifications.cancelReminder(assignment.id);
    setState(() {
      subject.assignments.removeWhere((a) => a.id == assignment.id);
    });
    _save();
  }

  // ---------- Helpers ----------
  Color _statusColor(AssignmentStatus status) {
    switch (status) {
      case AssignmentStatus.unfinished:
        return Colors.red.shade400;
      case AssignmentStatus.pending:
        return Colors.orange.shade400;
      case AssignmentStatus.finished:
        return Colors.green.shade500;
    }
  }

  IconData _statusIcon(AssignmentStatus status) {
    switch (status) {
      case AssignmentStatus.unfinished:
        return Icons.radio_button_unchecked;
      case AssignmentStatus.pending:
        return Icons.hourglass_bottom;
      case AssignmentStatus.finished:
        return Icons.check_circle;
    }
  }

  String _statusLabel(AssignmentStatus status) {
    switch (status) {
      case AssignmentStatus.unfinished:
        return 'Unfinished';
      case AssignmentStatus.pending:
        return 'Pending';
      case AssignmentStatus.finished:
        return 'Finished';
    }
  }

  String _formatDeadline(DateTime deadline) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(deadline.year, deadline.month, deadline.day);
    final daysLeft = target.difference(today).inDays;

    final time = '${deadline.day}/${deadline.month}/${deadline.year} ${deadline.hour.toString().padLeft(2, '0')}:${deadline.minute.toString().padLeft(2, '0')}';
    if (daysLeft < 0) return 'Overdue • $time';
    if (daysLeft == 0) return 'Today • $time';
    if (daysLeft == 1) return 'Tomorrow • $time';
    return '$daysLeft days left • $time';
  }

  IconData _themeIcon(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return Icons.light_mode;
      case ThemeMode.dark:
        return Icons.dark_mode;
      case ThemeMode.system:
        return Icons.brightness_auto;
    }
  }

  List<Subject> get _filteredSubjects {
    Iterable<Subject> subjects = _subjects;
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      subjects = subjects.where((s) =>
          s.name.toLowerCase().contains(q) ||
          s.assignments.any((a) => a.title.toLowerCase().contains(q)));
    }
    if (_assignmentStatusFilter != null) {
      subjects = subjects.where((s) =>
          s.assignments.any((a) => a.status == _assignmentStatusFilter));
    }
    return subjects.toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredSubjects;
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          _currentIndex == 0 ? 'TaskFlow' : 'Subject Notes',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(_themeIcon(widget.themeMode)),
            onPressed: widget.onThemeToggle,
            tooltip: 'Toggle theme',
          ),
        ],
      ),
      body: Stack(
        children: [
          IndexedStack(
            index: _currentIndex,
            children: [
              _subjects.isEmpty
                  ? _buildEmptyState()
                  : Column(
                      children: [
                         Padding(
                           padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                           child: TextField(
                             decoration: InputDecoration(
                               hintText: 'Search subjects or assignments...',
                               prefixIcon: const Icon(Icons.search),
                               border: OutlineInputBorder(
                                 borderRadius: BorderRadius.circular(16),
                               ),
                               contentPadding: const EdgeInsets.symmetric(
                                 horizontal: 16,
                                 vertical: 12,
                               ),
                             ),
                             onChanged: (v) => setState(() => _searchQuery = v),
                           ),
                         ),
                         Padding(
                           padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                           child: SingleChildScrollView(
                             scrollDirection: Axis.horizontal,
                             child: Row(
                               children: [
                                 _FilterChip(
                                   label: 'All',
                                   selected: _assignmentStatusFilter == null,
                                   onTap: () => setState(() => _assignmentStatusFilter = null),
                                 ),
                                 const SizedBox(width: 8),
                                 _FilterChip(
                                   label: 'Unfinished',
                                   selected: _assignmentStatusFilter == AssignmentStatus.unfinished,
                                   color: Colors.red,
                                   onTap: () => setState(() => _assignmentStatusFilter = AssignmentStatus.unfinished),
                                 ),
                                 const SizedBox(width: 8),
                                 _FilterChip(
                                   label: 'Pending',
                                   selected: _assignmentStatusFilter == AssignmentStatus.pending,
                                   color: Colors.orange,
                                   onTap: () => setState(() => _assignmentStatusFilter = AssignmentStatus.pending),
                                 ),
                                 const SizedBox(width: 8),
                                 _FilterChip(
                                   label: 'Finished',
                                   selected: _assignmentStatusFilter == AssignmentStatus.finished,
                                   color: Colors.green,
                                   onTap: () => setState(() => _assignmentStatusFilter = AssignmentStatus.finished),
                                 ),
                               ],
                             ),
                           ),
                         ),
                         Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.only(bottom: 80),
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              return _buildSubjectCard(filtered[index]);
                            },
                          ),
                        ),
                      ],
                    ),
              NotesScreen(key: _notesScreenKey),
            ],
          ),
          if (_loading)
            AnimatedOpacity(
              opacity: _loading ? 1 : 0,
              duration: const Duration(milliseconds: 300),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 84,
            child: Center(
              child: Container(
                height: 56,
                width: MediaQuery.of(context).size.width * 0.82,
                decoration: ShapeDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  shape: const StadiumBorder(),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Expanded(
                      child: _NavBarItem(
                        icon: Icons.folder_outlined,
                        activeIcon: Icons.folder,
                        label: 'Subjects',
                        selected: _currentIndex == 0,
                        onTap: () => setState(() => _currentIndex = 0),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: _CenterAddButton(
                        onAddSubject: _addSubject,
                        onAddNote: () => _notesScreenKey.currentState?.requestAddNote(),
                        currentIndex: _currentIndex,
                      ),
                    ),
                    Expanded(
                      child: _NavBarItem(
                        icon: Icons.note_outlined,
                        activeIcon: Icons.note,
                        label: 'Notes',
                        selected: _currentIndex == 1,
                        onTap: () => setState(() => _currentIndex = 1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 800),
              curve: Curves.elasticOut,
              tween: Tween(begin: 0.5, end: 1),
              builder: (context, value, child) {
                return Transform.scale(
                  scale: value,
                  child: Icon(
                    Icons.assignment_outlined,
                    size: 80,
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            Text(
              'No subjects yet',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the button below to add your first subject',
              style: TextStyle(color: Theme.of(context).colorScheme.outline),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubjectCard(Subject subject) {
    return _SubjectCard(
      subject: subject,
      onEditSubject: _editSubject,
      onDeleteSubject: _deleteSubject,
      onAddAssignment: _addAssignment,
      onEditAssignment: _editAssignment,
      onDeleteAssignment: _deleteAssignment,
      onPickStatus: _pickStatus,
      onAddNote: _addNote,
      statusIcon: _statusIcon,
      statusColor: _statusColor,
      statusLabel: _statusLabel,
      formatDeadline: _formatDeadline,
      statusFilter: _assignmentStatusFilter,
    );
  }

  @override
  void dispose() {
    _deadlineTimer?.cancel();
    super.dispose();
  }
}

class _SubjectCard extends StatefulWidget {
  final Subject subject;
  final void Function(Subject) onEditSubject;
  final void Function(Subject) onDeleteSubject;
  final void Function(Subject) onAddAssignment;
  final void Function(Subject, Assignment) onEditAssignment;
  final void Function(Subject, Assignment) onDeleteAssignment;
  final void Function(Assignment) onPickStatus;
  final void Function(Subject) onAddNote;
  final IconData Function(AssignmentStatus) statusIcon;
  final Color Function(AssignmentStatus) statusColor;
  final String Function(AssignmentStatus) statusLabel;
  final String Function(DateTime) formatDeadline;
  final AssignmentStatus? statusFilter;

  const _SubjectCard({
    required this.subject,
    required this.onEditSubject,
    required this.onDeleteSubject,
    required this.onAddAssignment,
    required this.onEditAssignment,
    required this.onDeleteAssignment,
    required this.onPickStatus,
    required this.onAddNote,
    required this.statusIcon,
    required this.statusColor,
    required this.statusLabel,
    required this.formatDeadline,
    this.statusFilter,
  });

  @override
  State<_SubjectCard> createState() => _SubjectCardState();
}

class _SubjectCardState extends State<_SubjectCard> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.subject.isExpanded;
  }

  void _toggleExpanded(bool expanded) {
    setState(() {
      _expanded = expanded;
      widget.subject.isExpanded = expanded;
    });
  }

  @override
  Widget build(BuildContext context) {
    final subject = widget.subject;
    final assignments = widget.statusFilter == null
        ? subject.assignments
        : subject.assignments
            .where((a) => a.status == widget.statusFilter)
            .toList();

    return AnimatedOpacity(
      opacity: 1,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
      child: TweenAnimationBuilder<Offset>(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
        tween: Tween(begin: const Offset(0, 0.05), end: Offset.zero),
        builder: (context, value, child) {
          return Transform.translate(
            offset: value,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Card(
                elevation: 0,
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    key: PageStorageKey<String>(subject.id),
                    initiallyExpanded: _expanded,
                    onExpansionChanged: _toggleExpanded,
                    childrenPadding: EdgeInsets.zero,
                    tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        subject.name.isNotEmpty ? subject.name[0].toUpperCase() : '?',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                    ),
                  ),
                  title: Text(
                    subject.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${assignments.length} assignment${assignments.length == 1 ? '' : 's'}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 6),
                      _AssignmentStatusIndicator(assignments: assignments),
                    ],
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') widget.onEditSubject(subject);
                      if (value == 'delete') widget.onDeleteSubject(subject);
                      if (value == 'add') widget.onAddAssignment(subject);
                      if (value == 'note') widget.onAddNote(subject);
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'note', child: Text('Add Note')),
                      const PopupMenuItem(value: 'add', child: Text('Add Assignment')),
                      const PopupMenuItem(value: 'edit', child: Text('Edit Subject')),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete Subject', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                  children: [
                    if (assignments.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text(
                          widget.statusFilter == null
                              ? 'No assignments yet. Tap ⋮ → Add Assignment'
                              : 'No ${widget.statusLabel(widget.statusFilter!).toLowerCase()} assignments',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.outline,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      )
                    else
                      ...assignments.map((assignment) {
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          minLeadingWidth: 0,
                          horizontalTitleGap: 12,
                          leading: Padding(
                            padding: const EdgeInsets.only(left: 16),
                            child: IconButton(
                              icon: Icon(
                                widget.statusIcon(assignment.status),
                                color: widget.statusColor(assignment.status),
                              ),
                              onPressed: () => widget.onPickStatus(assignment),
                              tooltip: 'Change status',
                            ),
                          ),
                          title: Padding(
                            padding: const EdgeInsets.only(right: 16),
                            child: Text(
                              assignment.title,
                              style: TextStyle(
                                decoration: assignment.status == AssignmentStatus.finished
                                    ? TextDecoration.lineThrough
                                    : null,
                                color: assignment.status == AssignmentStatus.finished
                                    ? Theme.of(context).colorScheme.outline
                                    : Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(right: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (assignment.note != null && assignment.note!.isNotEmpty)
                                  Text(assignment.note!),
                                const SizedBox(height: 4),
                                if (assignment.deadline != null)
                                  Text(
                                    widget.formatDeadline(assignment.deadline!),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                Chip(
                                  label: Text(
                                    widget.statusLabel(assignment.status),
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  backgroundColor: widget.statusColor(assignment.status).withValues(alpha: 0.15),
                                  side: BorderSide.none,
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                ),
                              ],
                            ),
                          ),
                          isThreeLine:
                              assignment.note != null && assignment.note!.isNotEmpty,
                          trailing: Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'edit') widget.onEditAssignment(subject, assignment);
                                if (value == 'delete') {
                                  widget.onDeleteAssignment(subject, assignment);
                                }
                              },
                              itemBuilder: (_) => [
                                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Delete', style: TextStyle(color: Colors.red)),
                                ),
                              ],
                            ),
                          ),
                          onTap: () => widget.onPickStatus(assignment),
                        );
                      }),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: OutlinedButton.icon(
                        onPressed: () => widget.onAddAssignment(subject),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add Assignment'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    ),
    );
  }
}

class _AssignmentStatusIndicator extends StatelessWidget {
  final List<Assignment> assignments;

  const _AssignmentStatusIndicator({required this.assignments});

  @override
  Widget build(BuildContext context) {
    final unfinished = assignments.where((a) => a.status == AssignmentStatus.unfinished).length;
    final pending = assignments.where((a) => a.status == AssignmentStatus.pending).length;
    final finished = assignments.where((a) => a.status == AssignmentStatus.finished).length;
    final total = assignments.length;

    if (total == 0) {
      return Text(
        'No assignments yet',
        style: TextStyle(
          fontSize: 12,
          color: Theme.of(context).colorScheme.outline,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    return Row(
      children: [
        _StatusDot(count: unfinished, color: Colors.red, label: 'Unfinished'),
        const SizedBox(width: 12),
        _StatusDot(count: pending, color: Colors.orange, label: 'Pending'),
        const SizedBox(width: 12),
        _StatusDot(count: finished, color: Colors.green, label: 'Finished'),
      ],
    );
  }
}

class _StatusDot extends StatelessWidget {
  final int count;
  final Color color;
  final String label;

  const _StatusDot({
    required this.count,
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '$count',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color? color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? Theme.of(context).colorScheme.primary;
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: effectiveColor.withValues(alpha: 0.2),
      checkmarkColor: effectiveColor,
      labelStyle: TextStyle(
        color: selected ? effectiveColor : Theme.of(context).colorScheme.onSurfaceVariant,
        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }
}

class _NavBarItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavBarItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.onSurfaceVariant;

    return Semantics(
      selected: selected,
      label: label,
      button: true,
      child: InkWell(
        onTap: onTap,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                selected ? activeIcon : icon,
                color: color,
                size: 24,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CenterAddButton extends StatelessWidget {
  final VoidCallback onAddSubject;
  final VoidCallback onAddNote;
  final int currentIndex;

  const _CenterAddButton({
    required this.onAddSubject,
    required this.onAddNote,
    required this.currentIndex,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: currentIndex == 0 ? onAddSubject : onAddNote,
        customBorder: const CircleBorder(),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: colorScheme.primary,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: colorScheme.shadow.withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            Icons.add,
            color: colorScheme.onPrimary,
            size: 22,
          ),
        ),
      ),
    );
  }
}
