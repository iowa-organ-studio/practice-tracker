import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'practice_page.dart';
import '../theme/app_colors.dart';
import '../services/week_service.dart';

class SelectionPage extends StatelessWidget {
  final bool adminMode;

  const SelectionPage({super.key, this.adminMode = false});

  final List<String> builders = const [
    'Klais',
    'Taylor and Boody',
    'Schlicker',
    'Casavant',
    'Holtkamp',
    'Brombaugh',
    'Other',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<WeekInfo?>(
        future: getCurrentWeekInfo(),

        builder: (context, weekSnapshot) {
          if (weekSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final week = weekSnapshot.data;

          if (week == null) {
            return const Center(child: Text("No active week found"));
          }

          return StreamBuilder<QuerySnapshot>(
            // Same collectionGroup index used by the overlap watcher —
            // no extra index needed. Firestore pushes an update the moment
            // any student's activeSession or heartbeat changes.
            stream: FirebaseFirestore.instance
                .collectionGroup('weeks')
                .where('activeSession', isEqualTo: true)
                .where('weekId', isEqualTo: week.weekId)
                .snapshots(),

            builder: (context, cuspSnapshot) {
              if (!cuspSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final cusps = cuspSnapshot.data!.docs
                  .map((d) => d.data() as Map<String, dynamic>)
                  .toList();

                  final now = DateTime.now();

                  final activeCusps = cusps.where((data) {
                    final active = data['activeSession'] == true;

                    if (!active) {
                      return false;
                    }

                    final heartbeat = data['lastHeartbeat'];

                    if (heartbeat == null) {
                      return false;
                    }

                    final heartbeatTime = (heartbeat as Timestamp).toDate();

                    return now.difference(heartbeatTime).inMinutes < 5;
                  }).toList();

                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,

                      children: builders.map((b) {
                        bool inUse = false;

                        if (b != 'Other') {
                          inUse = activeCusps.any((data) {
                            return data['currentOrgan'] == b;
                          });
                        }

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),

                          child: GestureDetector(
                            onTap: () async {
                              if (inUse) {
                                final result = await showDialog<bool>(
                                  context: context,

                                  builder: (_) {
                                    return AlertDialog(
                                      title: const Text("Organ In Use"),

                                      content: const Text(
                                        "This organ appears to be in use.\n\nStart session anyway?",
                                      ),

                                      actions: [
                                        TextButton(
                                          onPressed: () {
                                            Navigator.pop(context, false);
                                          },

                                          child: const Text("No"),
                                        ),

                                        TextButton(
                                          onPressed: () {
                                            Navigator.pop(context, true);
                                          },

                                          child: const Text("Yes"),
                                        ),
                                      ],
                                    );
                                  },
                                );

                                if (result != true) {
                                  return;
                                }
                              }

                              await Navigator.pushReplacement(
                                context,

                                MaterialPageRoute(
                                  builder: (_) => PracticePage(
                                    instrument: b,

                                    initiatedOverlap: inUse,

                                    adminMode: adminMode,
                                  ),
                                ),
                              );
                            },

                            child: Opacity(
                              opacity: inUse ? 0.4 : 1.0,

                              child: Container(
                                width: 220,

                                padding: const EdgeInsets.all(14),

                                alignment: Alignment.center,

                                decoration: BoxDecoration(
                                  color: b == 'Other'
                                      ? const Color(0xFFFFE680)
                                      : inUse
                                      ? Colors.grey
                                      : gold,

                                  border: Border.all(
                                    color: Colors.black,

                                    width: 2,
                                  ),
                                ),

                                child: Text(
                                  inUse ? "$b (in use)" : b,

                                  style: const TextStyle(color: Colors.black),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  );
            },
          );
        },
      ),
    );
  }
}