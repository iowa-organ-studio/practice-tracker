import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/semester.dart';

import '../models/week_status.dart';
import '../models/semester_week.dart';

Future<Semester?> getActiveSemester() async {
  final settingsDoc = await FirebaseFirestore.instance
      .collection('settings')
      .doc('semester')
      .get();

  if (!settingsDoc.exists) {
    return null;
  }

  final semesterId = settingsDoc['activeSemester'];

  final semesterDoc = await FirebaseFirestore.instance
      .collection('semesters')
      .doc(semesterId)
      .get();

  if (!semesterDoc.exists) {
    return null;
  }

  return Semester.fromMap(semesterDoc.id, semesterDoc.data()!);
}

WeekStatus computeWeekStatus({
  required SemesterWeek week,

  required int practicedMinutes,

  required int minimumMinutes,

  required bool isCurrentWeek,

  required bool isTopPracticer,
}) {
  final now = DateTime.now();

  if (week.offWeek) {
    return WeekStatus.offWeek;
  }

  if (now.isBefore(week.start)) {
    return WeekStatus.future;
  }

  if (isTopPracticer) {
    return WeekStatus.star;
  }

  if (practicedMinutes >= minimumMinutes) {
    return WeekStatus.green;
  }

  if (isCurrentWeek) {
    return WeekStatus.yellow;
  }

  return WeekStatus.red;
}

Future<int> getPracticeMinutesForWeek({
  required String uid,
  required SemesterWeek week,
}) async {
  final snapshot = await FirebaseFirestore.instance
      .collection('sessions')
      .where('uid', isEqualTo: uid)
      .get();

  int totalSeconds = 0;

  for (final doc in snapshot.docs) {
    final data = doc.data();

    final startTime = (data['startTime'] as Timestamp).toDate();

    if (startTime.isBefore(week.start) || startTime.isAfter(week.end)) {
      continue;
    }

    final rawTimeline = data['timeline'];

    if (rawTimeline == null || rawTimeline is! List || rawTimeline.isEmpty) {
      continue;
    }

    final duration = data['duration'] ?? 0;

    for (int i = 0; i < rawTimeline.length; i++) {
      final current = rawTimeline[i] as Map<String, dynamic>;

      final currentStart = current['start'] ?? 0;

      final nextStart = i < rawTimeline.length - 1
          ? rawTimeline[i + 1]['start'] ?? duration
          : duration;

      final int segmentDuration = (nextStart as int) - (currentStart as int);

      final moving = current['moving'] == true;

      final flagged = current['flagged'] == true;

      final paused = current['paused'] == true;

      final countsAsPractice = !moving && !flagged && !paused;

      if (countsAsPractice) {
        totalSeconds += segmentDuration;
      }
    }
  }

  return (totalSeconds / 60).round();
}
