
import 'package:cloud_firestore/cloud_firestore.dart';

import 'review_service.dart';

class DailyPracticeReport {
  final DateTime date;

  int practiceSeconds = 0;
  int movingSeconds = 0;
  int pausedSeconds = 0;
  int flaggedSeconds = 0;

  DailyPracticeReport(this.date);

  int get totalSeconds =>
      practiceSeconds +
      movingSeconds +
      pausedSeconds +
      flaggedSeconds;
}

class OrganPracticeReport {
  final String instrument;
  int totalSeconds = 0;

  OrganPracticeReport(this.instrument);
}

class GoalPracticeReport {
  final String goalId;
  final String title;

  int sessions = 0;
  final Set<String> days = {};

  GoalPracticeReport({
    required this.goalId,
    required this.title,
  });

  int get daysPracticed => days.length;
}

class PracticeReport {
  final DateTime startDate;
  final DateTime endDate;

  final List<DailyPracticeReport> days;
  final List<OrganPracticeReport> organs;
  final List<GoalPracticeReport> goals;

  final int sessionCount;

  PracticeReport({
    required this.startDate,
    required this.endDate,
    required this.days,
    required this.organs,
    required this.goals,
    required this.sessionCount,
  });

  int get totalSeconds =>
    days.fold<int>(0, (total, day) => total + day.totalSeconds);

  int get daysPracticed =>
      days.where((day) => day.totalSeconds > 0).length;
}

class PracticeReportService {
  static Future<PracticeReport> generate({
    required String uid,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final firstDay = DateTime(
      startDate.year,
      startDate.month,
      startDate.day,
    );

    final lastDayExclusive = DateTime(
      endDate.year,
      endDate.month,
      endDate.day + 1,
    );

    if (!firstDay.isBefore(lastDayExclusive)) {
      throw ArgumentError('Invalid report date range.');
    }

    // Prepare a daily entry for every date, including
    // days with no recorded practice.
    final dailyMap = <String, DailyPracticeReport>{};

    String dayKey(DateTime date) =>
        '${date.year}-${date.month}-${date.day}';

    for (
      var day = firstDay;
      day.isBefore(lastDayExclusive);
      day = DateTime(day.year, day.month, day.day + 1)
    ) {
      dailyMap[dayKey(day)] = DailyPracticeReport(day);
    }

    final sessions = await loadReviewSessions(uid);

    final organTotals = <String, OrganPracticeReport>{};
    final goalTotals = <String, GoalPracticeReport>{};

    // Read goal titles, including archived goals.
    final goalSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('goals')
        .get();

    final goalTitles = <String, String>{
      for (final doc in goalSnapshot.docs)
        doc.id: (doc.data()['title'] ?? 'Untitled goal').toString(),
    };

    int sessionCount = 0;

    for (final session in sessions) {
      final data = session.data;

      final rawStart = data['startTime'];
      final rawEnd = data['endTime'];

      if (rawStart is! Timestamp || rawEnd is! Timestamp) {
        continue;
      }

      final sessionStart = rawStart.toDate().toLocal();
      final sessionEnd = rawEnd.toDate().toLocal();

      if (!sessionEnd.isAfter(sessionStart)) continue;

      // Ignore sessions outside the requested period.
      if (!sessionStart.isBefore(lastDayExclusive) ||
          !sessionEnd.isAfter(firstDay)) {
        continue;
      }

      // Use the recorded duration, but never extend
      // past the session's actual end timestamp.
      final elapsedSeconds =
          sessionEnd.difference(sessionStart).inSeconds;

      final recordedDuration = data['duration'];

      final durationSeconds = recordedDuration is num
    ? recordedDuration.toInt().clamp(0, 10800)
    : elapsedSeconds.clamp(0, 10800);

      if (durationSeconds <= 0) continue;

     

      sessionCount++;

      final instrument =
          (data['instrument'] ?? 'Other').toString();

      final organ = organTotals.putIfAbsent(
        instrument,
        () => OrganPracticeReport(instrument),
      );

      final rawTimeline = data['timeline'];

      final segments = <Map<String, dynamic>>[];

      if (rawTimeline is List) {
        for (final entry in rawTimeline) {
          if (entry is Map) {
            segments.add(
              Map<String, dynamic>.from(entry),
            );
          }
        }
      }

      // If no timeline exists, treat the session
      // as ordinary practice for reporting purposes.
      if (segments.isEmpty) {
        segments.add({
          'start': 0,
          'moving': false,
          'paused': false,
          'flagged': false,
          'fraudulent': false,
        });
      }

      // Preserve timeline order for equal timestamps.
      segments.sort((a, b) {
        final aStart = (a['start'] as num?)?.toInt() ?? 0;
        final bStart = (b['start'] as num?)?.toInt() ?? 0;
        return aStart.compareTo(bStart);
      });

      for (int i = 0; i < segments.length; i++) {
        final segment = segments[i];

        final segmentStartSeconds =
            ((segment['start'] as num?)?.toInt() ?? 0)
                .clamp(0, durationSeconds);

        final segmentEndSeconds = i + 1 < segments.length
            ? ((segments[i + 1]['start'] as num?)?.toInt() ??
                    durationSeconds)
                .clamp(0, durationSeconds)
            : durationSeconds;

        if (segmentEndSeconds <= segmentStartSeconds) {
          continue;
        }

        final moving = segment['moving'] == true;
        final paused = segment['paused'] == true;
        final flagged = segment['flagged'] == true;

        // Report categories are mutually exclusive.
        // Paused takes precedence, then moving,
        // then flagged, then ordinary practice.
        final category = paused
            ? 'paused'
            : moving
                ? 'moving'
                : flagged
                    ? 'flagged'
                    : 'practice';

        var intervalStart = sessionStart.add(
          Duration(seconds: segmentStartSeconds),
        );

        final intervalEnd = sessionStart.add(
          Duration(seconds: segmentEndSeconds),
        );

        // Divide intervals at local midnight.
        while (intervalStart.isBefore(intervalEnd)) {
          final nextMidnight = DateTime(
            intervalStart.year,
            intervalStart.month,
            intervalStart.day + 1,
          );

          final pieceEnd = intervalEnd.isBefore(nextMidnight)
              ? intervalEnd
              : nextMidnight;

          final pieceStart = intervalStart.isAfter(firstDay)
              ? intervalStart
              : firstDay;

          final clippedEnd =
              pieceEnd.isBefore(lastDayExclusive)
                  ? pieceEnd
                  : lastDayExclusive;

          if (clippedEnd.isAfter(pieceStart)) {
            final seconds = clippedEnd
                .difference(pieceStart)
                .inSeconds;

            final daily = dailyMap[dayKey(pieceStart)];

            if (daily != null) {
              switch (category) {
                case 'paused':
                  daily.pausedSeconds += seconds;
                  break;
                case 'moving':
                  daily.movingSeconds += seconds;
                  break;
                case 'flagged':
                  daily.flaggedSeconds += seconds;
                  break;
                default:
                  daily.practiceSeconds += seconds;
              }

              organ.totalSeconds += seconds;
            }
          }

          intervalStart = pieceEnd;
        }
      }

      // Count a goal once per session, regardless
      // of how many times it was selected.
      final goalIds = (data['goalIds'] is List)
          ? (data['goalIds'] as List)
              .whereType<String>()
              .toSet()
          : <String>{};

      for (final goalId in goalIds) {
        final goal = goalTotals.putIfAbsent(
          goalId,
          () => GoalPracticeReport(
            goalId: goalId,
            title: goalTitles[goalId] ?? 'Archived or unknown goal',
          ),
        );

        goal.sessions++;
        goal.days.add(dayKey(sessionStart));
      }
    }

    final days = dailyMap.values.toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    final organs = organTotals.values
        .where((organ) => organ.totalSeconds > 0)
        .toList()
      ..sort(
        (a, b) => b.totalSeconds.compareTo(a.totalSeconds),
      );

    final goals = goalTotals.values.toList()
      ..sort((a, b) => b.sessions.compareTo(a.sessions));

    return PracticeReport(
      startDate: firstDay,
      endDate: endDate,
      days: days,
      organs: organs,
      goals: goals,
      sessionCount: sessionCount,
    );
  }
}
