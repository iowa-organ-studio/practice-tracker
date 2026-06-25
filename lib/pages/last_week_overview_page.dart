import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../widgets/admin_header.dart';

import 'review_page.dart';
import '../services/semester_service.dart';
import '../services/cusp_service.dart';
import '../theme/app_colors.dart';

class LastWeekOverviewPage extends StatefulWidget {
  const LastWeekOverviewPage({super.key});

  @override
  State<LastWeekOverviewPage> createState() => _LastWeekOverviewPageState();
}

class _LastWeekOverviewPageState extends State<LastWeekOverviewPage> {
  int? _previousWeekNumber;
  bool _loadingTitle = true;

  @override
  void initState() {
    super.initState();
    _loadPreviousWeekNumber();
  }

  /// Mirrors the "which week is this overview actually showing" logic
  /// used by getLastWeekColor, so the title always matches the data.
  Future<void> _loadPreviousWeekNumber() async {
    final semester = await getActiveSemester();

    if (semester == null) {
      if (mounted) setState(() => _loadingTitle = false);
      return;
    }

    final now = DateTime.now();
    int currentWeekIndex = -1;

    for (int i = 0; i < semester.weeks.length; i++) {
      final week = semester.weeks[i];
      if (now.isAfter(week.start) && now.isBefore(week.end)) {
        currentWeekIndex = i;
        break;
      }
    }

    if (!mounted) return;

    if (currentWeekIndex <= 0) {
      // Still in week 1 — no previous week to show.
      setState(() {
        _previousWeekNumber = null;
        _loadingTitle = false;
      });
      return;
    }

    final previousWeek = semester.weeks[currentWeekIndex - 1];

    setState(() {
      _previousWeekNumber = previousWeek.weekNumber;
      _loadingTitle = false;
    });
  }

  int yearRank(String year) {
    switch (year) {
      case '4':
        return 4;
      case '3':
        return 3;
      case '2':
        return 2;
      case '1':
        return 1;
      default:
        return 0;
    }
  }

  int degreeRank(String degree) {
    switch (degree) {
      case 'DMA':
        return 1;

      case 'MA':
        return 2;

      case 'BM':
      case 'BA':
        return 3;

      default:
        return 4;
    }
  }

  Future<Color> getLastWeekColor(String uid, int minimumMinutes) async {
    final semester = await getActiveSemester();

    if (semester == null) {
      return Colors.grey;
    }

    final now = DateTime.now();

    int currentWeekIndex = -1;

    for (int i = 0; i < semester.weeks.length; i++) {
      final week = semester.weeks[i];

      if (now.isAfter(week.start) && now.isBefore(week.end)) {
        currentWeekIndex = i;
        break;
      }
    }

    // still in week 1
    if (currentWeekIndex <= 0) {
      return Colors.grey;
    }

    final previousWeek = semester.weeks[currentWeekIndex - 1];

    if (previousWeek.offWeek) {
      return Colors.black;
    }

    final minutes = await getPracticeMinutesForWeek(
      uid: uid,
      week: previousWeek,
    );

    final lastFrozenWeekNumber = await getLastFrozenWeekNumber(semester);

    final isTopPracticer = previousWeek.weekNumber <= lastFrozenWeekNumber
        ? await getIsGoldStar(uid: uid, weekId: previousWeek.weekId)
        : uid == await getTopPracticerUidForWeek(week: previousWeek);

    if (isTopPracticer) {
      return gold;
    }

    if (minutes >= minimumMinutes) {
      return Colors.green;
    }

    return Colors.red;
  }

  String get _titleText {
    if (_loadingTitle) return "Loading...";
    if (_previousWeekNumber == null) return "No Previous Week";
    return "Week ${_previousWeekNumber.toString().padLeft(2, '0')} Overview";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const AdminHeader(title: "ADMIN"),

            const SizedBox(height: 16),

            Text(
              _titleText,

              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),

            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .snapshots(),

                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final docs = snapshot.data!.docs.where((d) {
                    final data = d.data() as Map<String, dynamic>;

                    return (data['role'] ?? 'student') != 'admin';
                  }).toList();

                  docs.sort((a, b) {
                    final ad = a.data() as Map<String, dynamic>;

                    final bd = b.data() as Map<String, dynamic>;

                    final adDegree = ad['degree'] ?? 'Other';

                    final bdDegree = bd['degree'] ?? 'Other';

                    final adYear = ad['year'] ?? '';

                    final bdYear = bd['year'] ?? '';

                    final degreeCompare = degreeRank(
                      adDegree,
                    ).compareTo(degreeRank(bdDegree));

                    if (degreeCompare != 0) {
                      return degreeCompare;
                    }

                    final yearCompare = yearRank(
                      bdYear,
                    ).compareTo(yearRank(adYear));

                    if (yearCompare != 0) {
                      return yearCompare;
                    }

                    final an = ad['name'] ?? '';

                    final bn = bd['name'] ?? '';

                    return an.compareTo(bn);
                  });

                  return ListView(
                    children: docs.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;

                      return Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),

                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),

                        decoration: BoxDecoration(
                          color: Colors.white,

                          border: Border.all(color: Colors.black, width: 2),

                          borderRadius: BorderRadius.circular(10),

                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 3,
                              offset: Offset(1, 2),
                            ),
                          ],
                        ),

                        child: Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () {
                                  Navigator.push(
                                    context,

                                    MaterialPageRoute(
                                      builder: (_) => ReviewPage(
                                        overrideUid: data['uid'] ?? '',
                                      ),
                                    ),
                                  );
                                },

                                child: Text(
                                  data['name'] ?? 'Unknown',

                                  style: const TextStyle(fontSize: 18),
                                ),
                              ),
                            ),

                            FutureBuilder<Color>(
                              future: getLastWeekColor(
                                data['uid'] ?? '',
                                data['minimumWeeklyMinutes'] ?? 0,
                              ),

                              builder: (context, colorSnapshot) {
                                final ledColor =
                                    colorSnapshot.data ?? Colors.grey;

                                final isStar = ledColor == gold;

                                return isStar
                                    ? Stack(
                                        alignment: Alignment.center,

                                        children: [
                                          const Icon(
                                            Icons.star,

                                            color: Colors.amber,

                                            size: 28,
                                          ),

                                          Container(
                                            width: 14,
                                            height: 14,

                                            decoration: BoxDecoration(
                                              color: ledColor,

                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                        ],
                                      )
                                    : Container(
                                        width: 18,

                                        height: 18,

                                        decoration: BoxDecoration(
                                          color: ledColor,

                                          shape: BoxShape.circle,
                                        ),
                                      );
                              },
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}