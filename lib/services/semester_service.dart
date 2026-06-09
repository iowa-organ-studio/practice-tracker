import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/semester.dart';
import '../models/week_status.dart';
import '../models/semester_week.dart';
import 'cusp_service.dart';

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

  required int practicedSeconds,

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

  if (practicedSeconds >= minimumMinutes * 60) {
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
      .collection('users')
      .doc(uid)
      .collection('weeks')
      .doc(week.weekId)
      .get();

  if (!snapshot.exists) {
    return 0;
  }

  final data = snapshot.data()!;

  return (data['totalPracticeMinutes'] as int?) ?? 0;
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

    final uid = userDoc.id;

    final minutes = await getWeekPracticeTotal(uid: uid, weekId: week.weekId);

    if (minutes > topMinutes && minutes > 0) {
      topMinutes = minutes;

      topUid = uid;
    }
  }

  return topUid;
}
