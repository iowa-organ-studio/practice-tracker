import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import '../models/segment.dart';
import '../models/wave_point.dart';
import '../painters/graph_painter.dart';
import '../painters/waveform_painter.dart';
import '../services/user_service.dart';
import 'home_page.dart';
import '../theme/app_colors.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'dart:convert';
import 'admin_page.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../services/week_service.dart';
import '../services/firebase_paths.dart';

class PracticePage extends StatefulWidget {
  final String instrument;
  final bool initiatedOverlap;
  final bool adminMode;

  const PracticePage({
    super.key,
    required this.instrument,
    this.initiatedOverlap = false,
    this.adminMode = false,
  });

  @override
  State<PracticePage> createState() => _PracticePageState();
}

class _PracticePageState extends State<PracticePage>
    with WidgetsBindingObserver {
  late Timer timer;
  Timer? heartbeatTimer;
  StreamSubscription? overlapSubscription;
  int seconds = 0;
  static const pendingStopKey = 'pending_stop_upload';
  DateTime? startTime;

  List<Segment> timeline = [];
  bool isMoving = false;
  DateTime? movingStartTime;
  DateTime? stillStartTime;
  DateTime? lastMovementTransitionTime;
  bool isFlagged = false;
  bool initiatedOverlap = false;

  String? activeConflictId;

  bool conflictAlreadyCreated = false;

  bool isSavingSession = false;

  bool uploadPending = false;

  bool isPaused = false;

  DateTime? pausedStartTime;

  List<WavePoint> waveform = [];

  final AudioRecorder recorder = AudioRecorder();

  Timer? amplitudeTimer;

  double currentAmplitude = 0;

  String uid = "";
  String name = "";
  String role = "";
  String? sessionId;

  WeekInfo? currentWeek;

  String formatClockTime(DateTime t) {
    int h = t.hour % 12;
    if (h == 0) h = 12;

    final m = t.minute.toString().padLeft(2, '0');
    final suffix = t.hour >= 12 ? "pm" : "am";

    return "$h:$m$suffix";
  }

  String formatClock(int s) {
    final minutes = (s ~/ 60).toString().padLeft(2, '0');
    final secs = (s % 60).toString().padLeft(2, '0');
    return "$minutes:$secs";
  }

  Future<void> loadUser() async {
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      uid = prefs.getString('uid') ?? "";
      name = prefs.getString('name') ?? "";
      role = prefs.getString('role') ?? "";
    });
  }

  Future<void> createSession() async {
    currentWeek = await getCurrentWeekInfo();

    if (currentWeek == null) {
      debugPrint("No current week found");

      return;
    }

    final weekDoc = FirebasePaths.weekDoc(
      uid: uid,
      weekId: currentWeek!.weekId,
    );

    final weekSnapshot = await weekDoc.get();

    if (!weekSnapshot.exists) {
      await weekDoc.set({
        'semesterId': currentWeek!.semesterId,

        'weekId': currentWeek!.weekId,

        'weekNumber': currentWeek!.weekNumber,

        'totalPracticeSeconds': 0,

        'activeSession': true,

        'currentOrgan': widget.instrument,

        'currentSessionId': null,

        'lastHeartbeat': DateTime.now(),
      });
    } else {
      await weekDoc.update({
        'activeSession': true,

        'currentOrgan': widget.instrument,

        'lastHeartbeat': DateTime.now(),
      });
    }

    final sessionDoc =
        await FirebasePaths.sessionsCollection(
          uid: uid,
          weekId: currentWeek!.weekId,
        ).add({
          'uid': uid,

          'name': name,

          'instrument': widget.instrument,

          'startTime': startTime,

          'endTime': null,

          'status': 'normal',

          'timeline': timeline
              .map(
                (e) => {
                  'start': e.start,

                  'moving': e.moving,

                  'flagged': e.flagged,

                  'paused': e.paused,

                  'resolved': e.resolved,

                  'fraudulent': e.fraudulent,
                },
              )
              .toList(),
        });

    sessionId = sessionDoc.id;

    await weekDoc.update({'currentSessionId': sessionId});
  }

  Future<void> syncTimeline() async {
    if (sessionId == null || currentWeek == null) {
      return;
    }

    try {
      await FirebasePaths.sessionDoc(
        uid: uid,

        weekId: currentWeek!.weekId,

        sessionId: sessionId!,
      ).update({
        'timeline': timeline
            .map(
              (e) => {
                'start': e.start,

                'moving': e.moving,

                'flagged': e.flagged,

                'paused': e.paused,

                'resolved': e.resolved,

                'fraudulent': e.fraudulent,
              },
            )
            .toList(),
      });
    } catch (e) {
      debugPrint("Timeline sync failed: $e");
    }
  }

  Future<void> createConflict() async {
    if (conflictAlreadyCreated) {
      return;
    }

    if (sessionId == null || currentWeek == null) {
      return;
    }

    try {
      final usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .get();

      List<DocumentSnapshot<Map<String, dynamic>>> cusps = [];

      for (final userDoc in usersSnapshot.docs) {
        final weekDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userDoc.id)
            .collection('weeks')
            .doc(currentWeek!.weekId)
            .get();

        if (weekDoc.exists) {
          cusps.add(weekDoc);
        }
      }

      final overlappingCusps = cusps.where((doc) {
        final data = doc.data()!;

        final active = data['activeSession'] == true;

        if (!active) {
          debugPrint("REJECT active=false");
          return false;
        }

        final organ = data['currentOrgan'];

        if (organ != widget.instrument) {
          return false;
        }

        final otherSessionId = data['currentSessionId'];

        if (otherSessionId == sessionId) {
          return false;
        }

        final heartbeat = data['lastHeartbeat'];

        if (heartbeat == null) {
          return false;
        }

        final heartbeatTime = (heartbeat as Timestamp).toDate();

        final stale = DateTime.now().difference(heartbeatTime).inMinutes > 3;

        if (stale) {
          return false;
        }

        return true;
      }).toList();

      if (overlappingCusps.isEmpty) {
        return;
      }

      final sessionRefs = [
        {'uid': uid, 'weekId': currentWeek!.weekId, 'sessionId': sessionId},
      ];

      final uids = [uid];

      final names = [name];

      for (final cusp in overlappingCusps) {
        final data = cusp.data()!;

        final otherUid = cusp.reference.parent.parent!.id;

        sessionRefs.add({
          'uid': otherUid,

          'weekId': currentWeek!.weekId,

          'sessionId': data['currentSessionId'],
        });

        uids.add(otherUid);
      }

      final existingConflicts = await FirebasePaths.conflictsCollection()
          .where('resolved', isEqualTo: false)
          .get();

      for (final doc in existingConflicts.docs) {
        final data = doc.data();

        final existingRefs = List<Map<String, dynamic>>.from(
          data['sessionRefs'] ?? [],
        );

        final normalize = (List<Map<String, dynamic>> refs) =>
            refs.map((e) => "${e['uid']}_${e['sessionId']}").toList()..sort();

        final existingNorm = normalize(existingRefs);

        final currentNorm = normalize(sessionRefs);

        if (existingNorm.join('_') == currentNorm.join('_')) {
          activeConflictId = doc.id;

          conflictAlreadyCreated = true;

          return;
        }
      }

      final conflictDoc = await FirebasePaths.conflictsCollection().add({
        'sessionRefs': sessionRefs,

        'uids': uids,

        'organ': widget.instrument,

        'weekId': currentWeek!.weekId,

        'createdAt': DateTime.now(),

        'resolved': false,

        'winnerSessionId': null,
      });

      activeConflictId = conflictDoc.id;

      conflictAlreadyCreated = true;
    } catch (e) {
      debugPrint("Conflict creation failed: $e");
    }
  }

  void startOverlapWatcher() {
    if (currentWeek == null) return;

    // Real-time listener: Firestore pushes updates only when data changes.
    // Replaces the Stream.periodic approach that was doing (1 + N) reads
    // every 5 seconds. Now we get 1 initial read + 1 read per actual change.
    //
    // Requires a composite index on the 'weeks' collectionGroup:
    //   activeSession ASC, currentOrgan ASC, weekId ASC
    // Add it in the Firebase console or via firestore.indexes.json.
    overlapSubscription = FirebaseFirestore.instance
        .collectionGroup('weeks')
        .where('activeSession', isEqualTo: true)
        .where('currentOrgan', isEqualTo: widget.instrument)
        .where('weekId', isEqualTo: currentWeek!.weekId)
        .snapshots()
        .listen((snapshot) async {
          final now = DateTime.now();

          bool overlapNow = snapshot.docs.any((doc) {
            final data = doc.data();

            final currentSession = data['currentSessionId'];

            if (currentSession == sessionId) {
              debugPrint("REJECT same session");
              return false;
            }

            final heartbeat = data['lastHeartbeat'];

            if (heartbeat == null) {
              debugPrint("REJECT heartbeat null");
              return false;
            }

            final heartbeatTime = (heartbeat as Timestamp).toDate();

            final stale =
                now.difference(heartbeatTime) > const Duration(minutes: 3);

            if (stale) {
              debugPrint(
                "REJECT stale heartbeat "
                "user=${doc.reference.parent.parent!.id} "
                "organ=${widget.instrument} "
                "age=${now.difference(heartbeatTime).inSeconds}s",
              );
              return false;
            }

            debugPrint(
              "FOUND OVERLAP "
              "me=$uid "
              "other=${doc.reference.parent.parent!.id}",
            );

            return true;
          });

          debugPrint(
            "OVERLAP CHECK "
            "uid=$uid "
            "session=$sessionId "
            "organ=${widget.instrument} "
            "overlapNow=$overlapNow",
          );

          final newFlaggedState = widget.instrument != 'Other' && overlapNow;

          if (newFlaggedState != isFlagged) {
            final previousFlaggedState = isFlagged;

            setState(() {
              isFlagged = newFlaggedState;

              timeline.add(
                Segment(
                  seconds,
                  isMoving,
                  flagged: newFlaggedState && !isMoving,
                ),
              );
            });

            syncTimeline();

            if (!previousFlaggedState && newFlaggedState) {
              await createConflict();

              if (!initiatedOverlap) {
                showOverlapDialog();
              }
            }
          }
        });
  }

  void showOverlapDialog() {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return AlertDialog(
          title: const Text("Organ Conflict"),
          content: const Text(
            "Someone else has started a practice session on this organ.\n\nDo you wish to continue practicing?",
          ),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.pop(context);

                // ✅ stop timers
                timer.cancel();
                heartbeatTimer?.cancel();
                amplitudeTimer?.cancel();

                // ✅ finalize session in Firestore
                try {
                  if (sessionId != null) {
                    await FirebasePaths.sessionDoc(
                      uid: uid,

                      weekId: currentWeek!.weekId,

                      sessionId: sessionId!,
                    ).update({
                      'duration': seconds,

                      'timeline': timeline
                          .map(
                            (e) => {
                              'start': e.start,

                              'moving': e.moving,

                              'flagged': e.flagged,

                              'paused': e.paused,

                              'resolved': e.resolved,

                              'fraudulent': e.fraudulent,
                            },
                          )
                          .toList(),

                      'endTime': DateTime.now(),
                    });
                  }
                } catch (e) {
                  debugPrint("Error ending session from conflict dialog: $e");
                }

                if (!mounted) return;

                // ✅ go home
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        widget.adminMode ? const AdminPage() : const HomePage(),
                  ),
                  (route) => false,
                );
              },
              child: const Text("No"),
            ),

            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text("Yes"),
            ),
          ],
        );
      },
    );
  }

  Future<void> sendHeartbeat() async {
    if (currentWeek == null) {
      return;
    }

    try {
      await FirebasePaths.weekDoc(
        uid: uid,
        weekId: currentWeek!.weekId,
      ).update({'lastHeartbeat': DateTime.now()});
    } catch (e) {
      debugPrint("Heartbeat update failed: $e");
    }
  }

  Future<void> initializePractice() async {
    debugPrint("INITIALIZE PRACTICE");
    await loadUser();
    debugPrint("USER LOADED");
    startTime = DateTime.now();
    initiatedOverlap = widget.initiatedOverlap;
    timeline = [Segment(0, false, flagged: false)];

    await createSession();
    debugPrint("SESSION CREATED");
    if (widget.instrument != 'Other') {
      startOverlapWatcher();
      debugPrint("OVERLAP WATCHER STARTED");
    }
    if (mounted) {
      setState(() {});
    }
  }

  String formatDate(DateTime d) {
    const months = [
      "Jan",
      "Feb",
      "Mar",
      "Apr",
      "May",
      "Jun",
      "Jul",
      "Aug",
      "Sep",
      "Oct",
      "Nov",
      "Dec",
    ];
    return "${d.day.toString().padLeft(2, '0')} ${months[d.month - 1]} ${d.year}";
  }

  String formatHM(int s) {
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    final sec = s % 60;

    if (h > 0) {
      return "$h h $m m $sec s";
    }

    return "$m m $sec s";
  }

  String formatDuration(int seconds) {
    final m = (seconds ~/ 60);
    final s = (seconds % 60).toString().padLeft(2, '0');
    return "$m:$s";
  }

  Map<String, int> computeTotals() {
    int practice = 0;
    int moving = 0;
    int flagged = 0;
    int paused = 0;

    for (int i = 0; i < timeline.length; i++) {
      final current = timeline[i];

      int end = (i < timeline.length - 1) ? timeline[i + 1].start : seconds;

      int duration = end - current.start;

      if (current.paused) {
        paused += duration;
      } else if (current.moving) {
        moving += duration;
      } else if (current.flagged) {
        flagged += duration;
      } else {
        practice += duration;
      }
    }

    return {
      'practice': practice,
      'moving': moving,
      'flagged': flagged,
      'paused': paused,
    };
  }

  Future<void> initializeWaveform() async {
    if (widget.instrument != 'Other') return;

    try {
      final hasPermission = await recorder.hasPermission();

      if (!hasPermission) {
        debugPrint("Microphone permission denied");
        return;
      }

      final dir = await getTemporaryDirectory();

      final path = '${dir.path}/temp_recording.m4a';

      await recorder.start(const RecordConfig(), path: path);

      amplitudeTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
        try {
          final amp = await recorder.getAmplitude();

          if (!mounted) return;

          double normalized = (amp.current + 60) / 60;

          normalized = normalized.clamp(0.0, 1.0);

          setState(() {
            currentAmplitude = (currentAmplitude * 0.7) + (normalized * 0.3);

            waveform.add(WavePoint(seconds, currentAmplitude));
          });
        } catch (e) {
          debugPrint("Amplitude read error: $e");
        }
      });
    } catch (e) {
      debugPrint("Waveform init error: $e");
    }
  }

  Future<void> savePendingStopUpload() async {
    final prefs = await SharedPreferences.getInstance();

    final pendingData = {
      'uid': uid,
      'weekId': currentWeek!.weekId,
      'sessionId': sessionId,
      'duration': seconds,
      'endTime': DateTime.now().toIso8601String(),

      'timeline': timeline
          .map(
            (e) => {
              'start': e.start,
              'moving': e.moving,
              'flagged': e.flagged,
              'paused': e.paused,
              'resolved': e.resolved,
              'fraudulent': e.fraudulent,
            },
          )
          .toList(),

      'waveform': waveform
          .map((e) => {'second': e.second, 'amplitude': e.amplitude})
          .toList(),
    };

    await prefs.setString(pendingStopKey, jsonEncode(pendingData));
  }

  @override
  void initState() {
    debugPrint("INIT STATE");
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    WakelockPlus.enable();

    initializePractice();
    initializeWaveform();
    heartbeatTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      sendHeartbeat();
      syncTimeline();
    });

    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;

      if (isPaused) {
        return;
      }

      setState(() {
        seconds++;
      });
    });

    accelerometerEventStream().listen((event) {
      if (!mounted) return;

      double mag = (event.x * event.x + event.y * event.y + event.z * event.z);

      bool movementDetected = mag > 120;

      final now = DateTime.now();

      if (movementDetected) {
        movingStartTime ??= now;

        stillStartTime = null;

        if (!isMoving) {
          final enoughTimePassed =
              lastMovementTransitionTime == null ||
              now.difference(lastMovementTransitionTime!) >
                  const Duration(seconds: 2);

          if (enoughTimePassed) {
            setState(() {
              isMoving = true;

              lastMovementTransitionTime = now;

              timeline.add(Segment(seconds, true, flagged: isFlagged));
            });

            syncTimeline();
          }
        }
      } else {
        stillStartTime ??= now;

        movingStartTime = null;

        if (isMoving &&
            now.difference(stillStartTime!) >= const Duration(seconds: 5)) {
          setState(() {
            final enoughTimePassed =
                lastMovementTransitionTime == null ||
                now.difference(lastMovementTransitionTime!) >
                    const Duration(seconds: 2);

            if (enoughTimePassed) {
              isMoving = false;

              lastMovementTransitionTime = now;

              timeline.add(Segment(seconds, false, flagged: isFlagged));
            }
          });

          syncTimeline();
        }
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    timer.cancel();
    WakelockPlus.disable();
    amplitudeTimer?.cancel();

    heartbeatTimer?.cancel();

    overlapSubscription?.cancel();

    recorder.stop();

    recorder.dispose();

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;

    if (state == AppLifecycleState.paused) {
      pausedStartTime = DateTime.now();

      setState(() {
        isPaused = true;
      });

      syncTimeline();
    }

    if (state == AppLifecycleState.resumed) {
      if (pausedStartTime != null) {
        final pausedDuration = DateTime.now()
            .difference(pausedStartTime!)
            .inSeconds;

        final resumedSecond = seconds + pausedDuration;

        setState(() {
          final pauseStartSecond = seconds;

          seconds = resumedSecond;

          timeline.add(Segment(pauseStartSecond, false, paused: true));

          timeline.add(
            Segment(resumedSecond, isMoving, flagged: isFlagged && !isMoving),
          );

          isPaused = false;
        });

        pausedStartTime = null;

        syncTimeline();
      }
    }
  }

  Future<int> computePracticeSeconds() async {
    int practice = 0;

    for (int i = 0; i < timeline.length; i++) {
      final current = timeline[i];

      final end = i < timeline.length - 1 ? timeline[i + 1].start : seconds;

      final duration = end - current.start;

      final legitimate =
          !current.moving &&
          !current.paused &&
          !current.flagged &&
          !current.fraudulent;

      final resolvedPractice =
          current.resolved &&
          !current.fraudulent &&
          !current.paused &&
          !current.moving;

      if (legitimate || resolvedPractice) {
        practice += duration;
      }
    }

    return practice;
  }

  Future<void> recomputeWeekTotal() async {
    if (currentWeek == null) {
      return;
    }

    final sessions = await FirebasePaths.sessionsCollection(
      uid: uid,
      weekId: currentWeek!.weekId,
    ).get();

    int total = 0;

    for (final doc in sessions.docs) {
      final data = doc.data();

      total += (data['practiceSeconds'] as int?) ?? 0;
    }

    await FirebasePaths.weekDoc(
      uid: uid,
      weekId: currentWeek!.weekId,
    ).update({'totalPracticeSeconds': total});
  }

  @override
  Widget build(BuildContext context) {
    debugPrint("PRACTICE BUILD");
    if (startTime == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return PopScope(
      canPop: false,

      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Practice session is active. Press "Stop Practice" to return to app home screen.',
            ),

            duration: Duration(seconds: 2),
          ),
        );
      },

      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              // TOP CONTENT
              // TOP CONTENT
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      FutureBuilder<Map<String, String>>(
                        future: getUserInfo(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) return const SizedBox();

                          final user = snapshot.data!;

                          return Container(
                            width: double.infinity,
                            color: Colors.black,
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user['name'] ?? '',
                                  style: const TextStyle(
                                    color: gold,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 20),

                      Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            "${formatDate(startTime!)} --- ${widget.instrument}",
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 10),

                      SizedBox(
                        height: 84,
                        child: Row(
                          children: [
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(
                                  left: 2,
                                  right: 2,
                                ),
                                child: CustomPaint(
                                  size: Size.infinite,
                                  painter: GraphPainter(
                                    timeline,
                                    seconds,
                                    startTime!,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 8),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(width: 10, height: 10, color: Colors.green),

                          const SizedBox(width: 4),

                          const Text(
                            "practice",
                            style: TextStyle(fontSize: 11),
                          ),

                          const SizedBox(width: 14),

                          Container(width: 10, height: 10, color: gold),

                          const SizedBox(width: 4),

                          const Text("moving", style: TextStyle(fontSize: 11)),

                          const SizedBox(width: 14),

                          Container(width: 10, height: 10, color: Colors.red),

                          const SizedBox(width: 4),

                          const Text("flagged", style: TextStyle(fontSize: 11)),

                          const SizedBox(width: 14),

                          Container(width: 10, height: 10, color: Colors.grey),

                          const SizedBox(width: 4),

                          const Text("paused", style: TextStyle(fontSize: 11)),
                        ],
                      ),

                      if (widget.instrument == 'Other') ...[
                        const SizedBox(height: 10),

                        SizedBox(
                          height: 84,
                          child: Row(
                            children: [
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(
                                    left: 2,
                                    right: 2,
                                  ),
                                  child: CustomPaint(
                                    size: Size.infinite,
                                    painter: WaveformPainter(waveform, seconds),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 8),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,

                        children: [
                          Container(width: 10, height: 10, color: Colors.green),

                          const SizedBox(width: 4),

                          Text(
                            formatHM(computeTotals()['practice']!),

                            style: const TextStyle(fontSize: 14),
                          ),

                          const SizedBox(width: 16),

                          Container(width: 10, height: 10, color: gold),

                          const SizedBox(width: 4),

                          Text(
                            formatHM(computeTotals()['moving']!),

                            style: const TextStyle(fontSize: 14),
                          ),

                          const SizedBox(width: 16),

                          Container(width: 10, height: 10, color: Colors.red),

                          const SizedBox(width: 4),

                          Text(
                            formatHM(computeTotals()['flagged']!),

                            style: const TextStyle(fontSize: 14),
                          ),

                          const SizedBox(width: 16),

                          Container(width: 10, height: 10, color: Colors.grey),

                          const SizedBox(width: 4),

                          Text(
                            formatHM(computeTotals()['paused']!),

                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      Text(
                        formatClock(seconds),
                        style: const TextStyle(fontSize: 28),
                      ),

                      if (isSavingSession) ...[
                        const SizedBox(height: 10),

                        const Text(
                          "Saving session...",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 4),

                        const Text(
                          "Waiting for internet connection...",
                          style: TextStyle(fontSize: 13, color: Colors.grey),
                        ),

                        const SizedBox(height: 10),

                        const CircularProgressIndicator(),
                      ],

                      if (uploadPending)
                        const Padding(
                          padding: EdgeInsets.only(top: 10),

                          child: Text(
                            "STATUS: Upload Pending",

                            style: TextStyle(
                              color: Colors.red,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),

                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: gold,
                          foregroundColor: Colors.black,
                        ),
                        onPressed: () async {
                          timer.cancel();

                          final connectivityResults = await Connectivity()
                              .checkConnectivity();

                          final offline = connectivityResults.contains(
                            ConnectivityResult.none,
                          );

                          if (offline) {
                            await Future.delayed(const Duration(seconds: 3));
                            await savePendingStopUpload();

                            if (mounted) {
                              setState(() {
                                uploadPending = true;
                              });
                            }

                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                duration: Duration(seconds: 8),

                                content: Text(
                                  "No internet connection available. Practice end time saved locally and will upload when connected to the internet. Do not force close the app or you may lose your session.",
                                ),
                              ),
                            );

                            if (!mounted) return;

                            Navigator.pushAndRemoveUntil(
                              context,

                              MaterialPageRoute(
                                builder: (_) => widget.adminMode
                                    ? const AdminPage()
                                    : const HomePage(),
                              ),

                              (route) => false,
                            );

                            return;
                          }

                          setState(() {
                            isSavingSession = true;
                          });

                          try {
                            final practiceSeconds =
                                await computePracticeSeconds();

                            await FirebasePaths.sessionDoc(
                              uid: uid,

                              weekId: currentWeek!.weekId,

                              sessionId: sessionId!,
                            ).update({
                              'duration': seconds,

                              'timeline': timeline
                                  .map(
                                    (e) => {
                                      'start': e.start,

                                      'moving': e.moving,

                                      'flagged': e.flagged,

                                      'paused': e.paused,

                                      'resolved': e.resolved,

                                      'fraudulent': e.fraudulent,
                                    },
                                  )
                                  .toList(),

                              'waveform': waveform
                                  .map(
                                    (e) => {
                                      'second': e.second,

                                      'amplitude': e.amplitude,
                                    },
                                  )
                                  .toList(),

                              'endTime': DateTime.now(),

                              'practiceSeconds': practiceSeconds,
                            });

                            await FirebasePaths.weekDoc(
                              uid: uid,

                              weekId: currentWeek!.weekId,
                            ).update({
                              'activeSession': false,

                              'currentOrgan': null,

                              'currentSessionId': null,
                            });

                            await recomputeWeekTotal();
                          } catch (e) {
                            debugPrint("Error updating session: $e");

                            await savePendingStopUpload();

                            await FirebasePaths.sessionDoc(
                              uid: uid,

                              weekId: currentWeek!.weekId,

                              sessionId: sessionId!,
                            ).update({'endedOffline': true});

                            if (mounted) {
                              setState(() {
                                uploadPending = true;
                              });
                            }

                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                duration: Duration(seconds: 8),

                                content: Text(
                                  "No internet connection available. Practice end time saved locally and will upload when connected to the internet. Do not force close the app or you may lose your session.",
                                ),
                              ),
                            );
                          }

                          if (!mounted) return;

                          Navigator.pushAndRemoveUntil(
                            context,

                            MaterialPageRoute(
                              builder: (_) => widget.adminMode
                                  ? const AdminPage()
                                  : const HomePage(),
                            ),

                            (route) => false,
                          );
                        },
                        child: const Text("Stop Practice"),
                      ),
                    ],
                  ),
                ),
              ),
              // LOGO BOTTOM
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 10),
                child: SvgPicture.asset(
                  'assets/Organ-Studio-LockupStacked-RGB.svg',
                  height: 70,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}