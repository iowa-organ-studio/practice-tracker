import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/week_service.dart';
import '../services/firebase_paths.dart';

class OccupancyPage extends StatefulWidget {
  const OccupancyPage({super.key});

  @override
  State<OccupancyPage> createState() => _OccupancyPageState();
}

class _OccupancyPageState extends State<OccupancyPage> {
  final List<String> organs = [
    'Klais',
    'Taylor and Boody',
    'Schlicker',
    'Casavant',
    'Holtkamp',
    'Brombaugh',
  ];

  StreamSubscription? _weekSubscription;
  List<Map<String, dynamic>> _liveSessions = [];
  WeekInfo? _week;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final week = await getCurrentWeekInfo();

    if (!mounted) return;

    if (week == null) {
      setState(() => _loading = false);
      return;
    }

    setState(() => _week = week);

    // Real-time listener on active weeks — same index as overlap watcher.
    // Fires once on open, then again whenever any session starts/stops/changes.
    _weekSubscription = FirebaseFirestore.instance
        .collectionGroup('weeks')
        .where('activeSession', isEqualTo: true)
        .where('weekId', isEqualTo: week.weekId)
        .snapshots()
        .listen((snapshot) async {
          final now = DateTime.now();

          // For each active week doc, fetch the current session to get
          // name and timeline (needed for paused/moving color).
          final results = await Future.wait(
            snapshot.docs.map((weekDoc) async {
              final weekData = weekDoc.data();

              final heartbeat = weekData['lastHeartbeat'];
              if (heartbeat == null) return null;

              final heartbeatTime = (heartbeat as Timestamp).toDate();
              if (now.difference(heartbeatTime).inMinutes > 5) return null;

              final sessionId = weekData['currentSessionId'];
              if (sessionId == null) return null;

              final uid = weekDoc.reference.parent.parent!.id;

              final sessionDoc = await FirebasePaths.sessionDoc(
                uid: uid,
                weekId: week.weekId,
                sessionId: sessionId,
              ).get();

              if (!sessionDoc.exists) return null;

              return {
                'uid': uid,
                'week': weekData,
                'session': sessionDoc.data(),
              };
            }),
          );

          if (!mounted) return;

          setState(() {
            _liveSessions =
                results.whereType<Map<String, dynamic>>().toList();
            _loading = false;
          });
        });
  }

  @override
  void dispose() {
    _weekSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_week == null) {
      return const Scaffold(
        body: Center(child: Text('No active week')),
      );
    }

    final now = DateTime.now();

    return Scaffold(
      appBar: AppBar(title: const Text('Current Organ Occupancy')),
      body: ListView(
        children: organs.map((organ) {
          final activeSessions = _liveSessions.where((entry) {
            final weekData = entry['week'] as Map<String, dynamic>;
            return weekData['currentOrgan'] == organ;
          }).toList();

          final names = activeSessions.map((entry) {
            final sessionData = entry['session'] as Map<String, dynamic>;
            return sessionData['name'] ?? 'Unknown';
          }).join(' / ');

          final color = () {
            if (activeSessions.isEmpty) return Colors.grey.shade300;
            if (activeSessions.length > 1) return Colors.red;

            final sessionData =
                activeSessions.first['session'] as Map<String, dynamic>;
            final timeline = sessionData['timeline'];

            if (timeline == null || timeline is! List || timeline.isEmpty) {
              return Colors.green;
            }

            final last = timeline.last as Map<String, dynamic>;

            if (last['paused'] == true) return Colors.grey;
            if (last['moving'] == true) return const Color(0xFFD4AF37);

            return Colors.green;
          }();

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
                    color: color,
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
      ),
    );
  }
}