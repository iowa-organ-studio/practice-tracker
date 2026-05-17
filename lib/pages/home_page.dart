import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/user_service.dart';

import 'selection_page.dart';
import 'review_page.dart';

import '../theme/app_colors.dart';

import '../services/semester_service.dart';
import '../models/week_status.dart';
import '../widgets/semester_card.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Timer? deviceHeartbeatTimer;
  int minimumWeeklyMinutes = 0;

  List<WeekStatus> semesterStatuses = [];

  Future<void> loadSemesterStatuses() async {
    final semester = await getActiveSemester();

    if (semester == null) {
      return;
    }

    final uid = await getUid();

    final minimumMinutes = await getMinimumWeeklyMinutes();

    setState(() {
      minimumWeeklyMinutes = minimumMinutes;
    });

    List<WeekStatus> loadedStatuses = [];

    for (final week in semester.weeks) {
      final minutes = await getPracticeMinutesForWeek(uid: uid, week: week);

      final now = DateTime.now();

      final isCurrentWeek = now.isAfter(week.start) && now.isBefore(week.end);

      final status = computeWeekStatus(
        week: week,
        practicedMinutes: minutes,
        minimumMinutes: minimumMinutes,
        isCurrentWeek: isCurrentWeek,
        isTopPracticer: false,
      );

      loadedStatuses.add(status);
    }

    setState(() {
      semesterStatuses = loadedStatuses;
    });
  }

  Future<int> getThisWeekMinutes() async {
    final semester = await getActiveSemester();

    if (semester == null) return 0;

    final uid = await getUid();

    final now = DateTime.now();

    final currentWeek = semester.weeks.firstWhere(
      (w) => now.isAfter(w.start) && now.isBefore(w.end),
    );

    return await getPracticeMinutesForWeek(uid: uid, week: currentWeek);
  }

  String formatHM(int minutes) {
    final h = minutes ~/ 60;

    final m = minutes % 60;

    return "${h} h ${m} m";
  }

  Future<void> sendDeviceHeartbeat() async {
    final prefs = await SharedPreferences.getInstance();

    final uid = prefs.getString('uid');

    if (uid == null) return;

    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'lastDeviceHeartbeat': DateTime.now(),
      });
    } catch (e) {
      debugPrint("Device heartbeat failed: $e");
    }
  }

  @override
  void initState() {
    super.initState();

    loadSemesterStatuses();

    deviceHeartbeatTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      sendDeviceHeartbeat();
    });
  }

  @override
  void dispose() {
    deviceHeartbeatTimer?.cancel();
    super.dispose();
  }

  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            FutureBuilder<Map<String, String>>(
              future: getUserInfo(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const SizedBox();
                }

                final user = snapshot.data!;

                return FutureBuilder<int>(
                  future: getThisWeekMinutes(),

                  builder: (context, minuteSnapshot) {
                    final weekMinutes = minuteSnapshot.data ?? 0;

                    final now = DateTime.now();

                    final elapsedWeekDays = now.weekday;

                    final weekDailyAverage = (weekMinutes / elapsedWeekDays)
                        .round();

                    final semesterDailyAverage = weekDailyAverage;

                    return Container(
                      width: double.infinity,

                      color: Colors.black,

                      padding: const EdgeInsets.all(12),

                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,

                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,

                            children: [
                              Text(
                                user['name'] ?? '',

                                style: const TextStyle(
                                  color: gold,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),

                              Text(
                                "Weekly Minimum: "
                                "${minimumWeeklyMinutes ~/ 60} h",

                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 14),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,

                            children: const [
                              Text(
                                "This week\n total",

                                textAlign: TextAlign.center,

                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                ),
                              ),

                              Text(
                                "This week\n daily avg",

                                textAlign: TextAlign.center,

                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                ),
                              ),

                              Text(
                                "Semester\n daily avg",

                                textAlign: TextAlign.center,

                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 6),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,

                            children: [
                              Text(
                                formatHM(weekMinutes),

                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),

                              Text(
                                formatHM(weekDailyAverage),

                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),

                              Text(
                                formatHM(semesterDailyAverage),

                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),

            const SizedBox(height: 24),

            const Text(
              "Hawkeye Organist Practice App",
              style: TextStyle(fontSize: 22),
            ),

            if (semesterStatuses.isNotEmpty)
              SemesterCard(title: "Summer 2026", statuses: semesterStatuses),

            const SizedBox(height: 24),

            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: gold,
                foregroundColor: Colors.black,
              ),
              child: const Text("Start Practice"),
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SelectionPage(),
                  ),
                );
              },
            ),

            ElevatedButton(
              child: const Text("Review Sessions"),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ReviewPage()),
                );
              },
            ),

            const Spacer(),

            SvgPicture.asset(
              'assets/Organ-Studio-LockupStacked-RGB.svg',
              height: 135,
            ),
          ],
        ),
      ),
    );
  }
}
