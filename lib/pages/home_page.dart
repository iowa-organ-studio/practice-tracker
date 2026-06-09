import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/user_service.dart';
import '../login_page.dart';
import 'selection_page.dart';
import 'review_page.dart';
import '../theme/app_colors.dart';
import '../services/semester_service.dart';
import '../models/week_status.dart';
import '../widgets/semester_card.dart';
import '../widgets/harmony_progress_card.dart';
import 'dart:convert';
import '../services/cusp_service.dart';
import '../services/firebase_paths.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Timer? deviceHeartbeatTimer;
  int minimumWeeklyMinutes = 0;

  List<WeekStatus> semesterStatuses = [];
  static const pendingStopKey = 'pending_stop_upload';
  String semesterTitle = "Semester";
  bool vacationMode = false;
  bool uploadPending = false;
  Future<void> loadSemesterStatuses() async {
    final semester = await getActiveSemester();

    if (semester == null) {
      setState(() {
        vacationMode = true;
      });

      return;
    }

    setState(() {
      semesterTitle = "${semester.name} Practice";

      vacationMode = false;
    });

    final uid = await getUid();

    final minimumMinutes = await getMinimumWeeklyMinutes();

    setState(() {
      minimumWeeklyMinutes = minimumMinutes;
    });

    List<WeekStatus> loadedStatuses = [];

    final now = DateTime.now();

    for (final week in semester.weeks) {
      String? topUid;

      if (now.isAfter(week.end)) {
        topUid = await getTopPracticerUidForWeek(week: week);
      }
      final seconds = await getWeekPracticeTotal(
  uid: uid,
  weekId: week.weekId,
);

      final isCurrentWeek = now.isAfter(week.start) && now.isBefore(week.end);

      final status = computeWeekStatus(
        week: week,
        practicedSeconds: seconds,
        minimumMinutes: minimumMinutes,
        isCurrentWeek: isCurrentWeek,
        isTopPracticer: uid == topUid,
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

    return await getWeekPracticeTotal(uid: uid, weekId: currentWeek.weekId);
  }

  Future<int> getSemesterDailyAverage() async {
    final semester = await getActiveSemester();

    if (semester == null) return 0;

    final uid = await getUid();

    final now = DateTime.now();

    int totalSemesterMinutes = 0;

    for (final week in semester.weeks) {
      if (now.isAfter(week.start)) {
        totalSemesterMinutes += await getWeekPracticeTotal(
          uid: uid,
          weekId: week.weekId,
        );
      }
    }

    final today = DateTime(now.year, now.month, now.day);

    final semesterStart = semester.weeks.first.start;

    final elapsedDays = today.difference(semesterStart).inDays;

    final safeDays = elapsedDays <= 0 ? 1 : elapsedDays;

    return (totalSemesterMinutes / safeDays).round();
  }

  String formatHM(int seconds) {
    final totalMinutes = seconds ~/ 60;

    final h = totalMinutes ~/ 60;

    final m = totalMinutes % 60;

    return "${h} h ${m} m";
  }

  Future<void> sendDeviceHeartbeat() async {
    final prefs = await SharedPreferences.getInstance();

    final uid = prefs.getString('uid');

    if (uid == null) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      if (!snapshot.exists) {
        return;
      }

      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'lastDeviceHeartbeat': DateTime.now(),
      });
    } catch (e) {
      debugPrint("Device heartbeat failed: $e");
    }
  }

  Future<void> retryPendingUpload() async {
    final prefs = await SharedPreferences.getInstance();

    final raw = prefs.getString(pendingStopKey);

    if (raw == null) {
      return;
    }

    setState(() {
      uploadPending = true;
    });

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
      });

      await prefs.remove(pendingStopKey);

      if (mounted) {
        setState(() {
          uploadPending = false;
        });
      }
    } catch (e) {
      debugPrint("Pending upload retry failed: $e");
    }
  }

  @override
  void initState() {
    super.initState();

    loadSemesterStatuses();
    retryPendingUpload();
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

                              RichText(
                                text: TextSpan(
                                  children: [
                                    const TextSpan(
                                      text: "Weekly Minimum: ",

                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                      ),
                                    ),

                                    TextSpan(
                                      text: "${minimumWeeklyMinutes ~/ 60} h",

                                      style: const TextStyle(
                                        color: gold,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 2),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,

                            children: const [
                              Text(
                                "This week total",

                                textAlign: TextAlign.center,

                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                ),
                              ),

                              Text(
                                "This week daily avg",

                                textAlign: TextAlign.center,

                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                ),
                              ),

                              Text(
                                "Semester daily avg",

                                textAlign: TextAlign.center,

                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 2),

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

                              FutureBuilder<int>(
                                future: getSemesterDailyAverage(),

                                builder: (context, semesterSnapshot) {
                                  final semesterAverage =
                                      semesterSnapshot.data ?? 0;

                                  return Text(
                                    formatHM(semesterAverage),

                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  );
                                },
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

            if (semesterStatuses.isNotEmpty)
              SemesterCard(title: semesterTitle, statuses: semesterStatuses),

            if (vacationMode)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),

                child: Text(
                  "Enjoy your vacation! Feel free to keep tracking practice for your own record keeping, but it will not be monitored.",

                  textAlign: TextAlign.center,

                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),

            const SizedBox(height: 8),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,

              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,

                    foregroundColor: gold,
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

                const SizedBox(width: 18),

                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: gold,

                    foregroundColor: Colors.black,
                  ),

                  child: const Text("Review Sessions"),

                  onPressed: () {
                    Navigator.push(
                      context,

                      MaterialPageRoute(
                        builder: (context) => const ReviewPage(),
                      ),
                    );
                  },
                ),
              ],
            ),

            const SizedBox(height: 20),

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
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                  (route) => false,
                );
              },
              child: const Text("LOGOUT"),
            ),

            const SizedBox(height: 24),

            if (uploadPending)
              const Padding(
                padding: EdgeInsets.only(bottom: 10),

                child: Text(
                  "STATUS: Upload Pending",

                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

            const HarmonyProgressCard(),

            const SizedBox(height: 10),

            Padding(
              padding: const EdgeInsets.only(bottom: 4),

              child: SvgPicture.asset(
                'assets/Organ-Studio-LockupStacked-RGB.svg',
                height: 105,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
