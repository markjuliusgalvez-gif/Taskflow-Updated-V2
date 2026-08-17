import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/note.dart';
import '../services/storage_service.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => NotesScreenState();
}

class NotesScreenState extends State<NotesScreen> {
  final StorageService _storage = StorageService();
  final Uuid _uuid = const Uuid();
  List<Note> _notes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    final data = await _storage.loadNotes();
    setState(() {
      _notes = data;
      _loading = false;
    });
  }

  Future<void> _save() async {
    await _storage.saveNotes(_notes);
  }

  void _openNoteEditor({Note? note}) {
    final isEditing = note != null;
    final titleCtrl = TextEditingController(text: note?.title ?? '');
    final bodyCtrl = TextEditingController(text: note?.content ?? '');

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
          builder: (context, setModalState) => SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  isEditing ? 'Edit Note' : 'New Note',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: titleCtrl,
                  autofocus: !isEditing,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: bodyCtrl,
                  maxLines: 8,
                  decoration: const InputDecoration(
                    labelText: 'Write something...',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () {
                    final title = titleCtrl.text.trim();
                    final body = bodyCtrl.text.trim();
                    if (title.isEmpty) return;
                    if (isEditing) {
                      setState(() {
                        final idx = _notes.indexWhere((n) => n.id == note.id);
                        if (idx >= 0) {
                          _notes[idx] = _notes[idx].copyWith(
                            title: title,
                            content: body,
                          );
                        }
                      });
                    } else {
                      setState(() {
                        _notes.add(Note(
                          id: _uuid.v4(),
                          subjectId: '',
                          title: title,
                          content: body,
                        ));
                      });
                    }
                    _save();
                    Navigator.pop(ctx);
                  },
                  child: Text(isEditing ? 'Save' : 'Add Note'),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmDelete(Note note) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Note?'),
        content: Text('This will permanently delete "${note.title}".'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              setState(() => _notes.removeWhere((n) => n.id == note.id));
              _save();
              Navigator.pop(ctx);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void requestAddNote() => _openNoteEditor();

  @override
  Widget build(BuildContext context) {
    final sorted = List<Note>.from(_notes)..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    return Column(
      children: [
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : sorted.isEmpty
                  ? Center(
                      child: Text(
                        'No notes yet',
                        style: TextStyle(color: Theme.of(context).colorScheme.outline),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 80),
                      itemCount: sorted.length,
                      itemBuilder: (context, index) {
                        final note = sorted[index];
                        return _NoteCard(
                          note: note,
                          onTap: () => _openNoteEditor(note: note),
                          onDelete: () => _confirmDelete(note),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}

class _NoteCard extends StatelessWidget {
  final Note note;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _NoteCard({
    required this.note,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final body = note.content.trim();
    final hasBody = body.isNotEmpty;

    return Dismissible(
      key: Key(note.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => onDelete(),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  note.title,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
                if (hasBody) ...[
                  const SizedBox(height: 6),
                  Text(
                    body,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  'Updated ${_formatUpdated(note.updatedAt)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatUpdated(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
