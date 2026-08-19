enum NoteStatus { pending, finished, unfinished }

class Note {
  final String id;
  final String subjectId;
  String title;
  String content;
  NoteStatus status;
  final DateTime createdAt;
  DateTime updatedAt;

  Note({
    required this.id,
    required this.subjectId,
    required this.title,
    required this.content,
    this.status = NoteStatus.unfinished,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'subjectId': subjectId,
        'title': title,
        'content': content,
        'status': status.name,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Note.fromJson(Map<String, dynamic> json) => Note(
        id: json['id'],
        subjectId: json['subjectId'],
        title: json['title'],
        content: json['content'],
        status: NoteStatus.values.firstWhere(
          (e) => e.name == json['status'],
          orElse: () => NoteStatus.unfinished,
        ),
        createdAt: DateTime.parse(json['createdAt']),
        updatedAt: DateTime.parse(json['updatedAt']),
      );

  Note copyWith({
    String? title,
    String? content,
    NoteStatus? status,
    DateTime? updatedAt,
  }) {
    return Note(
      id: id,
      subjectId: subjectId,
      title: title ?? this.title,
      content: content ?? this.content,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}
