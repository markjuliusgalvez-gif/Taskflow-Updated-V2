enum AssignmentStatus { unfinished, pending, finished }

class Assignment {
  final String id;
  String title;
  String? note;
  AssignmentStatus status;
  DateTime createdAt;
  DateTime? deadline;

  Assignment({
    required this.id,
    required this.title,
    this.note,
    this.status = AssignmentStatus.unfinished,
    DateTime? createdAt,
    this.deadline,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'note': note,
        'status': status.name,
        'createdAt': createdAt.toIso8601String(),
        'deadline': deadline?.toIso8601String(),
      };

  factory Assignment.fromJson(Map<String, dynamic> json) => Assignment(
        id: json['id'],
        title: json['title'],
        note: json['note'],
        status: AssignmentStatus.values.firstWhere(
          (e) => e.name == json['status'],
          orElse: () => AssignmentStatus.unfinished,
        ),
        createdAt: DateTime.parse(json['createdAt']),
        deadline:
            json['deadline'] != null ? DateTime.parse(json['deadline']) : null,
      );

  Assignment copyWith({
    String? title,
    String? note,
    AssignmentStatus? status,
    DateTime? deadline,
  }) {
    return Assignment(
      id: id,
      title: title ?? this.title,
      note: note ?? this.note,
      status: status ?? this.status,
      createdAt: createdAt,
      deadline: deadline ?? this.deadline,
    );
  }
}
