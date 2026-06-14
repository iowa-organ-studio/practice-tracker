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

import 'selection_page.dart';
import '../login_page.dart';
import 'review_page.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'dart:async';
import 'dart:convert';
import '../services/firebase_paths.dart';
import '../services/week_service.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  static const pendingStopKey = 'pending_stop_upload';

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  StreamSubscription? _staleSubscription;
  int _staleCount = 0;

  @override
  void initState() {
    super.initState();
    retryPendingUpload();
    _initStaleStream();
  }

  Future<void> _initStaleStream() async {
    final week = await getCurrentWeekInfo();
    if (week == null || !mounted) return;

    _staleSubscription = FirebaseFirestore.instance
        .collectionGroup('weeks')
        .where('activeSession', isEqualTo: true)
        .where('weekId', isEqualTo: week.weekId)
        .snapshots()
        .listen((snapshot) {
          final now = DateTime.now();
          int count = 0;

          for (final doc in snapshot.docs) {
            final data = doc.data();
            final heartbeat = data['lastHeartbeat'];

            if (heartbeat == null) {
              count++;
              continue;
            }

            final heartbeatTime = (heartbeat as Timestamp).toDate();
            if (now.difference(heartbeatTime).inMinutes > 10) {
              count++;
            }
          }

          if (mounted) setState(() => _staleCount = count);
        });
  }

  @override
  void dispose() {
    _staleSubscription?.cancel();
    super.dispose();
  }

  Future<void> retryPendingUpload() async {
    final prefs = await SharedPreferences.getInstance();

    final raw = prefs.getString(AdminPage.pendingStopKey);

    if (raw == null) {
      return;
    }

    try {
      final pending = Map<String, dynamic>.from(jsonDecode(raw));

      await FirebasePaths.sessionDoc(
        uid: pending['uid'],

        weekId: pending['weekId'],

        sessionId: pending['sessionId'],
      ).update({
        'duration': pending['duration'],

        'timeline': pending['timeline'],

        'waveform': pending['waveform'],

        'endTime': DateTime.parse(pending['endTime']),

        'endedOffline': true,
      });

      await prefs.remove(AdminPage.pendingStopKey);
    } catch (e) {
      debugPrint("Pending upload retry failed: $e");
    }
  }

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
                child: SingleChildScrollView(
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

                        child: Text(
                          _staleCount > 0
                              ? "Remove Stale Sessions ($_staleCount)"
                              : "Remove Stale Sessions",
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

                      const SizedBox(height: 20),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,

                        children: [
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.indigo,
                              foregroundColor: Colors.white,
                            ),

                            onPressed: () {
                              Navigator.push(
                                context,

                                MaterialPageRoute(
                                  builder: (_) =>
                                      const SelectionPage(adminMode: true),
                                ),
                              );
                            },

                            child: const Text("Start Practice"),
                          ),

                          const SizedBox(width: 16),

                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.indigo,
                            ),

                            onPressed: () {
                              Navigator.push(
                                context,

                                MaterialPageRoute(
                                  builder: (_) => const ReviewPage(),
                                ),
                              );
                            },

                            child: const Text("Review Sessions"),
                          ),
                        ],
                      ),

                      const SizedBox(height: 30),

                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(260, 50),
                        ),

                        onPressed: () async {
                          final prefs = await SharedPreferences.getInstance();

                          final uid = prefs.getString('uid');

                          if (uid != null) {
                            await FirebaseFirestore.instance
                                .collection('users')
                                .doc(uid)
                                .update({
                                  'activeDeviceId': null,
                                  'lastDeviceHeartbeat': null,
                                });
                          }

                          await prefs.clear();

                          if (!mounted) return;

                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const LoginPage(),
                            ),
                            (route) => false,
                          );
                        },

                        child: const Text("LOGOUT"),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}