import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'login_page.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';

Future<Widget> getStartPage() async {
  final prefs = await SharedPreferences.getInstance();
  final uid = prefs.getString('uid');

  if (uid != null) {
    return const HomePage();
  } else {
    return const LoginPage();
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  final startPage = await getStartPage();

  runApp(MyApp(startPage));
}

const gold = Color(0xFFFFCD00);

class MyApp extends StatelessWidget {
  final Widget startPage;

  const MyApp(this.startPage, {super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: startPage,
      routes: {'/home': (context) => const HomePage()},
    );
  }
}

Future<String> getFirstName() async {
  final prefs = await SharedPreferences.getInstance();
  final name = prefs.getString('name') ?? "";
  debugPrint("Loaded name: $name");
  if (name.isEmpty) return "";

  return name.split(" ")[0];
}

Future<String> getUid() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString('uid') ?? "";
}

Future<Map<String, String>> getUserInfo() async {
  final prefs = await SharedPreferences.getInstance();

  return {
    'name': prefs.getString('name') ?? '',
    'degree': prefs.getString('degree') ?? '',
    'year': prefs.getString('year') ?? '',
    'semester': prefs.getString('semester') ?? '',
  };
}

// ---------------- HOME PAGE ----------------
//
//
//
//
// ---------------- HOME PAGE ----------------
//
//
//
//
// ---------------- HOME PAGE ----------------

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Timer? deviceHeartbeatTimer;

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
          mainAxisAlignment: MainAxisAlignment.spaceAround,
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
                      Text(
                        "${user['degree']} — ${user['year']} — ${user['semester']}",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            const Text(
              "Hawkeye Organist Practice App",
              style: TextStyle(fontSize: 22),
            ),

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

//
// ---------------- SELECTION ----------------
//
//
// ---------------- SELECTION ----------------
//
//
// ---------------- SELECTION ----------------
//
//
// ---------------- SELECTION ----------------
//

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

//
// ---------------- REVIEW ----------------
//
//
// ---------------- REVIEW ----------------
//
//
// ---------------- REVIEW ----------------
//
// ---------------- REVIEW ----------------
//

class ReviewPage extends StatelessWidget {
  const ReviewPage({super.key});

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

  Map<String, int> computeTotals(List<Segment> timeline, int seconds) {
    int practice = 0;
    int moving = 0;

    for (int i = 0; i < timeline.length; i++) {
      final current = timeline[i];

      int end = (i < timeline.length - 1) ? timeline[i + 1].start : seconds;

      int duration = end - current.start;

      if (current.moving) {
        moving += duration;
      } else {
        practice += duration;
      }
    }

    return {'practice': practice, 'moving': moving};
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Sessions")),
      body: FutureBuilder<String>(
        future: getUid(),
        builder: (context, uidSnapshot) {
          if (!uidSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final currentUid = uidSnapshot.data!;

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('sessions')
                .where('uid', isEqualTo: currentUid)
                .orderBy('startTime', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = snapshot.data!.docs;

              return Column(
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
                            Text(
                              "${user['degree']} — ${user['year']} — ${user['semester']}",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  Expanded(
                    child: ListView(
                      children: docs.map((doc) {
                        final s = doc.data() as Map<String, dynamic>;

                        final rawTimeline = s['timeline'];
                        final rawWaveform = s['waveform'];

                        List<Segment> timelineList = [];
                        List<WavePoint> waveformList = [];

                        if (rawTimeline != null && rawTimeline is List) {
                          timelineList = rawTimeline
                              .where((e) => e != null)
                              .map((e) {
                                final map = e as Map<String, dynamic>;

                                return Segment(
                                  map['start'] ?? 0,
                                  map['moving'] ?? false,
                                  flagged: map['flagged'] ?? false,
                                );
                              })
                              .toList();
                        }

                        if (rawWaveform != null && rawWaveform is List) {
                          waveformList = rawWaveform
                              .where((e) => e != null)
                              .map((e) {
                                final map = e as Map<String, dynamic>;

                                return WavePoint(
                                  map['second'] ?? 0,
                                  (map['amplitude'] ?? 0.0).toDouble(),
                                );
                              })
                              .toList();
                        }

                        final duration = s['duration'] ?? 0;
                        final totals = computeTotals(timelineList, duration);

                        return Padding(
                          padding: const EdgeInsets.all(10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Builder(
                                builder: (_) {
                                  final start = (s['startTime'] as Timestamp)
                                      .toDate();

                                  int h = start.hour % 12;

                                  if (h == 0) h = 12;

                                  final minute = start.minute
                                      .toString()
                                      .padLeft(2, '0');

                                  final suffix = start.hour >= 12 ? "pm" : "am";

                                  final startLabel = "$h:$minute$suffix";

                                  return Text(
                                    "${s['instrument']} — "
                                    "${formatDate(start)} — "
                                    "$startLabel — "
                                    "${formatDuration(duration)}",
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  );
                                },
                              ),

                              const SizedBox(height: 6),

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
                                            timelineList,
                                            duration,
                                            (s['startTime'] as Timestamp)
                                                .toDate(),
                                            fixedThreeHourScale: true,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              if (s['instrument'] == 'Other' &&
                                  waveformList.isNotEmpty) ...[
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
                                            painter: WaveformPainter(
                                              waveformList,
                                              duration,
                                              fixedThreeHourScale: true,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],

                              Text(
                                "Practice: ${formatHM(totals['practice']!)}     Moving: ${formatHM(totals['moving']!)}",
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

//
// ---------------- GRAPH ----------------
//
//
// ---------------- GRAPH ----------------
//

class Segment {
  final int start;
  final bool moving;
  final bool flagged;

  Segment(this.start, this.moving, {this.flagged = false});
}

class WavePoint {
  final int second;
  final double amplitude;

  WavePoint(this.second, this.amplitude);
}

class GraphPainter extends CustomPainter {
  final List<Segment> timeline;
  final int seconds;
  final DateTime startTime;

  final bool fixedThreeHourScale;

  GraphPainter(
    this.timeline,
    this.seconds,
    this.startTime, {
    this.fixedThreeHourScale = false,
  });

  double getVisibleSeconds() {
    if (fixedThreeHourScale) {
      return 3 * 3600;
    }

    if (seconds <= 45 * 60) {
      return 3600;
    }

    if (seconds <= 105 * 60) {
      return 7200;
    }

    return 10800;
  }

  double getX(double s, double width, double visibleSeconds) {
    const graphPadding = 18.0;

    return graphPadding + (s / visibleSeconds) * (width - (graphPadding * 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final visibleSeconds = getVisibleSeconds();

    final paint = Paint()..style = PaintingStyle.fill;

    final axisPaint = Paint()..strokeWidth = 1;

    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    final safeTimeline = timeline.isEmpty ? [Segment(0, false)] : timeline;

    final graphTop = 6.0;
    final graphBottom = size.height - 20;

    double getTop(bool moving) {
      return moving ? graphTop : graphTop + (graphBottom - graphTop) * 0.5;
    }

    const tickInterval = 15 * 60;

    for (int t = 0; t <= visibleSeconds; t += tickInterval) {
      final x = getX(t.toDouble(), size.width, visibleSeconds);

      canvas.drawLine(
        Offset(x, graphTop),
        Offset(x, graphBottom),
        axisPaint..color = Colors.black12,
      );

      canvas.drawLine(
        Offset(x, graphBottom),
        Offset(x, graphBottom + 4),
        axisPaint..color = Colors.black54,
      );

      if (t % 3600 == 0) {
        final time = startTime.add(Duration(seconds: t));

        int h = time.hour % 12;

        if (h == 0) h = 12;

        final m = time.minute.toString().padLeft(2, '0');

        final suffix = time.hour >= 12 ? "pm" : "am";

        final label = "$h:$m$suffix";

        textPainter.text = TextSpan(
          text: label,
          style: const TextStyle(fontSize: 9, color: Colors.black),
        );

        textPainter.layout();

        textPainter.paint(
          canvas,
          Offset(x - textPainter.width / 2, graphBottom + 3),
        );
      }
    }

    for (int i = 0; i < safeTimeline.length; i++) {
      final seg = safeTimeline[i];

      int end = (i < safeTimeline.length - 1)
          ? safeTimeline[i + 1].start
          : seconds;

      double x1 = getX(seg.start.toDouble(), size.width, visibleSeconds);

      double x2 = getX(end.toDouble(), size.width, visibleSeconds);

      if (x2 - x1 < 2) {
        x2 = x1 + 2;
      }

      if (seg.moving && (x2 - x1) > 3) {
        x2 = x1 + 3;
      }

      final rect = Rect.fromLTRB(x1, getTop(seg.moving), x2, graphBottom);

      paint.color = seg.moving
          ? gold
          : seg.flagged
          ? Colors.red
          : Colors.green;

      canvas.drawRect(rect, paint);
    }

    canvas.drawRect(
      Rect.fromLTRB(18, graphTop, size.width - 18, graphBottom),
      Paint()
        ..style = PaintingStyle.stroke
        ..color = Colors.black,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class WaveformPainter extends CustomPainter {
  final List<WavePoint> waveform;
  final int seconds;

  final bool fixedThreeHourScale;

  WaveformPainter(
    this.waveform,
    this.seconds, {
    this.fixedThreeHourScale = false,
  });

  double getVisibleSeconds() {
    if (fixedThreeHourScale) {
      return 3 * 3600;
    }

    if (seconds <= 45 * 60) {
      return 3600;
    }

    if (seconds <= 105 * 60) {
      return 7200;
    }

    return 10800;
  }

  double getX(double s, double width, double visibleSeconds) {
    const graphPadding = 18.0;

    return graphPadding + (s / visibleSeconds) * (width - (graphPadding * 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final visibleSeconds = getVisibleSeconds();

    final waveformPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke;

    final gridPaint = Paint()
      ..color = Colors.black12
      ..strokeWidth = 1;

    final centerY = size.height / 2;

    final graphTop = 6.0;
    final graphBottom = size.height - 6;

    // vertical grid lines
    const tickInterval = 15 * 60;

    for (int t = 0; t <= visibleSeconds; t += tickInterval) {
      final x = getX(t.toDouble(), size.width, visibleSeconds);

      canvas.drawLine(Offset(x, graphTop), Offset(x, graphBottom), gridPaint);
    }

    // border
    canvas.drawRect(
      Rect.fromLTRB(18, graphTop, size.width - 18, graphBottom),
      borderPaint,
    );

    // center line
    canvas.drawLine(
      Offset(18, centerY),
      Offset(size.width - 18, centerY),
      borderPaint,
    );

    if (waveform.isEmpty) return;

    for (final point in waveform) {
      final x = getX(point.second.toDouble(), size.width, visibleSeconds);

      final ampHeight = point.amplitude * ((graphBottom - graphTop) * 0.42);

      const sliceWidth = 1.5;

      final rect = Rect.fromLTRB(
        x,
        centerY - ampHeight,
        x + sliceWidth,
        centerY + ampHeight,
      );

      canvas.drawRect(rect, waveformPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

//
// ---------------- PRACTICE ----------------
//
//
// ---------------- PRACTICE ----------------
//
//
// ---------------- PRACTICE ----------------
//
//
// ---------------- PRACTICE ----------------
//

class PracticePage extends StatefulWidget {
  final String instrument;
  final bool initiatedOverlap;

  const PracticePage({
    super.key,
    required this.instrument,
    this.initiatedOverlap = false,
  });

  @override
  State<PracticePage> createState() => _PracticePageState();
}

class _PracticePageState extends State<PracticePage> {
  late Timer timer;
  Timer? heartbeatTimer;
  StreamSubscription? overlapSubscription;
  int seconds = 0;

  DateTime? startTime;

  List<Segment> timeline = [];
  bool isMoving = false;
  bool isFlagged = false;
  bool initiatedOverlap = false;

  List<WavePoint> waveform = [];

  final AudioRecorder recorder = AudioRecorder();

  Timer? amplitudeTimer;

  double currentAmplitude = 0;

  String uid = "";
  String name = "";
  String role = "";
  String? sessionId;

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
    final doc = await FirebaseFirestore.instance.collection('sessions').add({
      'uid': uid,
      'name': name,
      'instrument': widget.instrument,
      'startTime': startTime,
      'endTime': null,
      'status': 'normal',
      'lastHeartbeat': DateTime.now(),

      'timeline': timeline
          .map(
            (e) => {'start': e.start, 'moving': e.moving, 'flagged': e.flagged},
          )
          .toList(),
    });

    sessionId = doc.id;
  }

  Future<void> syncTimeline() async {
    if (sessionId == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('sessions')
          .doc(sessionId)
          .update({
            'timeline': timeline
                .map(
                  (e) => {
                    'start': e.start,
                    'moving': e.moving,
                    'flagged': e.flagged,
                  },
                )
                .toList(),
          });
    } catch (e) {
      debugPrint("Timeline sync failed: $e");
    }
  }

  Future<void> startOverlapWatcher() async {
    overlapSubscription = FirebaseFirestore.instance
        .collection('sessions')
        .where('instrument', isEqualTo: widget.instrument)
        .where('endTime', isNull: true)
        .snapshots()
        .listen((snapshot) {
          bool overlapNow = snapshot.docs.any((doc) {
            return doc.id != sessionId;
          });

          if (overlapNow != isFlagged) {
            setState(() {
              isFlagged = overlapNow;

              timeline.add(
                Segment(seconds, isMoving, flagged: overlapNow && !isMoving),
              );
            });

            syncTimeline();

            if (isFlagged && !initiatedOverlap) {
              showOverlapDialog();
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

                if (!mounted) return;

                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const HomePage()),
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
    if (sessionId == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('sessions')
          .doc(sessionId)
          .update({'lastHeartbeat': DateTime.now()});
    } catch (e) {
      debugPrint("Heartbeat update failed: $e");
    }
  }

  Future<void> initializePractice() async {
    await loadUser();

    startTime = DateTime.now();
    initiatedOverlap = widget.initiatedOverlap;
    timeline = [Segment(0, false, flagged: false)];

    await createSession();
    await startOverlapWatcher();
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

    for (int i = 0; i < timeline.length; i++) {
      final current = timeline[i];

      int end = (i < timeline.length - 1) ? timeline[i + 1].start : seconds;

      int duration = end - current.start;

      if (current.moving) {
        moving += duration;
      } else {
        practice += duration;
      }
    }

    return {'practice': practice, 'moving': moving};
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

  @override
  void initState() {
    super.initState();

    initializePractice();
    initializeWaveform();
    heartbeatTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      sendHeartbeat();
      syncTimeline();
    });

    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;

      setState(() {
        seconds++;
      });
    });

    accelerometerEventStream().listen((event) {
      if (!mounted) return;

      double mag = (event.x * event.x + event.y * event.y + event.z * event.z);

      bool movingNow = mag > 120;

      if (movingNow != isMoving) {
        setState(() {
          isMoving = movingNow;
          timeline.add(
            Segment(seconds, movingNow, flagged: isFlagged && !movingNow),
          );
          syncTimeline();
        });
      }
    });
  }

  @override
  void dispose() {
    timer.cancel();

    amplitudeTimer?.cancel();

    heartbeatTimer?.cancel();

    overlapSubscription?.cancel();

    recorder.stop();

    recorder.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (startTime == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(automaticallyImplyLeading: false, title: const Text("")),
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
                              Text(
                                "${user['degree']} — ${user['year']} — ${user['semester']}",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
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
                              padding: const EdgeInsets.only(left: 2, right: 2),
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

                        const Text("practice", style: TextStyle(fontSize: 11)),

                        const SizedBox(width: 14),

                        Container(width: 10, height: 10, color: gold),

                        const SizedBox(width: 4),

                        const Text("moving", style: TextStyle(fontSize: 11)),

                        const SizedBox(width: 14),

                        Container(width: 10, height: 10, color: Colors.red),

                        const SizedBox(width: 4),

                        const Text("flagged", style: TextStyle(fontSize: 11)),
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

                    Text(
                      "Practice: ${formatHM(computeTotals()['practice']!)}     Moving: ${formatHM(computeTotals()['moving']!)}",
                      style: const TextStyle(fontSize: 14),
                    ),

                    const SizedBox(height: 10),

                    Text(
                      formatClock(seconds),
                      style: const TextStyle(fontSize: 28),
                    ),

                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: gold,
                        foregroundColor: Colors.black,
                      ),
                      onPressed: () async {
                        timer.cancel();
                        try {
                          await FirebaseFirestore.instance
                              .collection('sessions')
                              .doc(sessionId)
                              .update({
                                'duration': seconds,
                                'timeline': timeline
                                    .map(
                                      (e) => {
                                        'start': e.start,
                                        'moving': e.moving,
                                        'flagged': e.flagged,
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
                              });
                        } catch (e) {
                          debugPrint("Error updating session: $e");
                        }
                        if (!mounted) return;

                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(builder: (_) => const HomePage()),
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
                height: 101
              ),
            ),
          ],
        ),
      ),
    );
  }
}
