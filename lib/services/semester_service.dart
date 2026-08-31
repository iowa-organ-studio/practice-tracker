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

  final seconds = (data['totalPracticeSeconds'] as int?) ?? 0;

  return (seconds / 60).round();
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

/// Scans every (non-admin) user's practice total for the given week and
/// returns the uid with the highest total, or null if nobody practiced.
///
/// All per-user lookups run concurrently via Future.wait instead of one
/// at a time in a for-loop — with N students this turns ~N sequential
/// round-trips into roughly 1 round-trip's worth of wall-clock time,
/// which is the main thing that was making this slow.
Future<String?> getTopPracticerUidForWeek({required SemesterWeek week}) async {
  final usersSnapshot = await FirebaseFirestore.instance
      .collection('users')
      .get();

  final studentDocs = usersSnapshot.docs
      .where((doc) => (doc.data()['role'] ?? '') != 'admin')
      .toList();

  final results = await Future.wait(studentDocs.map((userDoc) async {
    final uid = userDoc.id;
    final minutes = await getWeekPracticeTotal(uid: uid, weekId: week.weekId);
    return MapEntry(uid, minutes);
  }));

  String? topUid;
  int topMinutes = -1;

  for (final entry in results) {
    if (entry.value > topMinutes && entry.value > 0) {
      topMinutes = entry.value;
      topUid = entry.key;
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

  // Read the current freeze marker once up front.
  // This prevents us from rescanning already-frozen weeks on every
  // HomePage load.
  final semesterSnapshot = await semesterRef.get();

  var lastFrozenWeekNumber =
      (semesterSnapshot.data()?['lastFrozenWeekNumber'] as int?) ?? 0;

  for (final week in semester.weeks) {
    if (week.offWeek) {
      continue;
    }

    if (!isWeekFreezeEligible(week)) {
      // Weeks are in chronological order, so once we hit one that isn't
      // eligible yet, none of the later ones are either.
      break;
    }

    // IMPORTANT: Check whether this week is already frozen BEFORE doing
    // the expensive user/CUSP scan.
    if (week.weekNumber <= lastFrozenWeekNumber) {
      continue;
    }

    // This is the first time we actually need to determine the winner
    // for this week.
    final topUid = await getTopPracticerUidForWeek(week: week);

    bool didFreezeThisWeek = false;

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(semesterRef);

      final data = snapshot.data();

      final transactionLastFrozenWeekNumber =
          (data?['lastFrozenWeekNumber'] as int?) ?? 0;

      // Another client may have frozen this week while we were doing the
      // expensive scan. The transaction remains the final safety check.
      if (week.weekNumber <= transactionLastFrozenWeekNumber) {
        return;
      }

      transaction.update(semesterRef, {
        'lastFrozenWeekNumber': week.weekNumber,
      });

      didFreezeThisWeek = true;
    });

    if (didFreezeThisWeek) {
      // Keep our local marker current so later iterations do not
      // unnecessarily reconsider the same week.
      lastFrozenWeekNumber = week.weekNumber;

      if (topUid != null) {
        await setIsGoldStar(
          uid: topUid,
          weekId: week.weekId,
          value: true,
        );
      }
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
