import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/segment.dart';

import '../painters/graph_painter.dart';

import '../services/firebase_paths.dart';

import '../services/conflict_service.dart';

class ConflictDetailPage extends StatefulWidget {
  final String conflictId;

  const ConflictDetailPage({super.key, required this.conflictId});

  @override
  State<ConflictDetailPage> createState() => _ConflictDetailPageState();
}

class _ConflictDetailPageState extends State<ConflictDetailPage> {
  String? winnerSessionId;

  List<Segment> parseTimeline(List<dynamic> raw) {
    return raw.map((e) {
      final map = e as Map<String, dynamic>;

      return Segment(
        map['start'] ?? 0,

        map['moving'] ?? false,

        flagged: map['flagged'] ?? false,

        paused: map['paused'] ?? false,

        resolved: map['resolved'] ?? false,

        fraudulent: map['fraudulent'] ?? false,
      );
    }).toList();
  }

  Future<int> computePracticeSeconds(
    List<dynamic> rawTimeline,
    int duration,
  ) async {
    final timeline = parseTimeline(rawTimeline);

    int practice = 0;

    for (int i = 0; i < timeline.length; i++) {
      final current = timeline[i];

      final end = i < timeline.length - 1 ? timeline[i + 1].start : duration;

      final segmentDuration = end - current.start;

      final legitimate =
          !current.moving &&
          !current.paused &&
          !current.flagged &&
          !current.fraudulent;

      final resolvedPractice =
          current.resolved &&
          !current.fraudulent &&
          !current.paused &&
          !current.moving;

      if (legitimate || resolvedPractice) {
        practice += segmentDuration;
      }
    }

    return practice;
  }

  Future<void> recomputeWeekTotal({
    required String uid,
    required String weekId,
  }) async {
    final sessions = await FirebasePaths.sessionsCollection(
      uid: uid,
      weekId: weekId,
    ).get();

    int total = 0;

    for (final doc in sessions.docs) {
      final data = doc.data();

      total += (data['practiceSeconds'] as int?) ?? 0;
    }

    await FirebasePaths.weekDoc(
      uid: uid,
      weekId: weekId,
    ).update({'totalPracticeSeconds': total});
  }

  Future<void> resolveWinner(Map<String, dynamic> winnerRef) async {
    final winnerDoc = await FirebasePaths.sessionDoc(
      uid: winnerRef['uid'],

      weekId: winnerRef['weekId'],

      sessionId: winnerRef['sessionId'],
    ).get();

    final data = winnerDoc.data()!;

    final timeline = List<Map<String, dynamic>>.from(data['timeline'] ?? []);

    final updatedTimeline = timeline.map((seg) {
      final flagged = seg['flagged'] ?? false;

      return {
        ...seg,

        'flagged': flagged ? false : (seg['flagged'] ?? false),

        'resolved': flagged ? true : (seg['resolved'] ?? false),
      };
    }).toList();

    final duration = data['duration'] ?? 0;

    final updatedPracticeSeconds = await computePracticeSeconds(
      updatedTimeline,
      duration,
    );

    await FirebasePaths.sessionDoc(
      uid: winnerRef['uid'],

      weekId: winnerRef['weekId'],

      sessionId: winnerRef['sessionId'],
    ).update({
      'timeline': updatedTimeline,

      'practiceSeconds': updatedPracticeSeconds,
    });

    await recomputeWeekTotal(
      uid: winnerRef['uid'],
      weekId: winnerRef['weekId'],
    );

    await FirebasePaths.conflictsCollection().doc(widget.conflictId).update({
      'winnerSessionId': winnerRef['sessionId'],
    });

    setState(() {
      winnerSessionId = winnerRef['sessionId'];
    });

    if (!mounted) return;

    showDialog(
      context: context,

      builder: (_) {
        return AlertDialog(
          title: const Text("Practice Restored"),

          content: const Text(
            "Resolved practice has been restored to the selected student.",
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },

              child: const Text("OK"),
            ),
          ],
        );
      },
    );
  }

  Future<void> markFlaggedTimeFraudulent(Map<String, dynamic> loserRef) async {
    final loserDoc = await FirebasePaths.sessionDoc(
      uid: loserRef['uid'],

      weekId: loserRef['weekId'],

      sessionId: loserRef['sessionId'],
    ).get();

    final data = loserDoc.data()!;

    final timeline = List<Map<String, dynamic>>.from(data['timeline'] ?? []);

    final updatedTimeline = timeline.map((seg) {
      final flagged = seg['flagged'] ?? false;

      return {
        ...seg,

        'flagged': flagged ? false : (seg['flagged'] ?? false),

        'resolved': false,

        'fraudulent': flagged ? true : false,
      };
    }).toList();

    final updatedPracticeSeconds = await computePracticeSeconds(
      updatedTimeline,
      data['duration'] ?? 0,
    );

    await FirebasePaths.sessionDoc(
      uid: loserRef['uid'],

      weekId: loserRef['weekId'],

      sessionId: loserRef['sessionId'],
    ).update({
      'timeline': updatedTimeline,

      'practiceSeconds': updatedPracticeSeconds,
    });

    await recomputeWeekTotal(uid: loserRef['uid'], weekId: loserRef['weekId']);

    await FirebasePaths.conflictsCollection().doc(widget.conflictId).update({
      'resolved': true,
    });

    if (!mounted) return;

    Navigator.pop(context);
  }

  Future<void> markEntireSessionFraudulent(
    Map<String, dynamic> loserRef,
  ) async {
    final loserDoc = await FirebasePaths.sessionDoc(
      uid: loserRef['uid'],

      weekId: loserRef['weekId'],

      sessionId: loserRef['sessionId'],
    ).get();

    final data = loserDoc.data()!;

    final timeline = List<Map<String, dynamic>>.from(data['timeline'] ?? []);

    final updatedTimeline = timeline.map((seg) {
      return {...seg, 'flagged': false, 'resolved': false, 'fraudulent': true};
    }).toList();

    final updatedPracticeSeconds = await computePracticeSeconds(
      updatedTimeline,
      data['duration'] ?? 0,
    );

    await FirebasePaths.sessionDoc(
      uid: loserRef['uid'],

      weekId: loserRef['weekId'],

      sessionId: loserRef['sessionId'],
    ).update({
      'timeline': updatedTimeline,

      'practiceSeconds': updatedPracticeSeconds,
    });

    await recomputeWeekTotal(uid: loserRef['uid'], weekId: loserRef['weekId']);

    await FirebasePaths.conflictsCollection().doc(widget.conflictId).update({
      'resolved': true,
    });

    if (!mounted) return;

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Conflict Detail")),

      body: FutureBuilder<DocumentSnapshot>(
        future: FirebasePaths.conflictsCollection()
            .doc(widget.conflictId)
            .get(),

        builder: (context, conflictSnapshot) {
          if (!conflictSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final conflict =
              conflictSnapshot.data!.data() as Map<String, dynamic>;

          final sessionRefs = List<Map<String, dynamic>>.from(
            conflict['sessionRefs'] ?? [],
          );

          return FutureBuilder<List<DocumentSnapshot>>(
            future: loadConflictSessions(sessionRefs),

            builder: (context, sessionSnapshot) {
              if (!sessionSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final sessions = sessionSnapshot.data!;

              sessions.sort((a, b) {
                final aData = a.data() as Map<String, dynamic>;

                final bData = b.data() as Map<String, dynamic>;

                final aStart = (aData['startTime'] as Timestamp).toDate();

                final bStart = (bData['startTime'] as Timestamp).toDate();

                return aStart.compareTo(bStart);
              });

              return ListView(
                children: [
                  ...sessions.map((s) {
                    final data = s.data() as Map<String, dynamic>;

                    final timeline = parseTimeline(data['timeline'] ?? []);

                    final duration = data['duration'] ?? 0;

                    final start = (data['startTime'] as Timestamp).toDate();

                    return Padding(
                      padding: const EdgeInsets.all(12),

                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,

                        children: [
                          Text(
                            "${data['name']} — ${data['instrument']}",

                            style: const TextStyle(
                              fontSize: 18,

                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          const SizedBox(height: 8),

                          SizedBox(
                            height: 84,

                            child: CustomPaint(
                              size: Size.infinite,

                              painter: GraphPainter(
                                timeline,

                                duration,

                                start,

                                fixedThreeHourScale: true,
                              ),
                            ),
                          ),

                          Text(
                            "Firebase document ID: ${s.id}",

                            style: const TextStyle(
                              fontSize: 12,

                              color: Colors.grey,
                            ),
                          ),

                          const SizedBox(height: 18),
                        ],
                      ),
                    );
                  }),

                  const SizedBox(height: 10),

                  if (winnerSessionId == null) ...[
                    const Center(
                      child: Text(
                        "Winner?",

                        style: TextStyle(
                          fontSize: 18,

                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    ...sessionRefs.map((ref) {
                      final session = sessions.firstWhere(
                        (s) => s.id == ref['sessionId'],
                      );

                      final data = session.data() as Map<String, dynamic>;

                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,

                          vertical: 6,
                        ),

                        child: ElevatedButton(
                          onPressed: () {
                            resolveWinner(ref);
                          },

                          child: Text(data['name']),
                        ),
                      );
                    }),
                  ] else ...[
                    Builder(
                      builder: (_) {
                        final loserRef = sessionRefs.firstWhere(
                          (ref) => ref['sessionId'] != winnerSessionId,
                        );

                        final loserSession = sessions.firstWhere(
                          (s) => s.id == loserRef['sessionId'],
                        );

                        final loserData =
                            loserSession.data() as Map<String, dynamic>;

                        return Column(
                          children: [
                            const SizedBox(height: 12),

                            Text(
                              "${loserData['name']} — ${loserData['instrument']}",

                              style: const TextStyle(
                                fontSize: 18,

                                fontWeight: FontWeight.bold,
                              ),
                            ),

                            const SizedBox(height: 16),

                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                              ),

                              child: ElevatedButton(
                                onPressed: () {
                                  markEntireSessionFraudulent(loserRef);
                                },

                                child: const Text(
                                  "Label entire session as fraudulent",
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),

                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                              ),

                              child: ElevatedButton(
                                onPressed: () {
                                  markFlaggedTimeFraudulent(loserRef);
                                },

                                child: const Text(
                                  "Label only flagged minutes as fraudulent",
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ],
              );
            },
          );
        },
      ),
    );
  }
}
