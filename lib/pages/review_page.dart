import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/segment.dart';
import '../models/wave_point.dart';

import '../painters/graph_painter.dart';
import '../painters/waveform_painter.dart';

import '../services/user_service.dart';

import '../theme/app_colors.dart';

import '../services/semester_service.dart';

class ReviewPage extends StatelessWidget {
  final String? overrideUid;

  const ReviewPage({super.key, this.overrideUid});

  String formatDate(DateTime d) {
    const months = [
      "Jan",
      "Feb",
      "Mar",
      "Apr",
      "May",
      "Jun",
      "Jul",
      "Aug",
      "Sep",
      "Oct",
      "Nov",
      "Dec",
    ];
    return "${d.day.toString().padLeft(2, '0')} ${months[d.month - 1]} ${d.year}";
  }

  Map<String, int> computeTotals(List<Segment> timeline, int seconds) {
    int practice = 0;
    int moving = 0;
    int flagged = 0;
    int paused = 0;

    for (int i = 0; i < timeline.length; i++) {
      final current = timeline[i];

      int end = (i < timeline.length - 1) ? timeline[i + 1].start : seconds;

      int duration = end - current.start;

      if (current.paused) {
        paused += duration;
      } else if (current.moving) {
        moving += duration;
      } else if (current.flagged) {
        flagged += duration;
      } else {
        practice += duration;
      }
    }

    return {
      'practice': practice,
      'moving': moving,
      'flagged': flagged,
      'paused': paused,
    };
  }

  String formatHM(int s) {
    final roundedMinutes = (s / 60).round();

    final h = roundedMinutes ~/ 60;

    final m = roundedMinutes % 60;

    if (h > 0) {
      return "$h h $m m";
    }

    return "$m m";
  }

  String formatDuration(int seconds) {
    final roundedMinutes = (seconds / 60).round();

    final h = roundedMinutes ~/ 60;

    final m = roundedMinutes % 60;

    if (h > 0) {
      return "$h h $m m";
    }

    return "$m m";
  }

  String getWeekLabel(DateTime date) {
    final semesterStart = DateTime(2026, 5, 11);

    final days = date.difference(semesterStart).inDays;

    final week = (days ~/ 7) + 1;

    return "Week $week";
  }

  int computeWeekTotal(List<QueryDocumentSnapshot> docs, String weekLabel) {
    int total = 0;

    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;

      final start = (data['startTime'] as Timestamp).toDate();

      final label = getWeekLabel(start);

      if (label == weekLabel) {
        final duration = data['duration'] ?? 0;

        total += duration as int;
      }
    }

    return total;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Sessions")),
      body: FutureBuilder<String>(
        future: getUid(),
        builder: (context, uidSnapshot) {
          if (!uidSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final currentUid = overrideUid ?? uidSnapshot.data!;

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('sessions')
                .where('uid', isEqualTo: currentUid)
                .orderBy('startTime', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = snapshot.data!.docs;

              return Column(
                children: [
                  FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance
                        .collection('users')
                        .doc(overrideUid ?? uidSnapshot.data!)
                        .get(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const SizedBox();

                      final user =
                          snapshot.data!.data() as Map<String, dynamic>;

                      return Container(
                        width: double.infinity,
                        color: Colors.black,
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user['name'] ?? '',
                              style: const TextStyle(
                                color: gold,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  Expanded(
                    child: ListView(
                      children: docs.map((doc) {
                        final s = doc.data() as Map<String, dynamic>;

                        final rawTimeline = s['timeline'];
                        final rawWaveform = s['waveform'];

                        List<Segment> timelineList = [];
                        List<WavePoint> waveformList = [];

                        if (rawTimeline != null && rawTimeline is List) {
                          timelineList = rawTimeline
                              .where((e) => e != null)
                              .map((e) {
                                final map = e as Map<String, dynamic>;

                                return Segment(
                                  map['start'] ?? 0,
                                  map['moving'] ?? false,

                                  flagged: map['flagged'] ?? false,

                                  paused: map['paused'] ?? false,
                                );
                              })
                              .toList();
                        }

                        if (rawWaveform != null && rawWaveform is List) {
                          waveformList = rawWaveform
                              .where((e) => e != null)
                              .map((e) {
                                final map = e as Map<String, dynamic>;

                                return WavePoint(
                                  map['second'] ?? 0,
                                  (map['amplitude'] ?? 0.0).toDouble(),
                                );
                              })
                              .toList();
                        }

                        final duration = s['duration'] ?? 0;
                        final totals = computeTotals(timelineList, duration);

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,

                          children: [
                            Builder(
                              builder: (_) {
                                final start = (s['startTime'] as Timestamp)
                                    .toDate();

                                final currentWeek = getWeekLabel(start);

                                bool showHeader = false;

                                final currentIndex = docs.indexOf(doc);

                                if (currentIndex == 0) {
                                  showHeader = true;
                                } else {
                                  final previousDoc = docs[currentIndex - 1];

                                  final previousData =
                                      previousDoc.data()
                                          as Map<String, dynamic>;

                                  final previousStart =
                                      (previousData['startTime'] as Timestamp)
                                          .toDate();

                                  final previousWeek = getWeekLabel(
                                    previousStart,
                                  );

                                  showHeader = previousWeek != currentWeek;
                                }

                                if (!showHeader) {
                                  return const SizedBox();
                                }

                                final weekTotal = computeWeekTotal(
                                  docs,
                                  currentWeek,
                                );

                                return Container(
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 8,
                                  ),

                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),

                                  decoration: BoxDecoration(
                                    color: Colors.white,

                                    border: Border.all(
                                      color: Colors.black,
                                      width: 2,
                                    ),

                                    borderRadius: BorderRadius.circular(10),

                                    boxShadow: const [
                                      BoxShadow(
                                        color: Colors.black12,
                                        blurRadius: 3,
                                        offset: Offset(1, 2),
                                      ),
                                    ],
                                  ),

                                  child: Text(
                                    "$currentWeek — "
                                    "Total practice: "
                                    "${formatHM(weekTotal)}",

                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                );
                              },
                            ),

                            Padding(
                              padding: const EdgeInsets.all(10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Builder(
                                    builder: (_) {
                                      final start =
                                          (s['startTime'] as Timestamp)
                                              .toDate();

                                      int h = start.hour % 12;

                                      if (h == 0) h = 12;

                                      final minute = start.minute
                                          .toString()
                                          .padLeft(2, '0');

                                      final suffix = start.hour >= 12
                                          ? "pm"
                                          : "am";

                                      final startLabel = "$h:$minute$suffix";

                                      return Text(
                                        "${s['instrument']} — "
                                        "${formatDate(start)} — "
                                        "$startLabel — "
                                        "${formatDuration(duration)}",
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      );
                                    },
                                  ),

                                  const SizedBox(height: 6),

                                  SizedBox(
                                    height: 84,
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Padding(
                                            padding: const EdgeInsets.only(
                                              left: 2,
                                              right: 2,
                                            ),
                                            child: CustomPaint(
                                              size: Size.infinite,
                                              painter: GraphPainter(
                                                timelineList,
                                                duration,
                                                (s['startTime'] as Timestamp)
                                                    .toDate(),
                                                fixedThreeHourScale: true,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  if (s['instrument'] == 'Other' &&
                                      waveformList.isNotEmpty) ...[
                                    const SizedBox(height: 10),

                                    SizedBox(
                                      height: 84,
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Padding(
                                              padding: const EdgeInsets.only(
                                                left: 2,
                                                right: 2,
                                              ),
                                              child: CustomPaint(
                                                size: Size.infinite,
                                                painter: WaveformPainter(
                                                  waveformList,
                                                  duration,
                                                  fixedThreeHourScale: true,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],

                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,

                                    children: [
                                      Container(
                                        width: 10,
                                        height: 10,
                                        color: Colors.green,
                                      ),

                                      const SizedBox(width: 4),

                                      Text(
                                        formatHM(totals['practice']!),

                                        style: const TextStyle(fontSize: 12),
                                      ),

                                      const SizedBox(width: 14),

                                      Container(
                                        width: 10,
                                        height: 10,
                                        color: gold,
                                      ),

                                      const SizedBox(width: 4),

                                      Text(
                                        formatHM(totals['moving']!),

                                        style: const TextStyle(fontSize: 12),
                                      ),

                                      const SizedBox(width: 14),

                                      Container(
                                        width: 10,
                                        height: 10,
                                        color: Colors.red,
                                      ),

                                      const SizedBox(width: 4),

                                      Text(
                                        formatHM(totals['flagged']!),

                                        style: const TextStyle(fontSize: 12),
                                      ),

                                      const SizedBox(width: 14),

                                      Container(
                                        width: 10,
                                        height: 10,
                                        color: Colors.grey,
                                      ),

                                      const SizedBox(width: 4),

                                      Text(
                                        formatHM(totals['paused']!),

                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
