import 'semester_week.dart';

class Semester {
  final String id;

  final String name;

  final List<SemesterWeek> weeks;

  Semester({
    required this.id,
    required this.name,
    required this.weeks,
  });

  factory Semester.fromMap(
    String id,
    Map<String, dynamic> map,
  ) {
    return Semester(
      id: id,

      name: map['name'],

      weeks:
          (map['weeks'] as List)
              .map(
                (w) => SemesterWeek.fromMap(w),
              )
              .toList(),
    );
  }
}