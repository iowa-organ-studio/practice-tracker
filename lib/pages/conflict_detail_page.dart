import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/segment.dart';

import '../painters/graph_painter.dart';

class ConflictDetailPage extends StatefulWidget {
  final String conflictId;

  const ConflictDetailPage({super.key, required this.conflictId});

  @override
  State<ConflictDetailPage> createState() => _ConflictDetailPageState();
}

class _ConflictDetailPageState extends State<ConflictDetailPage> {
  String? winnerSessionId;
  Future<void> resolveWinner(String winnerSessionId) async {
    final sessionDoc = await FirebaseFirestore.instance
        .collection('sessions')
        .doc(winnerSessionId)
        .get();

    final data = sessionDoc.data() as Map<String, dynamic>;

    final timeline = List<Map<String, dynamic>>.from(data['timeline'] ?? []);

    final updatedTimeline = timeline.map((seg) {
      final flagged = seg['flagged'] ?? false;

      return {
        ...seg,

        'flagged': flagged ? false : (seg['flagged'] ?? false),

        'resolved': flagged ? true : (seg['resolved'] ?? false),
      };
    }).toList();

    await FirebaseFirestore.instance
        .collection('sessions')
        .doc(winnerSessionId)
        .update({'timeline': updatedTimeline});

    await FirebaseFirestore.instance
        .collection('conflicts')
        .doc(widget.conflictId)
        .update({'winnerSessionId': winnerSessionId});

    setState(() {
      this.winnerSessionId = winnerSessionId;
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

  Future<void> markEntireSessionFraudulent(String loserSessionId) async {
    final sessionDoc = await FirebaseFirestore.instance
        .collection('sessions')
        .doc(loserSessionId)
        .get();

    final data = sessionDoc.data() as Map<String, dynamic>;

    final timeline = List<Map<String, dynamic>>.from(data['timeline'] ?? []);

    final updatedTimeline = timeline.map((seg) {
      return {...seg, 'flagged': false, 'resolved': false, 'fraudulent': true};
    }).toList();

    await FirebaseFirestore.instance
        .collection('sessions')
        .doc(loserSessionId)
        .update({'timeline': updatedTimeline});

    final currentConflict = await FirebaseFirestore.instance
        .collection('conflicts')
        .doc(widget.conflictId)
        .get();

    final conflictData = currentConflict.data() as Map<String, dynamic>;

    final sessionIds = List<String>.from(conflictData['sessionIds'] ?? []);

    sessionIds.sort();

    final matchingConflicts = await FirebaseFirestore.instance
        .collection('conflicts')
        .where('organ', isEqualTo: conflictData['organ'])
        .get();

    for (final doc in matchingConflicts.docs) {
      final data = doc.data();

      final otherSessionIds = List<String>.from(data['sessionIds'] ?? []);

      otherSessionIds.sort();

      final sameConflict = otherSessionIds.join('_') == sessionIds.join('_');

      if (sameConflict) {
        await FirebaseFirestore.instance
            .collection('conflicts')
            .doc(doc.id)
            .update({'resolved': true});
      }
    }

    if (!mounted) return;

    Navigator.pop(context);
  }

  Future<void> markFlaggedTimeFraudulent(String loserSessionId) async {
    final sessionDoc = await FirebaseFirestore.instance
        .collection('sessions')
        .doc(loserSessionId)
        .get();

    final data = sessionDoc.data() as Map<String, dynamic>;

    final timeline = List<Map<String, dynamic>>.from(data['timeline'] ?? []);

    final updatedTimeline = timeline.map((seg) {
      final flagged = seg['flagged'] ?? false;

      return {
        ...seg,

        'flagged': flagged ? false : (seg['flagged'] ?? false),

        'resolved': flagged ? false : (seg['resolved'] ?? false),

        'fraudulent': flagged ? true : false,
      };
    }).toList();

    await FirebaseFirestore.instance
        .collection('sessions')
        .doc(loserSessionId)
        .update({'timeline': updatedTimeline});

    final currentConflict = await FirebaseFirestore.instance
        .collection('conflicts')
        .doc(widget.conflictId)
        .get();

    final conflictData = currentConflict.data() as Map<String, dynamic>;

    final sessionIds = List<String>.from(conflictData['sessionIds'] ?? []);

    sessionIds.sort();

    final matchingConflicts = await FirebaseFirestore.instance
        .collection('conflicts')
        .where('organ', isEqualTo: conflictData['organ'])
        .get();

    for (final doc in matchingConflicts.docs) {
      final data = doc.data();

      final otherSessionIds = List<String>.from(data['sessionIds'] ?? []);

      otherSessionIds.sort();

      final sameConflict = otherSessionIds.join('_') == sessionIds.join('_');

      if (sameConflict) {
        await FirebaseFirestore.instance
            .collection('conflicts')
            .doc(doc.id)
            .update({'resolved': true});
      }
    }

    if (!mounted) return;

    Navigator.pop(context);
  }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Conflict Detail")),

      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('conflicts')
            .doc(widget.conflictId)
            .get(),

        builder: (context, conflictSnapshot) {
          if (!conflictSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final conflict =
              conflictSnapshot.data!.data() as Map<String, dynamic>;

          final sessionIds = List<String>.from(conflict['sessionIds']);

          return FutureBuilder<List<DocumentSnapshot>>(
            future: Future.wait(
              sessionIds.map(
                (id) => FirebaseFirestore.instance
                    .collection('sessions')
                    .doc(id)
                    .get(),
              ),
            ),

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

                    ...sessions.map((s) {
                      final data = s.data() as Map<String, dynamic>;

                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 6,
                        ),

                        child: ElevatedButton(
                          onPressed: () {
                            resolveWinner(s.id);
                          },

                          child: Text(data['name']),
                        ),
                      );
                    }),
                  ] else ...[
                    Builder(
                      builder: (_) {
                        final loserSession = sessions.firstWhere(
                          (s) => s.id != winnerSessionId,
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
                                  markEntireSessionFraudulent(loserSession.id);
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
                                  markFlaggedTimeFraudulent(loserSession.id);
                                },

                                child: const Text(
                                  "Label only flagged time as fraudulent",
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
