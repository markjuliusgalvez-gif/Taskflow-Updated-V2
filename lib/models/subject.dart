import 'assignment.dart';

class Subject {
  final String id;
  String name;
  List<Assignment> assignments;
  bool isExpanded;

  Subject({
    required this.id,
    required this.name,
    List<Assignment>? assignments,
    this.isExpanded = true,
  }) : assignments = assignments ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'assignments': assignments.map((a) => a.toJson()).toList(),
        'isExpanded': isExpanded,
      };

  factory Subject.fromJson(Map<String, dynamic> json) => Subject(
        id: json['id'],
        name: json['name'],
        assignments: (json['assignments'] as List)
            .map((a) => Assignment.fromJson(a))
            .toList(),
        isExpanded: json['isExpanded'] ?? true,
      );
}