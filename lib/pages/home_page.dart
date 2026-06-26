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

  // Cache key for the last known semester statuses, so we can show
  // something immediately on load instead of a blank gap while the
  // real (and sometimes slow) calculation runs in the background.
  static const semesterStatusCacheKey = 'cached_semester_statuses';
  static const semesterTitleCacheKey = 'cached_semester_title';

  List<WeekStatus> semesterStatuses = [];
  static const pendingStopKey = 'pending_stop_upload';
  String semesterTitle = "Semester";
  bool vacationMode = false;
  bool uploadPending = false;

  /// Loads any cached statuses from the last successful calculation and
  /// shows them immediately, before the real (potentially slow) network
  /// calculation below has a chance to run. If nothing has changed once
  /// the real calculation finishes, the UI just doesn't visibly update —
  /// if something DID change, it swaps in seamlessly once ready.
  Future<void> _loadCachedSemesterStatuses() async {
    final prefs = await SharedPreferences.getInstance();

    final cachedTitle = prefs.getString(semesterTitleCacheKey);
    final cachedRaw = prefs.getString(semesterStatusCacheKey);

    if (cachedRaw == null) return;

    try {
      final decoded = (jsonDecode(cachedRaw) as List)
          .map((s) => WeekStatus.values.firstWhere(
                (e) => e.name == s,
                orElse: () => WeekStatus.future,
              ))
          .toList();

      if (!mounted) return;

      setState(() {
        semesterStatuses = decoded;
        if (cachedTitle != null) semesterTitle = cachedTitle;
      });
    } catch (e) {
      debugPrint("Failed to parse cached semester statuses: $e");
    }
  }

  Future<void> _cacheSemesterStatuses(
    List<WeekStatus> statuses,
    String title,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(statuses.map((s) => s.name).toList());
    await prefs.setString(semesterStatusCacheKey, encoded);
    await prefs.setString(semesterTitleCacheKey, title);
  }

  Future<void> loadSemesterStatuses() async {
    final semester = await getActiveSemester();

    if (semester == null) {
      setState(() {
        vacationMode = true;
      });

      return;
    }

    final title = "${semester.name} Practice";

    setState(() {
      semesterTitle = title;

      vacationMode = false;
    });

    final uid = await getUid();

    final minimumMinutes = await getMinimumWeeklyMinutes();

    setState(() {
      minimumWeeklyMinutes = minimumMinutes;
    });

    // Freeze any past weeks that are now old enough (see
    // isWeekFreezeEligible). This is a no-op for weeks already frozen,
    // and only does real work the first time anyone opens the app after
    // a week crosses the freeze threshold.
    await freezeEligibleWeeks(semester);

    final lastFrozenWeekNumber = await getLastFrozenWeekNumber(semester);

    final now = DateTime.now();

    // Compute every week's status concurrently rather than one at a
    // time — only the still-live week actually does a heavy scan, but
    // running everything in parallel means that scan doesn't block the
    // simple per-week lookups (which were previously waiting behind it
    // in the sequential for-loop, even though they have nothing to do
    // with each other).
    final loadedStatuses = await Future.wait(semester.weeks.map((week) async {
      final isFrozen = week.weekNumber <= lastFrozenWeekNumber;

      bool isTopPracticer;

      if (isFrozen) {
        // Cheap path: just read the flag already written at freeze time.
        isTopPracticer = await getIsGoldStar(uid: uid, weekId: week.weekId);
      } else if (now.isAfter(week.end)) {
        // This is the one still-live week (the most recent past week
        // that hasn't crossed the freeze threshold yet). Compute it the
        // old way so the admin still has time to resolve conflicts
        // before it locks in.
        final topUid = await getTopPracticerUidForWeek(week: week);

        isTopPracticer = uid == topUid;
      } else {
        isTopPracticer = false;
      }

      final seconds = await getWeekPracticeTotal(
        uid: uid,
        weekId: week.weekId,
      );

      final isCurrentWeek = now.isAfter(week.start) && now.isBefore(week.end);

      return computeWeekStatus(
        week: week,
        practicedSeconds: seconds,
        minimumMinutes: minimumMinutes,
        isCurrentWeek: isCurrentWeek,
        isTopPracticer: isTopPracticer,
      );
    }));

    if (!mounted) return;

    setState(() {
      semesterStatuses = loadedStatuses;
    });

    // Save this result so the next app open (or returning home after a
    // practice session) can show it immediately, without a fresh gap.
    await _cacheSemesterStatuses(loadedStatuses, title);
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

    // Run all week totals concurrently instead of accumulating them one
    // await at a time — same fix as the gold star scan, applied here
    // since this loop has the identical sequential-await shape.
    final pastOrCurrentWeeks =
        semester.weeks.where((week) => now.isAfter(week.start)).toList();

    final weekTotals = await Future.wait(pastOrCurrentWeeks.map(
      (week) => getWeekPracticeTotal(uid: uid, weekId: week.weekId),
    ));

    final totalSemesterMinutes =
        weekTotals.fold<int>(0, (sum, minutes) => sum + minutes);

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

    // Show last-known statuses immediately, before kicking off the real
    // (network-bound) calculation. If nothing changed, the user never
    // sees a gap at all; if something did change, it updates in place
    // once loadSemesterStatuses finishes.
    _loadCachedSemesterStatuses();

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

  @override
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
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: SemesterCard(title: semesterTitle, statuses: semesterStatuses),
              ),

            if (vacationMode)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),

                child: Text(
                  "Enjoy your vacation! Feel free to keep tracking practice for your own record keeping, but it will not be monitored.",

                  textAlign: TextAlign.center,

                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),

            const SizedBox(height: 12),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 64,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: gold,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        child: const Text(
                          "Start Practice",
                          textAlign: TextAlign.center,
                        ),
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const SelectionPage(),
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                  const SizedBox(width: 14),

                  Expanded(
                    child: SizedBox(
                      height: 64,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: gold,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        child: const Text(
                          "Review Sessions",
                          textAlign: TextAlign.center,
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ReviewPage(),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            if (uploadPending)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),

                child: Text(
                  "STATUS: Upload Pending",

                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: const HarmonyProgressCard(),
            ),

            const SizedBox(height: 16),

            Center(
              child: SizedBox(
                width: 140,
                height: 44,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
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
              ),
            ),

            const SizedBox(height: 16),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    const baseHeight = 80.0; // logo's natural rendered height
                    final availableHeight = constraints.maxHeight.isFinite
                        ? constraints.maxHeight
                        : baseHeight;
                    final scale = availableHeight / baseHeight;

                    return Align(
                      alignment: Alignment.bottomCenter,
                      child: Transform.scale(
                        scale: scale,
                        alignment: Alignment.bottomCenter,
                        child: SvgPicture.asset(
                          'assets/Organ-Studio-LockupStacked-RGB.svg',
                          height: baseHeight,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
