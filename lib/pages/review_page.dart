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
  const ReviewPage({super.key});

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

    for (int i = 0; i < timeline.length; i++) {
      final current = timeline[i];

      int end = (i < timeline.length - 1) ? timeline[i + 1].start : seconds;

      int duration = end - current.start;

      if (current.moving) {
        moving += duration;
      } else if (current.flagged) {
        flagged += duration;
      } else {
        practice += duration;
      }
    }

    return {'practice': practice, 'moving': moving, 'flagged': flagged};
  }

  String formatHM(int s) {
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    final sec = s % 60;

    if (h > 0) {
      return "$h h $m m $sec s";
    }

    return "$m m $sec s";
  }

  String formatDuration(int seconds) {
    final m = (seconds ~/ 60);
    final s = (seconds % 60).toString().padLeft(2, '0');
    return "$m:$s";
  }

  String getWeekLabel(DateTime date) {
    final semesterStart = DateTime(2026, 5, 11);

    final days = date.difference(semesterStart).inDays;

    final week = (days ~/ 7) + 1;

    return "Week $week";
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

          final currentUid = uidSnapshot.data!;

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
                  FutureBuilder<Map<String, String>>(
                    future: getUserInfo(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const SizedBox();

                      final user = snapshot.data!;

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

                                return Padding(
                                  padding: const EdgeInsets.only(
                                    left: 12,
                                    top: 18,
                                    bottom: 6,
                                  ),

                                  child: Text(
                                    currentWeek,

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

                                  Text(
                                    "Practice: ${formatHM(totals['practice']!)}"
                                    "     Moving: ${formatHM(totals['moving']!)}"
                                    "     Flagged: ${formatHM(totals['flagged']!)}",

                                    style: const TextStyle(fontSize: 12),
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
