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

    final suffix =
        d.hour >= 12
        ? 'pm'
        : 'am';

    return "${d.day} "
        "${months[d.month - 1]} "
        "${d.year} "
        "$h:$m$suffix";
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<WeekInfo?>(
      future: getCurrentWeekInfo(),

      builder: (
        context,
        weekSnapshot,
      ) {
        if (!weekSnapshot
            .hasData) {
          return const Scaffold(
            body: Center(
              child:
                  CircularProgressIndicator(),
            ),
          );
        }

        final week =
            weekSnapshot.data;

        if (week == null) {
          return const Scaffold(
            body: Center(
              child: Text(
                "No active week",
              ),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text(
              "Stale Sessions",
            ),
          ),

          body: StreamBuilder<
            QuerySnapshot
          >(
            stream:
                FirebaseFirestore
                    .instance
                    .collectionGroup(
                      'weeks',
                    )
                    .where(
                      'weekId',
                      isEqualTo:
                          week.weekId,
                    )
                    .snapshots(),

            builder: (
              context,
              snapshot,
            ) {
              if (!snapshot
                  .hasData) {
                return const Center(
                  child:
                      CircularProgressIndicator(),
                );
              }

              final now =
                  DateTime.now();

              final staleCusps =
                  snapshot.data!.docs.where((
                    doc,
                  ) {
                    final data =
                        doc.data()
                            as Map<
                              String,
                              dynamic
                            >;

                    final active =
                        data['activeSession'] ==
                        true;

                    if (!active) {
                      return false;
                    }

                    final heartbeat =
                        data['lastHeartbeat'];

                    if (heartbeat ==
                        null) {
                      return true;
                    }

                    final heartbeatTime =
                        (heartbeat
                                as Timestamp)
                            .toDate();

                    return now
                            .difference(
                              heartbeatTime,
                            )
                            .inMinutes >
                        10;
                  }).toList();

              if (staleCusps
                  .isEmpty) {
                return const Center(
                  child: Text(
                    "No stale sessions",
                  ),
                );
              }

              return ListView(
                children:
                    staleCusps.map((
                      cusp,
                    ) {
                      final data =
                          cusp.data()
                              as Map<
                                String,
                                dynamic
                              >;

                      final uid =
                          cusp
                              .reference
                              .parent
                              .parent!
                              .id;

                      final sessionId =
                          data['currentSessionId'];

                      final start =
                          (data['lastHeartbeat']
                                  as Timestamp)
                              .toDate();

                      final heartbeat =
                          (data['lastHeartbeat']
                                  as Timestamp)
                              .toDate();

                      return FutureBuilder<
                        DocumentSnapshot
                      >(
                        future:
                            FirebasePaths.sessionDoc(
                              uid: uid,

                              weekId:
                                  week
                                      .weekId,

                              sessionId:
                                  sessionId,
                            ).get(),

                        builder: (
                          context,
                          sessionSnapshot,
                        ) {
                          if (!sessionSnapshot
                              .hasData) {
                            return const SizedBox();
                          }

                          if (!sessionSnapshot
                              .data!
                              .exists) {
                            return const SizedBox();
                          }

                          final session =
                              sessionSnapshot
                                      .data!
                                      .data()
                                  as Map<
                                    String,
                                    dynamic
                                  >;

                          return Card(
                            margin:
                                const EdgeInsets.all(
                                  12,
                                ),

                            child: Padding(
                              padding:
                                  const EdgeInsets.all(
                                    14,
                                  ),

                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment
                                        .start,

                                children: [
                                  Text(
                                    "${session['name']} — ${session['instrument']}",

                                    style:
                                        const TextStyle(
                                          fontSize:
                                              18,

                                          fontWeight:
                                              FontWeight.bold,
                                        ),
                                  ),

                                  const SizedBox(
                                    height:
                                        8,
                                  ),

                                  Text(
                                    "Started: ${formatDateTime(start)}",
                                  ),

                                  const SizedBox(
                                    height:
                                        4,
                                  ),

                                  Text(
                                    "Last heartbeat: ${formatDateTime(heartbeat)}",
                                  ),

                                  const SizedBox(
                                    height:
                                        4,
                                  ),

                                  Text(
                                    "Firebase document ID: $sessionId",

                                    style:
                                        const TextStyle(
                                          fontSize:
                                              12,

                                          color:
                                              Colors.grey,
                                        ),
                                  ),

                                  const SizedBox(
                                    height:
                                        14,
                                  ),

                                  StaleSessionActions(
                                    uid:
                                        uid,

                                    weekId:
                                        week
                                            .weekId,

                                    sessionId:
                                        sessionId,

                                    initialEndTime:
                                        heartbeat,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    }).toList(),
              );
            },
          ),
        );
      },
    );
  }
}

class StaleSessionActions
    extends StatefulWidget {
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
  State<StaleSessionActions>
  createState() =>
      _StaleSessionActionsState();
}

class _StaleSessionActionsState
    extends State<
      StaleSessionActions
    > {
  final TextEditingController
  controller =
      TextEditingController();

  @override
  void initState() {
    super.initState();

    controller.text =
        DateFormat(
          'yyyy-MM-dd HH:mm',
        ).format(
          widget.initialEndTime,
        );
  }

  Future<void> createEndTime()
  async {
    try {
      final parsed =
          DateFormat(
            'yyyy-MM-dd HH:mm',
          ).parse(
            controller.text,
          );

      await FirebasePaths
          .sessionDoc(
            uid: widget.uid,

            weekId:
                widget.weekId,

            sessionId:
                widget.sessionId,
          )
          .update({
            'endTime':
                parsed,
          });

      await FirebasePaths
          .weekDoc(
            uid: widget.uid,

            weekId:
                widget.weekId,
          )
          .update({
            'activeSession':
                false,

            'currentOrgan':
                null,

            'currentSessionId':
                null,
          });

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        const SnackBar(
          content: Text(
            "End Time added to session",
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        const SnackBar(
          content: Text(
            "Invalid date format",
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller:
              controller,

          decoration:
              const InputDecoration(
                labelText:
                    'Create end time',

                hintText:
                    'yyyy-MM-dd HH:mm',
              ),
        ),

        const SizedBox(
          height: 12,
        ),

        ElevatedButton(
          onPressed:
              createEndTime,

          child: const Text(
            "Create End Time",
          ),
        ),
      ],
    );
  }
}