import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/week_service.dart';
import '../services/firebase_paths.dart';

class OccupancyPage extends StatelessWidget {
  OccupancyPage({super.key});

  final List<String> organs = [
    'Klais',
    'Taylor and Boody',
    'Schlicker',
    'Casavant',
    'Holtkamp',
    'Brombaugh',
  ];

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<WeekInfo?>(
      future: getCurrentWeekInfo(),

      builder: (
        context,
        weekSnapshot,
      ) {
        if (weekSnapshot.connectionState ==
            ConnectionState.waiting) {
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
              "Current Organ Occupancy",
            ),
          ),

          body: FutureBuilder<
            QuerySnapshot
          >(
            future:
                FirebaseFirestore
                    .instance
                    .collection('users')
                    .get(),

            builder: (
              context,
              userSnapshot,
            ) {
              if (userSnapshot
                      .connectionState ==
                  ConnectionState
                      .waiting) {
                return const Center(
                  child:
                      CircularProgressIndicator(),
                );
              }

              final userDocs =
                  userSnapshot
                          .data
                          ?.docs ??
                      [];

              return FutureBuilder<
                List<
                  Map<
                    String,
                    dynamic
                  >
                >
              >(
                future: Future.wait(
                  userDocs.map((
                    userDoc,
                  ) async {
                    final weekDoc =
                        await FirebaseFirestore
                            .instance
                            .collection(
                              'users',
                            )
                            .doc(
                              userDoc.id,
                            )
                            .collection(
                              'weeks',
                            )
                            .doc(
                              week.weekId,
                            )
                            .get();

                    if (!weekDoc
                        .exists) {
                      return {};
                    }

                    final weekData =
                        weekDoc.data()!;

                    final active =
                        weekData['activeSession'] ==
                        true;

                    if (!active) {
                      return {};
                    }

                    final sessionId =
                        weekData['currentSessionId'];

                    if (sessionId ==
                        null) {
                      return {};
                    }

                    final rawSession =
                        await FirebasePaths.sessionDoc(
                          uid:
                              userDoc.id,

                          weekId:
                              week
                                  .weekId,

                          sessionId:
                              sessionId,
                        ).get();

                    if (!rawSession
                        .exists) {
                      return {};
                    }

                    return {
                      'uid':
                          userDoc.id,

                      'week':
                          weekData,

                      'session':
                          rawSession
                              .data(),
                    };
                  }),
                ),

                builder: (
                  context,
                  sessionSnapshot,
                ) {
                  if (sessionSnapshot
                          .connectionState ==
                      ConnectionState
                          .waiting) {
                    return const Center(
                      child:
                          CircularProgressIndicator(),
                    );
                  }

                  final liveSessions =
                      sessionSnapshot
                              .data ??
                          [];

                  final now =
                      DateTime.now();

                  return ListView(
                    children:
                        organs.map((
                          organ,
                        ) {
                          final activeSessions =
                              liveSessions.where((
                                entry,
                              ) {
                                if (entry
                                    .isEmpty) {
                                  return false;
                                }

                                final weekData =
                                    entry['week']
                                        as Map<
                                          String,
                                          dynamic
                                        >;

                                final sessionData =
                                    entry['session']
                                        as Map<
                                          String,
                                          dynamic
                                        >;

                                if (weekData['currentOrgan'] !=
                                    organ) {
                                  return false;
                                }

                                final heartbeat =
                                    weekData['lastHeartbeat'];

                                if (heartbeat ==
                                    null) {
                                  return false;
                                }

                                final heartbeatTime =
                                    (heartbeat
                                            as Timestamp)
                                        .toDate();

                                final stale =
                                    now
                                            .difference(
                                              heartbeatTime,
                                            )
                                            .inMinutes >
                                        5;

                                if (stale) {
                                  return false;
                                }

                                return true;
                              }).toList();

                          final names =
                              activeSessions.map((
                                entry,
                              ) {
                                final sessionData =
                                    entry['session']
                                        as Map<
                                          String,
                                          dynamic
                                        >;

                                return sessionData['name'] ??
                                    'Unknown';
                              }).join(' / ');

                          return Padding(
                            padding:
                                const EdgeInsets.all(
                                  10,
                                ),

                            child: Row(
                              children: [
                                Container(
                                  width:
                                      150,

                                  padding:
                                      const EdgeInsets.symmetric(
                                        vertical:
                                            14,

                                        horizontal:
                                            10,
                                      ),

                                  color:
                                      Colors.black,

                                  child: Text(
                                    organ,

                                    style:
                                        const TextStyle(
                                          color:
                                              Color(
                                                0xFFD4AF37,
                                              ),

                                          fontSize:
                                              16,

                                          fontWeight:
                                              FontWeight.bold,
                                        ),
                                  ),
                                ),

                                Expanded(
                                  child:
                                      Container(
                                        padding:
                                            const EdgeInsets.symmetric(
                                              vertical:
                                                  14,

                                              horizontal:
                                                  10,
                                            ),

                                        color:
                                            () {
                                              if (activeSessions
                                                  .isEmpty) {
                                                return Colors
                                                    .grey
                                                    .shade300;
                                              }

                                              if (activeSessions.length >
                                                  1) {
                                                return Colors
                                                    .red;
                                              }

                                              final sessionData =
                                                  activeSessions.first['session']
                                                      as Map<String, dynamic>;

                                              final timeline =
                                                  sessionData['timeline'];

                                              if (timeline ==
                                                      null ||
                                                  timeline is! List ||
                                                  timeline.isEmpty) {
                                                return Colors.green;
                                              }

                                              final last =
                                                  timeline.last
                                                      as Map<String, dynamic>;

                                              if (last['paused'] ==
                                                  true) {
                                                return Colors.grey;
                                              }

                                              if (last['moving'] ==
                                                  true) {
                                                return const Color(
                                                  0xFFD4AF37,
                                                );
                                              }

                                              return Colors.green;
                                            }(),

                                        child: Text(
                                          activeSessions.isEmpty
                                              ? 'Available'
                                              : names,

                                          style: TextStyle(
                                            color:
                                                activeSessions.isEmpty
                                                ? Colors.black
                                                : Colors.white,

                                            fontSize:
                                                12,

                                            fontWeight:
                                                FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                ),
                              ],
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