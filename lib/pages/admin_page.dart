import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

import '../widgets/admin_header.dart';

import 'occupancy_page.dart';

import 'last_week_overview_page.dart';

import 'conflict_resolution_page.dart';

import 'admin_harmony_progress_page.dart';

import 'admin_tools_page.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'stale_sessions_page.dart';

class AdminPage extends StatelessWidget {
  const AdminPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const AdminHeader(title: "ADMIN"),

            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: Column(
                  mainAxisSize: MainAxisSize.min,

                  children: [
                    const SizedBox(height: 30),

                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: gold,
                        foregroundColor: Colors.black,
                        minimumSize: const Size(260, 50),
                      ),

                      onPressed: () {
                        debugPrint("LAST WEEK BUTTON PRESSED");

                        Navigator.push(
                          context,

                          MaterialPageRoute(
                            builder: (_) => const LastWeekOverviewPage(),
                          ),
                        );
                      },

                      child: const Text("Last Week Overview"),
                    ),

                    const SizedBox(height: 20),

                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: gold,
                        foregroundColor: Colors.black,
                        minimumSize: const Size(260, 50),
                      ),

                      onPressed: () {
                        Navigator.push(
                          context,

                          MaterialPageRoute(builder: (_) => OccupancyPage()),
                        );
                      },

                      child: const Text("Current Organ Occupancy"),
                    ),

                    const SizedBox(height: 20),

                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: gold,
                        foregroundColor: Colors.black,
                        minimumSize: const Size(260, 50),
                      ),

                      onPressed: () {
                        Navigator.push(
                          context,

                          MaterialPageRoute(
                            builder: (_) => const ConflictResolutionPage(),
                          ),
                        );
                      },

                      child: StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('conflicts')
                            .where('resolved', isEqualTo: false)
                            .snapshots(),

                        builder: (context, snapshot) {
                          final count = snapshot.data?.docs.length ?? 0;

                          return Text("Conflict Resolution ($count)");
                        },
                      ),
                    ),

                    const SizedBox(height: 20),

                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: gold,
                        foregroundColor: Colors.black,
                        minimumSize: const Size(260, 50),
                      ),

                      onPressed: () {
                        Navigator.push(
                          context,

                          MaterialPageRoute(
                            builder: (_) => const StaleSessionsPage(),
                          ),
                        );
                      },

                      child: StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('sessions')
                            .snapshots(),

                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const Text("Remove Stale Sessions");
                          }

                          final now = DateTime.now();

                          final staleCount = snapshot.data!.docs.where((d) {
                            final data = d.data() as Map<String, dynamic>;

                            final endTime = data['endTime'];

                            if (endTime != null) {
                              return false;
                            }

                            final heartbeat = data['lastHeartbeat'];

                            if (heartbeat == null) {
                              return true;
                            }

                            final heartbeatTime = (heartbeat as Timestamp)
                                .toDate();

                            return DateTime.now()
                                    .difference(heartbeatTime)
                                    .inMinutes >
                                10;
                          }).length;

                          return Text("Remove Stale Sessions ($staleCount)");
                        },
                      ),
                    ),

                    const SizedBox(height: 20),

                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: gold,
                        foregroundColor: Colors.black,
                        minimumSize: const Size(260, 50),
                      ),

                      onPressed: () {
                        Navigator.push(
                          context,

                          MaterialPageRoute(
                            builder: (_) => const AdminToolsPage(),
                          ),
                        );
                      },

                      child: const Text("Other Tools"),
                    ),

                    const SizedBox(height: 60),

                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: gold,
                        minimumSize: const Size(260, 50),
                      ),

                      onPressed: () {
                        Navigator.push(
                          context,

                          MaterialPageRoute(
                            builder: (_) => const AdminHarmonyProgressPage(),
                          ),
                        );
                      },

                      child: const Text("Update Student Harmony Progress"),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
