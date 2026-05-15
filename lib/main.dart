import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'login_page.dart';

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
  List<Map<String, dynamic>> sessions = [];

  @override
  void initState() {
    super.initState();
    loadSessions();
  }

  Future<void> loadSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('sessions');

    if (data != null) {
      setState(() {
        sessions = List<Map<String, dynamic>>.from(jsonDecode(data));
      });
    }
  }

  Future<void> clearOldSessions() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('sessions');
  }

  Future<void> saveSessions() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('sessions', jsonEncode(sessions));
  }

  String formatTime(int s) {
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    return "$h h $m m";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
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
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SelectionPage(),
                  ),
                );

                if (result != null) {
                  sessions.add({
                    'duration': result['duration'],
                    'timeline': result['timeline'],
                    'date': DateTime.now().toIso8601String(),
                    'instrument': result['instrument'],
                  });

                  await saveSessions();
                  setState(() {});
                }
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
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: builders.map((b) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GestureDetector(
                onTap: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PracticePage(instrument: b),
                    ),
                  );
                  Navigator.pop(context, result);
                },
                child: Container(
                  width: 220,
                  padding: const EdgeInsets.all(14),
                  alignment: Alignment.center,
                  color: Colors.grey[700],
                  child: Text(b, style: const TextStyle(color: gold)),
                ),
              ),
            );
          }).toList(),
        ),
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
    return "$h h $m m";
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

                        final timelineList = (s['timeline'] as List)
                            .map((e) => Segment(e['start'], e['moving']))
                            .toList();

                        final duration = s['duration'] ?? 0;
                        final totals = computeTotals(timelineList, duration);

                        return Padding(
                          padding: const EdgeInsets.all(10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "${s['instrument']} — ${formatDuration(duration)}",
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),

                              const SizedBox(height: 6),

                              SizedBox(
                                height: 120,
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 70,
                                      child: LayoutBuilder(
                                        builder: (context, constraints) {
                                          final h = constraints.maxHeight;

                                          return Stack(
                                            children: [
                                              Positioned(
                                                top: h * 0.15,
                                                right: 0,
                                                child: const Text(
                                                  "moving",
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                  ),
                                                ),
                                              ),
                                              Positioned(
                                                top: h * 0.70,
                                                right: 0,
                                                child: const Text(
                                                  "practice",
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          );
                                        },
                                      ),
                                    ),

                                    const SizedBox(width: 8),

                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                        ),
                                        child: CustomPaint(
                                          size: Size.infinite,
                                          painter: GraphPainter(
                                            timelineList,
                                            duration,
                                            (s['startTime'] as Timestamp)
                                                .toDate(),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  "Practice: ${formatHM(totals['practice']!)}     Moving: ${formatHM(totals['moving']!)}",
                                  style: const TextStyle(fontSize: 12),
                                ),
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

  Segment(this.start, this.moving);
}

class GraphPainter extends CustomPainter {
  final List<Segment> timeline;
  final int seconds;
  final DateTime startTime;

  GraphPainter(this.timeline, this.seconds, this.startTime);

  static const maxSeconds = 3 * 3600;

  double getX(double s, double width) {
    const rightPadding = 50.0; // increase this
    return (s / maxSeconds) * (width - rightPadding);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    final axisPaint = Paint()
      ..color = Colors.black54
      ..strokeWidth = 1;

    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    final safeTimeline = timeline.isEmpty ? [Segment(0, false)] : timeline;

    final graphTop = 10.0;
    final graphBottom = size.height - 25; // leave space for labels

    double getTop(bool moving) =>
        moving ? graphTop : graphTop + (graphBottom - graphTop) * 0.5;

    // ---------------- DRAW GRID + TICKS ----------------
    const tickInterval = 15 * 60; // every 15 minutes

    for (int t = 0; t <= maxSeconds; t += tickInterval) {
      final x = getX(t.toDouble(), size.width);

      // vertical grid line
      canvas.drawLine(
        Offset(x, graphTop),
        Offset(x, graphBottom),
        axisPaint..color = Colors.black12,
      );

      // tick
      canvas.drawLine(
        Offset(x, graphBottom),
        Offset(x, graphBottom + 5),
        axisPaint..color = Colors.black54,
      );

      // label every hour
      if (t % 3600 == 0) {
        final time = startTime.add(Duration(seconds: t));

        int h = time.hour % 12;
        if (h == 0) h = 12;
        final m = time.minute.toString().padLeft(2, '0');
        final suffix = time.hour >= 12 ? "pm" : "am";

        final label = "$h:$m$suffix";

        textPainter.text = TextSpan(
          text: label,
          style: const TextStyle(fontSize: 10, color: Colors.black),
        );

        textPainter.layout();

        textPainter.paint(
          canvas,
          Offset(x - textPainter.width / 2, graphBottom + 6),
        );
      }
    }

    // ---------------- DRAW BARS ----------------
    for (int i = 0; i < safeTimeline.length; i++) {
      final seg = safeTimeline[i];

      int end = (i < safeTimeline.length - 1)
          ? safeTimeline[i + 1].start
          : seconds;

      double x1 = getX(seg.start.toDouble(), size.width);
      double x2 = getX(end.toDouble(), size.width);

      if (x2 - x1 < 2) x2 = x1 + 2;

      final rect = Rect.fromLTRB(x1, getTop(seg.moving), x2, graphBottom);

      paint.color = seg.moving ? gold : Colors.green;
      canvas.drawRect(rect, paint);
    }

    // ---------------- BORDER ----------------
    const rightPadding = 50.0;

    canvas.drawRect(
      Rect.fromLTRB(0, graphTop, size.width - rightPadding, graphBottom),
      Paint()
        ..style = PaintingStyle.stroke
        ..color = Colors.black,
    );
  } // ✅ THIS CLOSES paint()

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

  const PracticePage({super.key, required this.instrument});

  @override
  State<PracticePage> createState() => _PracticePageState();
}

class _PracticePageState extends State<PracticePage> {
  late Timer timer;
  int seconds = 0;

  late DateTime startTime;

  List<Segment> timeline = [Segment(0, false)];
  bool isMoving = false;

  String uid = "";
  String name = "";
  String role = "";

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
    return "$h h $m m";
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

  @override
  void initState() {
    super.initState();

    loadUser(); // ✅ load UID once

    startTime = DateTime.now();

    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        seconds++;
      });
    });

    accelerometerEvents.listen((event) {
      if (!mounted) return;

      double mag = (event.x * event.x + event.y * event.y + event.z * event.z);

      bool movingNow = mag > 120;

      if (movingNow != isMoving) {
        setState(() {
          isMoving = movingNow;
          timeline.add(Segment(seconds, isMoving));
        });
      }
    });
  }

  @override
  void dispose() {
    timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                          "${formatDate(startTime)} --- ${widget.instrument}",
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    SizedBox(
                      height: 120,
                      child: Row(
                        children: [
                          SizedBox(
                            width: 70,
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final h = constraints.maxHeight;

                                return Stack(
                                  children: [
                                    Positioned(
                                      top: h * 0.25,
                                      right: 0,
                                      child: const Text(
                                        "moving",
                                        style: TextStyle(fontSize: 10),
                                      ),
                                    ),
                                    Positioned(
                                      top: h * 0.75,
                                      right: 0,
                                      child: const Text(
                                        "practice",
                                        style: TextStyle(fontSize: 10),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              child: CustomPaint(
                                size: Size.infinite,
                                painter: GraphPainter(
                                  timeline,
                                  seconds,
                                  startTime,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 10),

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
                              .add({
                                'uid': uid,
                                'name': name,
                                'instrument': widget.instrument,
                                'duration': seconds,
                                'timeline': timeline
                                    .map(
                                      (e) => {
                                        'start': e.start,
                                        'moving': e.moving,
                                      },
                                    )
                                    .toList(),
                                'startTime': startTime,
                                'endTime': DateTime.now(),
                                'status': 'normal',
                              });
                        } catch (e) {
                          debugPrint("Error saving session: $e");
                        }

                        Navigator.pop(context, {
                          'duration': seconds,
                          'timeline': timeline
                              .map(
                                (e) => {'start': e.start, 'moving': e.moving},
                              )
                              .toList(),
                          'instrument': widget.instrument,
                        });
                      },
                      child: const Text("Stop Practice"),
                    ),
                  ],
                ),
              ),
            ),
            // LOGO BOTTOM
            Padding(
              padding: const EdgeInsets.all(20),
              child: SvgPicture.asset(
                'assets/Organ-Studio-LockupStacked-RGB.svg',
                height: 55,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
