import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> uploadSummer2026Semester() async {
  final semesterId = 'summer_2026';

  final startDate = DateTime(
    2026,
    5,
    11,
  );

  List<Map<String, dynamic>> weeks = [];

  for (int i = 0; i < 16; i++) {
    final weekStart =
        startDate.add(
          Duration(days: i * 7),
        );

    final weekEnd =
        weekStart.add(
          const Duration(
            days: 6,
            hours: 23,
            minutes: 59,
            seconds: 59,
          ),
        );

    weeks.add({
      'weekNumber': i + 1,

      'start':
          weekStart.toIso8601String(),

      'end':
          weekEnd.toIso8601String(),

      'offWeek': false,
    });
  }

  await FirebaseFirestore.instance
      .collection('semesters')
      .doc(semesterId)
      .set({
        'name': 'Summer 2026',
        'weeks': weeks,
      });

  await FirebaseFirestore.instance
      .collection('settings')
      .doc('semester')
      .set({
        'activeSemester': semesterId,
      });

  print('Summer 2026 uploaded');
}