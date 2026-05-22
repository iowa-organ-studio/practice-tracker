import 'package:cloud_firestore/cloud_firestore.dart';

class WeekInfo {
  final String semesterId;

  final String weekId;

  final int weekNumber;

  final bool offWeek;

  final DateTime start;

  final DateTime end;

  WeekInfo({
    required this.semesterId,
    required this.weekId,
    required this.weekNumber,
    required this.offWeek,
    required this.start,
    required this.end,
  });
}

Future<WeekInfo?> getCurrentWeekInfo() async {
  final semesters = await FirebaseFirestore.instance
      .collection('semesters')
      .get();

  final now = DateTime.now();

  for (final doc in semesters.docs) {
    final data = doc.data();

    final weeks = List<Map<String, dynamic>>.from(data['weeks'] ?? []);

    for (final week in weeks) {
      final start = (week['start'] as Timestamp).toDate();

      final end = DateTime(start.year, start.month, start.day + 6, 23, 59, 59);

      final inWeek = now.isAfter(start) && now.isBefore(end);

      if (inWeek) {
        return WeekInfo(
          semesterId: doc.id,

          weekId: week['weekId'],

          weekNumber: week['weekNumber'],

          offWeek: week['offWeek'] ?? false,

          start: start,

          end: end,
        );
      }
    }
  }

  return null;
}
