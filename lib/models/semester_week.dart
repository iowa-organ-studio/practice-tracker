import 'package:cloud_firestore/cloud_firestore.dart';

class SemesterWeek {
  final int weekNumber;

  final DateTime start;

  final DateTime end;

  final bool offWeek;
  final String weekId;

  SemesterWeek({
    required this.weekNumber,
    required this.start,
    required this.end,
    required this.offWeek,
    required this.weekId,
  });

  factory SemesterWeek.fromMap(Map<String, dynamic> map) {
    final start = (map['start'] as Timestamp).toDate();

    final end = DateTime(start.year, start.month, start.day + 6, 23, 59, 59);

    return SemesterWeek(
      weekNumber: map['weekNumber'],

      weekId: map['weekId'],

      start: start,

      end: end,

      offWeek: map['deadWeek'] ?? false,
    );
  }
}
