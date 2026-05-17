import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../widgets/admin_header.dart';

class OccupancyPage extends StatelessWidget {
  OccupancyPage({super.key});

  static const organs = [
    'Klais',
    'Taylor and Boody',
    'Schlicker',
    'Casavant',
    'Holtkamp',
    'Brombaugh',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const AdminHeader(title: "ADMIN"),

            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('sessions')
                    .where('endTime', isNull: true)
                    .snapshots(),

                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final docs = snapshot.data!.docs;

                  final now = DateTime.now();

                  return ListView(
                    children: organs.map((organ) {
                      final activeSessions = docs.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;

                        if (data['instrument'] != organ) {
                          return false;
                        }

                        final heartbeat = data['lastHeartbeat'];

                        if (heartbeat == null) {
                          return false;
                        }

                        final heartbeatTime = (heartbeat as Timestamp).toDate();

                        return now.difference(heartbeatTime) <
                            const Duration(minutes: 5);
                      }).toList();

                      final names = activeSessions
                          .map((doc) {
                            final data = doc.data() as Map<String, dynamic>;

                            return data['name'] ?? 'Unknown';
                          })
                          .join(' / ');

                      return Padding(
                        padding: const EdgeInsets.all(10),

                        child: Row(
                          children: [
                            Container(
                              width: 150,

                              padding: const EdgeInsets.symmetric(
                                vertical: 14,
                                horizontal: 10,
                              ),

                              color: Colors.black,

                              child: Text(
                                organ,

                                style: const TextStyle(
                                  color: Color(0xFFD4AF37),

                                  fontSize: 16,

                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),

                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                  horizontal: 10,
                                ),

                                color: () {
                                  if (activeSessions.isEmpty) {
                                    return Colors.grey.shade300;
                                  }

                                  if (activeSessions.length > 1) {
                                    return Colors.red;
                                  }

                                  final data =
                                      activeSessions.first.data()
                                          as Map<String, dynamic>;

                                  final timeline = data['timeline'];

                                  if (timeline == null ||
                                      timeline is! List ||
                                      timeline.isEmpty) {
                                    return Colors.green;
                                  }

                                  final last =
                                      timeline.last as Map<String, dynamic>;

                                  if (last['paused'] == true) {
                                    return Colors.grey;
                                  }

                                  if (last['moving'] == true) {
                                    return const Color(0xFFD4AF37);
                                  }

                                  return Colors.green;
                                }(),

                                child: Text(
                                  activeSessions.isEmpty ? 'Available' : names,

                                  style: TextStyle(
                                    color: activeSessions.isEmpty
                                        ? Colors.black
                                        : Colors.white,

                                    fontSize: 12,

                                    fontWeight: FontWeight.bold,
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}
