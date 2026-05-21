import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/semester.dart';

import '../models/week_status.dart';
import '../models/semester_week.dart';

Future<Semester?> getActiveSemester() async {
  final snapshot = await FirebaseFirestore.instance
      .collection('semesters')
      .get();

  final now = DateTime.now();

  for (final doc in snapshot.docs) {
    final semester = Semester.fromMap(doc.id, doc.data());

    if (semester.weeks.isEmpty) {
      continue;
    }

    final firstWeek = semester.weeks.first;

    final lastWeek = semester.weeks.last;

    final semesterStart = firstWeek.start;

    final semesterEnd = lastWeek.end;

    final inSemester =
        !now.isBefore(semesterStart) && !now.isAfter(semesterEnd);

    if (inSemester) {
      return semester;
    }
  }

  return null;
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

    final sessionUid = data['uid'];

    final userQuery = await FirebaseFirestore.instance
        .collection('users')
        .where('uid', isEqualTo: sessionUid)
        .limit(1)
        .get();

    if (userQuery.docs.isNotEmpty) {
      final userData = userQuery.docs.first.data();

      if ((userData['role'] ?? 'student') == 'admin') {
        continue;
      }
    }

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

Future<String> getWeekLabelForDate(DateTime date) async {
  final semester = await getActiveSemester();

  if (semester == null) {
    return "No Semester";
  }

  for (final week in semester.weeks) {
    final inWeek = !date.isBefore(week.start) && !date.isAfter(week.end);

    if (inWeek) {
      return "Week ${week.weekNumber}";
    }
  }

  return "Outside Semester";
}

Future<String?> getTopPracticerUidForWeek({required SemesterWeek week}) async {
  final usersSnapshot = await FirebaseFirestore.instance
      .collection('users')
      .get();

  String? topUid;

  int topMinutes = -1;

  for (final userDoc in usersSnapshot.docs) {
    final data = userDoc.data();

    if ((data['role'] ?? '') == 'admin') {
      continue;
    }

    final uid = data['uid'];

    if (uid == null) {
      continue;
    }

    final minutes = await getPracticeMinutesForWeek(uid: uid, week: week);

    if (minutes > topMinutes) {
      topMinutes = minutes;

      topUid = uid;
    }
  }

  return topUid;
}
