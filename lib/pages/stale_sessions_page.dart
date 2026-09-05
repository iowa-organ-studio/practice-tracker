import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../services/week_service.dart';
import '../services/firebase_paths.dart';

class StaleSessionsPage extends StatelessWidget {
  const StaleSessionsPage({super.key});

  String formatDateTime(DateTime d) {
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

    int h = d.hour % 12;

    if (h == 0) h = 12;

    final m = d.minute.toString().padLeft(2, '0');

    final suffix = d.hour >= 12 ? 'pm' : 'am';

    return "${d.day} "
        "${months[d.month - 1]} "
        "${d.year} "
        "$h:$m$suffix";
  }

    @override
  Widget build(BuildContext context) {
    return FutureBuilder<WeekInfo?>(
      future: getCurrentWeekInfo(),
      builder: (context, weekSnapshot) {
        if (!weekSnapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final week = weekSnapshot.data;

        if (week == null) {
          return const Scaffold(
            body: Center(child: Text("No active week")),
          );
        }

        return Scaffold(
          appBar: AppBar(title: const Text("Stale Sessions")),
          body: FutureBuilder<QuerySnapshot>(
            future: FirebaseFirestore.instance.collection('users').get(),
            builder: (context, userSnapshot) {
              if (userSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final userDocs = userSnapshot.data?.docs ?? [];

              return FutureBuilder<List<List<Map<String, dynamic>>>>(
                future: Future.wait(
                  userDocs.map((userDoc) async {
                    final weekDoc = await FirebaseFirestore.instance
                        .collection('users')
                        .doc(userDoc.id)
                        .collection('weeks')
                        .doc(week.weekId)
                        .get();

                    if (!weekDoc.exists) {
                      return <Map<String, dynamic>>[];
                    }

                    final weekData = weekDoc.data();

                    if (weekData == null) {
                      return <Map<String, dynamic>>[];
                    }

                    final active = weekData['activeSession'] == true;

                    final heartbeat = weekData['lastHeartbeat'];

                    bool staleEnough = !active;

                    if (active) {
                      if (heartbeat == null) {
                        staleEnough = true;
                      } else {
                        final heartbeatTime =
                            (heartbeat as Timestamp).toDate();

                        staleEnough =
                            DateTime.now().difference(heartbeatTime).inMinutes >
                                10;
                      }
                    }

                    if (!staleEnough) {
                      return <Map<String, dynamic>>[];
                    }

                    final sessionsSnapshot =
                        await FirebasePaths.sessionsCollection(
                      uid: userDoc.id,
                      weekId: week.weekId,
                    ).get();

                    final incompleteSessions =
                        <Map<String, dynamic>>[];

                    for (final sessionDoc in sessionsSnapshot.docs) {
                      final sessionData = sessionDoc.data();

                      if (sessionData['endTime'] != null) {
                        continue;
                      }

                      if (sessionData['staleReviewed'] == true) {
                        continue;
                      }

                      incompleteSessions.add({
                        'uid': userDoc.id,
                        'week': weekData,
                        'sessionId': sessionDoc.id,
                        'session': sessionData,
                      });
                    }

                    return incompleteSessions;
                  }),
                ),
                builder: (context, staleSnapshot) {
                  if (staleSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  final nestedResults =
                      staleSnapshot.data ??
                      <List<Map<String, dynamic>>>[];

                  final staleSessions = <Map<String, dynamic>>[];

                  for (final userResults in nestedResults) {
                    staleSessions.addAll(userResults);
                  }

                  if (staleSessions.isEmpty) {
                    return const Center(
                      child: Text("No stale sessions"),
                    );
                  }

                  staleSessions.sort((a, b) {
                    final aStart =
                        (a['session']['startTime'] as Timestamp).toDate();

                    final bStart =
                        (b['session']['startTime'] as Timestamp).toDate();

                    return aStart.compareTo(bStart);
                  });

                  return ListView(
                    children: staleSessions.map((entry) {
                      final uid = entry['uid'] as String;

                      final session =
                          entry['session'] as Map<String, dynamic>;

                      final sessionId = entry['sessionId'] as String;

                      final weekData =
                          entry['week'] as Map<String, dynamic>;

                      final start =
                          (session['startTime'] as Timestamp).toDate();

                      final heartbeatValue = weekData['lastHeartbeat'];

                      DateTime initialEndTime;

                      if (heartbeatValue != null) {
                        initialEndTime =
                            (heartbeatValue as Timestamp).toDate();
                      } else {
                        initialEndTime = start;
                      }

                      final studentReported =
                          session['studentReportedEndTime'];

                      return Card(
                        margin: const EdgeInsets.all(12),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                "${session['name']} — "
                                "${session['instrument']}",
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),

                              const SizedBox(height: 8),

                              Text(
                                "Started: ${formatDateTime(start)}",
                              ),

                              const SizedBox(height: 4),

                              if (heartbeatValue != null)
                                Text(
                                  "Last heartbeat: "
                                  "${formatDateTime(initialEndTime)}",
                                )
                              else
                                const Text(
                                  "Last heartbeat: none",
                                ),

                              if (studentReported != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    "Student reported: "
                                    "${formatDateTime(
                                      (studentReported as Timestamp)
                                          .toDate(),
                                    )}",
                                  ),
                                ),

                              const SizedBox(height: 14),

                              StaleSessionActions(
                                uid: uid,
                                weekId: week.weekId,
                                sessionId: sessionId,
                                initialEndTime: initialEndTime,
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}


class StaleSessionActions extends StatefulWidget {
  final String uid;

  final String weekId;

  final String sessionId;

  final DateTime initialEndTime;

  const StaleSessionActions({
    super.key,
    required this.uid,
    required this.weekId,
    required this.sessionId,
    required this.initialEndTime,
  });

  @override
  State<StaleSessionActions> createState() => _StaleSessionActionsState();
}

class _StaleSessionActionsState extends State<StaleSessionActions> {
  final TextEditingController controller = TextEditingController();

  @override
  void initState() {
    super.initState();

    controller.text = DateFormat(
      'yyyy-MM-dd HH:mm',
    ).format(widget.initialEndTime);
  }

  Future<void> createEndTime() async {
    try {
      final parsed =
          DateFormat('yyyy-MM-dd HH:mm').parse(controller.text);

      final session = await FirebasePaths.sessionDoc(
        uid: widget.uid,
        weekId: widget.weekId,
        sessionId: widget.sessionId,
      ).get();

      final data = session.data()!;

      final startTime =
          (data['startTime'] as Timestamp).toDate();

      final inferredDuration =
          parsed.difference(startTime).inSeconds;

      if (inferredDuration < 0) {
        throw Exception("End time before start time");
      }

      await FirebasePaths.sessionDoc(
        uid: widget.uid,
        weekId: widget.weekId,
        sessionId: widget.sessionId,
      ).update({
        'endTime': parsed,
        'duration': inferredDuration,
        'staleReviewed': true,
      });

      await FirebasePaths.weekDoc(
        uid: widget.uid,
        weekId: widget.weekId,
      ).update({
        'activeSession': false,
        'currentOrgan': null,
        'currentSessionId': null,
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("End Time added to session"),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Invalid end time"),
        ),
      );
    }
  }

  Future<void> assignAdminEndTime() async {
    try {
      final session = await FirebasePaths.sessionDoc(
        uid: widget.uid,
        weekId: widget.weekId,
        sessionId: widget.sessionId,
      ).get();

      if (!session.exists) {
        return;
      }

      final data = session.data()!;

      final startTime =
          (data['startTime'] as Timestamp).toDate();

      final reported = data['studentReportedEndTime'];

      DateTime initialDateTime = widget.initialEndTime;

      if (reported != null) {
        initialDateTime =
            (reported as Timestamp).toDate();
      }

      if (initialDateTime.isBefore(startTime)) {
        initialDateTime = startTime;
      }

      final now = DateTime.now();

      if (initialDateTime.isAfter(now)) {
        initialDateTime = now;
      }

      if (!mounted) return;

      final selectedDate = await showDatePicker(
        context: context,
        initialDate: DateTime(
          initialDateTime.year,
          initialDateTime.month,
          initialDateTime.day,
        ),
        firstDate: DateTime(
          startTime.year,
          startTime.month,
          startTime.day,
        ),
        lastDate: DateTime(
          now.year,
          now.month,
          now.day,
        ),
      );

      if (selectedDate == null) {
        return;
      }

      if (!mounted) return;

      final selectedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(initialDateTime),
      );

      if (selectedTime == null) {
        return;
      }

      final assignedEndTime = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        selectedTime.hour,
        selectedTime.minute,
      );

      if (assignedEndTime.isBefore(startTime)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("End time cannot be before start time"),
          ),
        );
        return;
      }

      controller.text = DateFormat(
        'yyyy-MM-dd HH:mm',
      ).format(assignedEndTime);

      await createEndTime();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Could not assign end time"),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Create end time',
            hintText: 'yyyy-MM-dd HH:mm',
          ),
        ),

        const SizedBox(height: 12),

        Column(
          children: [
            ElevatedButton(
              onPressed: createEndTime,
              child: const Text("Use Last Recorded"),
            ),

            const SizedBox(height: 10),

            ElevatedButton(
              onPressed: () async {
                final session = await FirebasePaths.sessionDoc(
                  uid: widget.uid,
                  weekId: widget.weekId,
                  sessionId: widget.sessionId,
                ).get();

                final data = session.data()!;

                final reported =
                    data['studentReportedEndTime'];

                if (reported == null) {
                  if (!mounted) {
                    return;
                  }

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content:
                          Text("No student-reported ending time"),
                    ),
                  );

                  return;
                }

                final startTime =
                    (data['startTime'] as Timestamp).toDate();

                final reportedEnd =
                    (reported as Timestamp).toDate();

                final duration =
                    reportedEnd.difference(startTime).inSeconds;

                if (duration < 0) {
                  if (!mounted) {
                    return;
                  }

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content:
                          Text("Student-reported ending time is invalid"),
                    ),
                  );

                  return;
                }

                await FirebasePaths.sessionDoc(
                  uid: widget.uid,
                  weekId: widget.weekId,
                  sessionId: widget.sessionId,
                ).update({
                  'endTime': reportedEnd,
                  'duration': duration,
                  'staleReviewed': true,
                });

                await FirebasePaths.weekDoc(
                  uid: widget.uid,
                  weekId: widget.weekId,
                ).update({
                  'activeSession': false,
                  'currentOrgan': null,
                  'currentSessionId': null,
                });

                if (!mounted) {
                  return;
                }

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content:
                        Text("Student-reported ending time applied"),
                  ),
                );
              },
              child: const Text("Use Student Reported"),
            ),

            const SizedBox(height: 10),

            ElevatedButton(
              onPressed: assignAdminEndTime,
              child: const Text("ADMIN assign end time"),
            ),
          ],
        ),
      ],
    );
  }
}