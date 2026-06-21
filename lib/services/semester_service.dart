import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/semester.dart';
import '../models/week_status.dart';
import '../models/semester_week.dart';
import 'cusp_service.dart';

/// A week becomes eligible to be frozen once we are at or past 12:01am on
/// the Monday that starts two weeks after the week in question ended.
/// Example: Week 02 ends Sunday night. Week 03 starts the next Monday.
/// Week 02 freezes at 12:01am on the Monday that starts Week 04 — just
/// over a week after Week 02 ended, giving the admin all of Week 03 to
/// resolve any conflicts before the result is locked in.
bool isWeekFreezeEligible(SemesterWeek week) {
  final freezeEligibleAt = week.end
      .add(const Duration(days: 7))
      .add(const Duration(minutes: 2));

  return DateTime.now().isAfter(freezeEligibleAt);
}

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

/// Checks the semester for any past weeks that are now eligible to be
/// frozen (see isWeekFreezeEligible) but haven't been yet, and freezes
/// them in order, oldest first.
///
/// "Freezing" a week means: figure out who (if anyone) earned the gold
/// star that week, write that onto the winner's CUSP doc, then advance
/// the semester's lastFrozenWeekNumber marker.
///
/// This is safe to call from any user's app on every load. A Firestore
/// transaction on lastFrozenWeekNumber guards against two clients racing
/// to freeze the same week at the same time — whichever transaction
/// commits first wins, and the second one's compare-and-swap simply
/// no-ops for that week.
Future<void> freezeEligibleWeeks(Semester semester) async {
  final semesterRef = FirebaseFirestore.instance
      .collection('semesters')
      .doc(semester.id);

  for (final week in semester.weeks) {
    if (week.offWeek) {
      continue;
    }

    if (!isWeekFreezeEligible(week)) {
      // Weeks are in chronological order, so once we hit one that isn't
      // eligible yet, none of the later ones are either.
      break;
    }

    // Find out who won gold star for this week. This is the one full
    // user-scan per week, done exactly once, at freeze time.
    final topUid = await getTopPracticerUidForWeek(week: week);

    bool didFreezeThisWeek = false;

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(semesterRef);

      final data = snapshot.data();

      final lastFrozenWeekNumber =
          (data?['lastFrozenWeekNumber'] as int?) ?? 0;

      if (week.weekNumber <= lastFrozenWeekNumber) {
        // Already frozen by another client. Nothing to do.
        return;
      }

      transaction.update(semesterRef, {
        'lastFrozenWeekNumber': week.weekNumber,
      });

      didFreezeThisWeek = true;
    });

    if (didFreezeThisWeek && topUid != null) {
      await setIsGoldStar(uid: topUid, weekId: week.weekId, value: true);
    }
  }
}

/// Returns the highest weekNumber that has already been frozen for this
/// semester. 0 means no weeks have been frozen yet.
Future<int> getLastFrozenWeekNumber(Semester semester) async {
  final snapshot = await FirebaseFirestore.instance
      .collection('semesters')
      .doc(semester.id)
      .get();

  return (snapshot.data()?['lastFrozenWeekNumber'] as int?) ?? 0;
}
