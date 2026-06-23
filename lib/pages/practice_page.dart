import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart' as ap;

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

  // Metronome state
  int _mm = 126;
  bool _mmClassicMode = true;
  bool _mmRunning = false;
  final ap.AudioPlayer _mmPlayer = ap.AudioPlayer();
  Timer? _mmBeatTimer;
  DateTime? _mmNextBeat;

  // Tap tempo
  final Stopwatch _tapStopwatch = Stopwatch();
  final List<int> _tapIntervals = [];

  static const List<int> _classicMM = [
    30, 32, 34, 36, 38, 40, 42, 44, 46, 48, 50, 52, 54, 56, 58, 60,
    63, 66, 69, 72, 76, 80, 84, 88, 92, 96, 100, 104, 108, 112, 116,
    120, 126, 132, 138, 144, 152, 160, 168, 176, 184, 192, 200,
  ];

  void _mmStep(int direction) {
    setState(() {
      if (_mmClassicMode) {
        final idx = _classicMM.indexOf(_mm);
        if (idx == -1) {
          _mm = direction > 0
              ? _classicMM.firstWhere((v) => v > _mm, orElse: () => _classicMM.last)
              : _classicMM.lastWhere((v) => v < _mm, orElse: () => _classicMM.first);
        } else {
          _mm = _classicMM[(idx + direction).clamp(0, _classicMM.length - 1)];
        }
      } else {
        _mm = (_mm + direction).clamp(30, 200);
      }
    });
    // Changing tempo just adjusts the schedule — no restart, no gap
    if (_mmRunning) _mmRescheduleNextBeat();
  }

  // Drift-compensating scheduler: tracks when each beat *should* fire
  // and adjusts the next Timer delay to absorb any accumulated error,
  // rather than letting Timer.periodic drift cumulatively.
  void _mmRescheduleNextBeat() {
    if (!_mmRunning) return;
    final intervalMs = (60000 / _mm).round();
    _mmNextBeat = DateTime.now().add(Duration(milliseconds: intervalMs));
  }

  void _mmScheduleBeat() {
    if (!_mmRunning || _mmNextBeat == null) return;
    final now = DateTime.now();
    final delay = _mmNextBeat!.difference(now);
    _mmBeatTimer = Timer(delay.isNegative ? Duration.zero : delay, () {
      if (!_mmRunning) return;
      _mmPlayer.play(ap.AssetSource('audio/claves44_wav.wav'));
      final intervalMs = (60000 / _mm).round();
      _mmNextBeat = _mmNextBeat!.add(Duration(milliseconds: intervalMs));
      _mmScheduleBeat();
    });
  }

  void _showMMNumberPad() {
    String input = '';
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          void onDigit(String d) {
            if (input.length < 3) setDialogState(() => input += d);
          }
          void onDelete() {
            if (input.isNotEmpty)
              setDialogState(() => input = input.substring(0, input.length - 1));
          }
          void onConfirm() {
            final val = int.tryParse(input);
            if (val != null) {
              setState(() => _mm = val.clamp(30, 200));
              if (_mmRunning) _mmRescheduleNextBeat();
            }
            Navigator.of(ctx).pop();
          }

          Widget numKey(String label, {VoidCallback? onTap, Color? color}) {
            return GestureDetector(
              onTap: onTap,
              child: Container(
                margin: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: color ?? Colors.grey.shade800,
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text(
                  label,
                  style: TextStyle(
                    color: color != null ? Colors.black : Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
          }

          return Dialog(
            backgroundColor: Colors.black,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: SizedBox(
              width: 260,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Enter MM (30–200)',
                        style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade900,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        input.isEmpty ? '—' : input,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 320,
                      child: GridView.count(
                        crossAxisCount: 3,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          ...['7','8','9','4','5','6','1','2','3']
                              .map((d) => numKey(d, onTap: () => onDigit(d))),
                          numKey('⌫', onTap: onDelete, color: Colors.grey.shade600),
                          numKey('0', onTap: () => onDigit('0')),
                          numKey('✓', onTap: onConfirm, color: gold),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _mmStop() {
    _mmBeatTimer?.cancel();
    _mmBeatTimer = null;
    _mmNextBeat = null;
    setState(() => _mmRunning = false);
  }

  void _mmToggle() {
    if (_mmRunning) {
      _mmStop();
    } else {
      setState(() => _mmRunning = true);
      // Play immediately on start, then schedule subsequent beats
      _mmPlayer.play(ap.AssetSource('audio/claves44_wav.wav'));
      final intervalMs = (60000 / _mm).round();
      _mmNextBeat = DateTime.now().add(Duration(milliseconds: intervalMs));
      _mmScheduleBeat();
    }
  }

  void _onTargetTap() {
    if (!_tapStopwatch.isRunning) {
      _tapStopwatch.reset();
      _tapStopwatch.start();
      _tapIntervals.clear();
      return;
    }
    final elapsed = _tapStopwatch.elapsedMilliseconds;
    if (elapsed > 2500) {
      _tapStopwatch.reset();
      _tapStopwatch.start();
      _tapIntervals.clear();
      return;
    }
    _tapIntervals.add(elapsed);
    _tapStopwatch.reset();
    final recent = _tapIntervals.length > 3
        ? _tapIntervals.sublist(_tapIntervals.length - 3)
        : List<int>.from(_tapIntervals);
    final avgMs = recent.reduce((a, b) => a + b) / recent.length;
    final bpm = (60000 / avgMs).round().clamp(30, 200);
    setState(() => _mm = bpm);
    if (_mmRunning) _mmRescheduleNextBeat();
  }

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
    if (currentWeek == null) { debugPrint("No current week found"); return; }

    final weekDoc = FirebasePaths.weekDoc(uid: uid, weekId: currentWeek!.weekId);
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

    final sessionDoc = await FirebasePaths.sessionsCollection(
      uid: uid, weekId: currentWeek!.weekId,
    ).add({
      'uid': uid, 'name': name, 'instrument': widget.instrument,
      'startTime': startTime, 'endTime': null, 'status': 'normal',
      'timeline': timeline.map((e) => {
        'start': e.start, 'moving': e.moving, 'flagged': e.flagged,
        'paused': e.paused, 'resolved': e.resolved, 'fraudulent': e.fraudulent,
      }).toList(),
    });

    sessionId = sessionDoc.id;
    await weekDoc.update({'currentSessionId': sessionId});
  }

  Future<void> syncTimeline() async {
    if (sessionId == null || currentWeek == null) return;
    try {
      await FirebasePaths.sessionDoc(
        uid: uid, weekId: currentWeek!.weekId, sessionId: sessionId!,
      ).update({
        'timeline': timeline.map((e) => {
          'start': e.start, 'moving': e.moving, 'flagged': e.flagged,
          'paused': e.paused, 'resolved': e.resolved, 'fraudulent': e.fraudulent,
        }).toList(),
      });
    } catch (e) { debugPrint("Timeline sync failed: $e"); }
  }

  Future<void> createConflict() async {
    if (conflictAlreadyCreated || sessionId == null || currentWeek == null) return;
    try {
      final usersSnapshot = await FirebaseFirestore.instance.collection('users').get();
      List<DocumentSnapshot<Map<String, dynamic>>> cusps = [];
      for (final userDoc in usersSnapshot.docs) {
        final weekDoc = await FirebaseFirestore.instance
            .collection('users').doc(userDoc.id)
            .collection('weeks').doc(currentWeek!.weekId).get();
        if (weekDoc.exists) cusps.add(weekDoc);
      }

      final overlappingCusps = cusps.where((doc) {
        final data = doc.data()!;
        if (data['activeSession'] != true) return false;
        if (data['currentOrgan'] != widget.instrument) return false;
        if (data['currentSessionId'] == sessionId) return false;
        final heartbeat = data['lastHeartbeat'];
        if (heartbeat == null) return false;
        return DateTime.now().difference((heartbeat as Timestamp).toDate()).inMinutes <= 3;
      }).toList();

      if (overlappingCusps.isEmpty) return;

      final sessionRefs = [{'uid': uid, 'weekId': currentWeek!.weekId, 'sessionId': sessionId}];
      final uids = [uid];

      for (final cusp in overlappingCusps) {
        final data = cusp.data()!;
        final otherUid = cusp.reference.parent.parent!.id;
        sessionRefs.add({'uid': otherUid, 'weekId': currentWeek!.weekId, 'sessionId': data['currentSessionId']});
        uids.add(otherUid);
      }

      final existingConflicts = await FirebasePaths.conflictsCollection()
          .where('resolved', isEqualTo: false).get();
      final normalize = (List<Map<String, dynamic>> refs) =>
          refs.map((e) => "${e['uid']}_${e['sessionId']}").toList()..sort();
      for (final doc in existingConflicts.docs) {
        final data = doc.data();
        if (normalize(List<Map<String, dynamic>>.from(data['sessionRefs'] ?? [])).join('_') ==
            normalize(sessionRefs).join('_')) {
          activeConflictId = doc.id;
          conflictAlreadyCreated = true;
          return;
        }
      }

      final conflictDoc = await FirebasePaths.conflictsCollection().add({
        'sessionRefs': sessionRefs, 'uids': uids, 'organ': widget.instrument,
        'weekId': currentWeek!.weekId, 'createdAt': DateTime.now(),
        'resolved': false, 'winnerSessionId': null,
      });
      activeConflictId = conflictDoc.id;
      conflictAlreadyCreated = true;
    } catch (e) { debugPrint("Conflict creation failed: $e"); }
  }

  void startOverlapWatcher() {
    if (currentWeek == null) return;
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
            if (data['currentSessionId'] == sessionId) return false;
            final heartbeat = data['lastHeartbeat'];
            if (heartbeat == null) return false;
            if (now.difference((heartbeat as Timestamp).toDate()) > const Duration(minutes: 3)) return false;
            debugPrint("FOUND OVERLAP me=$uid other=${doc.reference.parent.parent!.id}");
            return true;
          });
          debugPrint("OVERLAP CHECK uid=$uid session=$sessionId organ=${widget.instrument} overlapNow=$overlapNow");
          final newFlaggedState = widget.instrument != 'Other' && overlapNow;
          if (newFlaggedState != isFlagged) {
            final previousFlaggedState = isFlagged;
            setState(() {
              isFlagged = newFlaggedState;
              timeline.add(Segment(seconds, isMoving, flagged: newFlaggedState && !isMoving));
            });
            syncTimeline();
            if (!previousFlaggedState && newFlaggedState) {
              await createConflict();
              if (!initiatedOverlap) showOverlapDialog();
            }
          }
        });
  }

  void showOverlapDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text("Organ Conflict"),
        content: const Text(
          "Someone else has started a practice session on this organ.\n\nDo you wish to continue practicing?",
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              timer.cancel();
              heartbeatTimer?.cancel();
              amplitudeTimer?.cancel();
              try {
                if (sessionId != null) {
                  await FirebasePaths.sessionDoc(
                    uid: uid, weekId: currentWeek!.weekId, sessionId: sessionId!,
                  ).update({
                    'duration': seconds,
                    'timeline': timeline.map((e) => {
                      'start': e.start, 'moving': e.moving, 'flagged': e.flagged,
                      'paused': e.paused, 'resolved': e.resolved, 'fraudulent': e.fraudulent,
                    }).toList(),
                    'endTime': DateTime.now(),
                  });
                }
              } catch (e) { debugPrint("Error ending session from conflict dialog: $e"); }
              if (!mounted) return;
              Navigator.pushAndRemoveUntil(context,
                MaterialPageRoute(builder: (_) => widget.adminMode ? const AdminPage() : const HomePage()),
                (route) => false);
            },
            child: const Text("No"),
          ),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Yes")),
        ],
      ),
    );
  }

  Future<void> sendHeartbeat() async {
    if (currentWeek == null) return;
    try {
      await FirebasePaths.weekDoc(uid: uid, weekId: currentWeek!.weekId)
          .update({'lastHeartbeat': DateTime.now()});
    } catch (e) { debugPrint("Heartbeat update failed: $e"); }
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
    if (mounted) setState(() {});
  }

  String formatDate(DateTime d) {
    const months = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"];
    return "${d.day.toString().padLeft(2, '0')} ${months[d.month - 1]} ${d.year}";
  }

  String formatHM(int s) {
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    final sec = s % 60;
    if (h > 0) return "$h h $m m $sec s";
    return "$m m $sec s";
  }

  String formatDuration(int seconds) {
    final m = (seconds ~/ 60);
    final s = (seconds % 60).toString().padLeft(2, '0');
    return "$m:$s";
  }

  Map<String, int> computeTotals() {
    int practice = 0, moving = 0, flagged = 0, paused = 0;
    for (int i = 0; i < timeline.length; i++) {
      final current = timeline[i];
      int end = (i < timeline.length - 1) ? timeline[i + 1].start : seconds;
      int duration = end - current.start;
      if (current.paused) paused += duration;
      else if (current.moving) moving += duration;
      else if (current.flagged) flagged += duration;
      else practice += duration;
    }
    return {'practice': practice, 'moving': moving, 'flagged': flagged, 'paused': paused};
  }

  Future<void> initializeWaveform() async {
    if (widget.instrument != 'Other') return;
    try {
      final hasPermission = await recorder.hasPermission();
      if (!hasPermission) { debugPrint("Microphone permission denied"); return; }
      final dir = await getTemporaryDirectory();
      await recorder.start(const RecordConfig(), path: '${dir.path}/temp_recording.m4a');
      amplitudeTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
        try {
          final amp = await recorder.getAmplitude();
          if (!mounted) return;
          double normalized = ((amp.current + 60) / 60).clamp(0.0, 1.0);
          setState(() {
            currentAmplitude = (currentAmplitude * 0.7) + (normalized * 0.3);
            waveform.add(WavePoint(seconds, currentAmplitude));
          });
        } catch (e) { debugPrint("Amplitude read error: $e"); }
      });
    } catch (e) { debugPrint("Waveform init error: $e"); }
  }

  Future<void> savePendingStopUpload() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(pendingStopKey, jsonEncode({
      'uid': uid, 'weekId': currentWeek!.weekId, 'sessionId': sessionId,
      'duration': seconds, 'endTime': DateTime.now().toIso8601String(),
      'timeline': timeline.map((e) => {
        'start': e.start, 'moving': e.moving, 'flagged': e.flagged,
        'paused': e.paused, 'resolved': e.resolved, 'fraudulent': e.fraudulent,
      }).toList(),
      'waveform': waveform.map((e) => {'second': e.second, 'amplitude': e.amplitude}).toList(),
    }));
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

    // Metronome initialized fresh on each Start press

    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (isPaused) return;
      setState(() { seconds++; });
    });

    accelerometerEventStream().listen((event) {
      if (!mounted) return;
      double mag = event.x * event.x + event.y * event.y + event.z * event.z;
      bool movementDetected = mag > 120;
      final now = DateTime.now();

      if (movementDetected) {
        movingStartTime ??= now;
        stillStartTime = null;
        if (!isMoving) {
          final enoughTimePassed = lastMovementTransitionTime == null ||
              now.difference(lastMovementTransitionTime!) > const Duration(seconds: 2);
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
        if (isMoving && now.difference(stillStartTime!) >= const Duration(seconds: 5)) {
          setState(() {
            final enoughTimePassed = lastMovementTransitionTime == null ||
                now.difference(lastMovementTransitionTime!) > const Duration(seconds: 2);
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
    _mmBeatTimer?.cancel();
    _mmPlayer.dispose();
    recorder.stop();
    recorder.dispose();
    super.dispose();
  }

 @override
void didChangeAppLifecycleState(AppLifecycleState state) {
  if (!mounted) return;

  if (state == AppLifecycleState.inactive ||
      state == AppLifecycleState.paused) {
    if (_mmRunning) {
      _mmStop();
    }
  }

  if (state == AppLifecycleState.paused) {
    pausedStartTime = DateTime.now();
    setState(() {
      isPaused = true;
    });
    syncTimeline();
  }
    if (state == AppLifecycleState.resumed) {
      if (pausedStartTime != null) {
        final pausedDuration = DateTime.now().difference(pausedStartTime!).inSeconds;
        final resumedSecond = seconds + pausedDuration;
        setState(() {
          final pauseStartSecond = seconds;
          seconds = resumedSecond;
          timeline.add(Segment(pauseStartSecond, false, paused: true));
          timeline.add(Segment(resumedSecond, isMoving, flagged: isFlagged && !isMoving));
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
      final legitimate = !current.moving && !current.paused && !current.flagged && !current.fraudulent;
      final resolvedPractice = current.resolved && !current.fraudulent && !current.paused && !current.moving;
      if (legitimate || resolvedPractice) practice += duration;
    }
    return practice;
  }

  Future<void> recomputeWeekTotal() async {
    if (currentWeek == null) return;
    final sessions = await FirebasePaths.sessionsCollection(uid: uid, weekId: currentWeek!.weekId).get();
    int total = 0;
    for (final doc in sessions.docs) {
      total += (doc.data()['practiceSeconds'] as int?) ?? 0;
    }
    await FirebasePaths.weekDoc(uid: uid, weekId: currentWeek!.weekId)
        .update({'totalPracticeSeconds': total});
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Practice session is active. Press "Stop Practice" to return to app home screen.'),
          duration: Duration(seconds: 2),
        ));
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      FutureBuilder<Map<String, String>>(
                        future: getUserInfo(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) return const SizedBox();
                          return Container(
                            width: double.infinity,
                            color: Colors.black,
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              snapshot.data!['name'] ?? '',
                              style: const TextStyle(color: gold, fontSize: 18, fontWeight: FontWeight.bold),
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
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),

                      const SizedBox(height: 10),

                      SizedBox(
                        height: 50,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: CustomPaint(
                            size: Size.infinite,
                            painter: GraphPainter(timeline, seconds, startTime!),
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(width: 10, height: 10, color: Colors.green),
                          const SizedBox(width: 4), const Text("practice", style: TextStyle(fontSize: 11)),
                          const SizedBox(width: 14),
                          Container(width: 10, height: 10, color: gold),
                          const SizedBox(width: 4), const Text("moving", style: TextStyle(fontSize: 11)),
                          const SizedBox(width: 14),
                          Container(width: 10, height: 10, color: Colors.red),
                          const SizedBox(width: 4), const Text("flagged", style: TextStyle(fontSize: 11)),
                          const SizedBox(width: 14),
                          Container(width: 10, height: 10, color: Colors.grey),
                          const SizedBox(width: 4), const Text("paused", style: TextStyle(fontSize: 11)),
                        ],
                      ),

                      if (widget.instrument == 'Other') ...[
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 50,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: CustomPaint(
                              size: Size.infinite,
                              painter: WaveformPainter(waveform, seconds),
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 8),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(width: 10, height: 10, color: Colors.green),
                          const SizedBox(width: 4),
                          Text(formatHM(computeTotals()['practice']!), style: const TextStyle(fontSize: 14)),
                          const SizedBox(width: 16),
                          Container(width: 10, height: 10, color: gold),
                          const SizedBox(width: 4),
                          Text(formatHM(computeTotals()['moving']!), style: const TextStyle(fontSize: 14)),
                          const SizedBox(width: 16),
                          Container(width: 10, height: 10, color: Colors.red),
                          const SizedBox(width: 4),
                          Text(formatHM(computeTotals()['flagged']!), style: const TextStyle(fontSize: 14)),
                          const SizedBox(width: 16),
                          Container(width: 10, height: 10, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(formatHM(computeTotals()['paused']!), style: const TextStyle(fontSize: 14)),
                        ],
                      ),

                      const SizedBox(height: 10),
                      Text(formatClock(seconds), style: const TextStyle(fontSize: 28)),

                      if (isSavingSession) ...[
                        const SizedBox(height: 10),
                        const Text("Saving session...", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        const Text("Waiting for internet connection...", style: TextStyle(fontSize: 13, color: Colors.grey)),
                        const SizedBox(height: 10),
                        const CircularProgressIndicator(),
                      ],

                      if (uploadPending)
                        const Padding(
                          padding: EdgeInsets.only(top: 10),
                          child: Text("STATUS: Upload Pending",
                              style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold)),
                        ),

                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: gold, foregroundColor: Colors.black),
                        onPressed: () async {
                          timer.cancel();
                          final connectivityResults = await Connectivity().checkConnectivity();
                          final offline = connectivityResults.contains(ConnectivityResult.none);

                          if (offline) {
                            await Future.delayed(const Duration(seconds: 3));
                            await savePendingStopUpload();
                            if (mounted) setState(() { uploadPending = true; });
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                              duration: Duration(seconds: 8),
                              content: Text("No internet connection available. Practice end time saved locally and will upload when connected to the internet. Do not force close the app or you may lose your session."),
                            ));
                            if (!mounted) return;
                            Navigator.pushAndRemoveUntil(context,
                              MaterialPageRoute(builder: (_) => widget.adminMode ? const AdminPage() : const HomePage()),
                              (route) => false);
                            return;
                          }

                          setState(() { isSavingSession = true; });

                          try {
                            final practiceSeconds = await computePracticeSeconds();
                            await FirebasePaths.sessionDoc(
                              uid: uid, weekId: currentWeek!.weekId, sessionId: sessionId!,
                            ).update({
                              'duration': seconds,
                              'timeline': timeline.map((e) => {
                                'start': e.start, 'moving': e.moving, 'flagged': e.flagged,
                                'paused': e.paused, 'resolved': e.resolved, 'fraudulent': e.fraudulent,
                              }).toList(),
                              'waveform': waveform.map((e) => {'second': e.second, 'amplitude': e.amplitude}).toList(),
                              'endTime': DateTime.now(),
                              'practiceSeconds': practiceSeconds,
                            });
                            await FirebasePaths.weekDoc(uid: uid, weekId: currentWeek!.weekId).update({
                              'activeSession': false, 'currentOrgan': null, 'currentSessionId': null,
                            });
                            await recomputeWeekTotal();
                          } catch (e) {
                            debugPrint("Error updating session: $e");
                            await savePendingStopUpload();
                            await FirebasePaths.sessionDoc(
                              uid: uid, weekId: currentWeek!.weekId, sessionId: sessionId!,
                            ).update({'endedOffline': true});
                            if (mounted) setState(() { uploadPending = true; });
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                              duration: Duration(seconds: 8),
                              content: Text("No internet connection available. Practice end time saved locally and will upload when connected to the internet. Do not force close the app or you may lose your session."),
                            ));
                          }

                          if (!mounted) return;
                          Navigator.pushAndRemoveUntil(context,
                            MaterialPageRoute(builder: (_) => widget.adminMode ? const AdminPage() : const HomePage()),
                            (route) => false);
                        },
                        child: const Text("Stop Practice"),
                      ),

                      const SizedBox(height: 16),

                      // ── Metronome ──────────────────────────────────────
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _mmButton(label: '−', onTap: () => _mmStep(-1)),
                                const SizedBox(width: 10),
                                GestureDetector(
                                  onTap: _showMMNumberPad,
                                  child: Container(
                                    width: 58,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      border: Border.all(color: gold.withOpacity(0.4), width: 1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                    child: Text('$_mm',
                                        style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                _mmButton(label: '+', onTap: () => _mmStep(1)),
                                const SizedBox(width: 16),
                                _mmModeButton(label: 'Classic', active: _mmClassicMode,
                                    onTap: () => setState(() => _mmClassicMode = true)),
                                const SizedBox(width: 8),
                                _mmModeButton(label: '±1', active: !_mmClassicMode,
                                    onTap: () => setState(() => _mmClassicMode = false)),
                              ],
                            ),

                            const SizedBox(height: 12),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                GestureDetector(
                                  onTap: _onTargetTap,
                                  child: CustomPaint(
                                    size: const Size(64, 64),
                                    painter: _ConcentricCirclesPainter(gold),
                                  ),
                                ),
                                const SizedBox(width: 24),
                                GestureDetector(
                                  onTap: () => _mmToggle(),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: _mmRunning ? Colors.red : Colors.green,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      _mmRunning ? 'Stop' : 'Start',
                                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // ── End Metronome ───────────────────────────────────

                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 10),
                child: SvgPicture.asset('assets/Organ-Studio-LockupStacked-RGB.svg', height: 70),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _mmButton({required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(color: gold, borderRadius: BorderRadius.circular(6)),
        alignment: Alignment.center,
        child: Text(label, style: const TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _mmModeButton({required String label, required bool active, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active ? gold : Colors.grey.shade800,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label, style: TextStyle(
          color: active ? Colors.black : Colors.grey.shade400,
          fontSize: 13, fontWeight: FontWeight.bold,
        )),
      ),
    );
  }
}

class _ConcentricCirclesPainter extends CustomPainter {
  final Color accentColor;
  const _ConcentricCirclesPainter(this.accentColor);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final maxR = size.width / 2;
    const rings = 5;
    for (int i = rings; i >= 1; i--) {
      final r = maxR * i / rings;
      final paint = Paint()
        ..color = i.isOdd ? accentColor : const Color(0xFF1A1A1A)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(cx, cy), r, paint);
    }
  }

  @override
  bool shouldRepaint(_ConcentricCirclesPainter old) => old.accentColor != accentColor;
}