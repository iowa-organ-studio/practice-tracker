class SemesterWeek {
  final int weekNumber;

  final DateTime start;

  final DateTime end;

  final bool offWeek;

  SemesterWeek({
    required this.weekNumber,
    required this.start,
    required this.end,
    required this.offWeek,
  });

  factory SemesterWeek.fromMap(
    Map<String, dynamic> map,
  ) {
    return SemesterWeek(
      weekNumber: map['weekNumber'],

      start:
          DateTime.parse(
            map['start'],
          ),

      end:
          DateTime.parse(
            map['end'],
          ),

      offWeek:
          map['offWeek'] ?? false,
    );
  }
}