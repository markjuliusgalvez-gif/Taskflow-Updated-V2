import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/subject.dart';
import '../models/note.dart';

class StorageService {
  static const _subjectsKey = 'subjects_data';
  static const _notesKey = 'notes_data';

  Future<List<Subject>> loadSubjects() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_subjectsKey);
    if (raw == null) return [];
    final List decoded = jsonDecode(raw);
    return decoded.map((e) => Subject.fromJson(e)).toList();
  }

  Future<void> saveSubjects(List<Subject> subjects) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(subjects.map((s) => s.toJson()).toList());
    await prefs.setString(_subjectsKey, encoded);
  }

  Future<List<Note>> loadNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_notesKey);
    if (raw == null) return [];
    final List decoded = jsonDecode(raw);
    return decoded.map((e) => Note.fromJson(e)).toList();
  }

  Future<void> saveNotes(List<Note> notes) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(notes.map((n) => n.toJson()).toList());
    await prefs.setString(_notesKey, encoded);
  }
}
