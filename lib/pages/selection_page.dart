import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'practice_page.dart';

import '../theme/app_colors.dart';

class SelectionPage extends StatelessWidget {
  const SelectionPage({super.key});

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
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('sessions')
            .where('endTime', isNull: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final now = DateTime.now();

          final activeSessions = snapshot.data!.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;

            final heartbeat = data['lastHeartbeat'];

            if (heartbeat == null) {
              return true;
            }

            final heartbeatTime = (heartbeat as Timestamp).toDate();

            return now.difference(heartbeatTime) < const Duration(minutes: 5);
          }).toList();

          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: builders.map((b) {
                bool inUse = false;

                if (b != 'Other') {
                  inUse = activeSessions.any((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return data['instrument'] == b;
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
                          border: Border.all(color: Colors.black, width: 2),
                        ),
                        child: Text(
                          inUse ? "$b (in use)" : b,
                          style: TextStyle(color: Colors.black),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          );
        },
      ),
    );
  }
}

