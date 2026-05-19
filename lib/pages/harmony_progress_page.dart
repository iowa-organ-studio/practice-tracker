import 'package:flutter/material.dart';

import '../widgets/admin_header.dart';

import '../data/harmony_competencies.dart';

import '../models/harmony_competency.dart';
import '../models/harmony_state.dart';
import '../models/harmony_wedge.dart';

import '../theme/app_colors.dart';
import 'dart:math';
import '../services/user_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_svg/flutter_svg.dart';

class HarmonyProgressPage extends StatefulWidget {
  const HarmonyProgressPage({super.key});

  @override
  State<HarmonyProgressPage> createState() => _HarmonyProgressPageState();
}

class _HarmonyProgressPageState extends State<HarmonyProgressPage> {
  Future<List<HarmonyCompetency>> loadCompetencies() async {
    final uid = await getUid();

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();

    final user = userDoc.data() ?? {};

    final progress = Map<String, dynamic>.from(user['harmonyProgress'] ?? {});

    return harmonyCompetencies.map((competency) {
      final updatedWedges = Map<HarmonyWedge, HarmonyState>.from(
        competency.wedges,
      );

      final competencyData = progress[competency.id] ?? {};

      for (final wedge in HarmonyWedge.values) {
        final wedgeKey = wedge.name;

        final wedgeData = competencyData[wedgeKey] ?? {};

        final embellished = wedgeData['embellished'] == true;

        final complete = wedgeData['complete'] == true;

        if (embellished) {
          updatedWedges[wedge] = HarmonyState.embellished;
        } else if (complete) {
          updatedWedges[wedge] = HarmonyState.complete;
        }
      }

      return HarmonyCompetency(
        id: competency.id,

        title: competency.title,

        centerIcon: competency.centerIcon,

        wedges: updatedWedges,
      );
    }).toList();
  }

  bool competencyLocked(List<HarmonyCompetency> competencies, int index) {
    if (index == 0) {
      return false;
    }

    final previous = competencies[index - 1];

    return !previous.wedges.values.any(
      (s) => s == HarmonyState.complete || s == HarmonyState.embellished,
    );
  }

  bool competencyMastered(HarmonyCompetency competency) {
    return competency.wedges.values.every((s) => s == HarmonyState.embellished);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<HarmonyCompetency>>(
      future: loadCompetencies(),

      builder: (context, competencySnapshot) {
        if (!competencySnapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final competencies = competencySnapshot.data!;

        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                FutureBuilder<Map<String, String>>(
                  future: getUserInfo(),

                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const SizedBox();
                    }

                    final user = snapshot.data!;

                    return Container(
                      width: double.infinity,

                      color: Colors.black,

                      padding: const EdgeInsets.all(12),

                      child: RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: "${user['name'] ?? ''} ",

                              style: const TextStyle(
                                color: gold,

                                fontSize: 18,

                                fontWeight: FontWeight.bold,
                              ),
                            ),

                            const TextSpan(
                              text: "Harmony Progress",

                              style: TextStyle(
                                color: Colors.white,

                                fontSize: 18,

                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 12),

                const Text(
                  "Harmony Progress",

                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),

                Expanded(
                  child: ListView.builder(
                    itemCount: competencies.length,

                    itemBuilder: (context, index) {
                      final competency = competencies[index];

                      final locked = competencyLocked(competencies, index);

                      final mastered = competencyMastered(competency);

                      return HarmonyCompetencyCard(
                        competency: competency,

                        number: index + 1,

                        locked: locked,

                        mastered: mastered,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class HarmonyCompetencyCard extends StatelessWidget {
  final HarmonyCompetency competency;

  final int number;
  final bool locked;
  final bool mastered;

  const HarmonyCompetencyCard({
    super.key,
    required this.competency,
    required this.number,
    required this.locked,
    required this.mastered,
  });

  String wedgeIcon(HarmonyWedge wedge) {
    switch (wedge) {
      case HarmonyWedge.hands:
        return "P̶e̶d̶a̶l̶";

      case HarmonyWedge.keys3:
        return "3♯♭";

      case HarmonyWedge.keys5:
        return "5♯♭";

      case HarmonyWedge.keys7:
        return "7♯♭";

      case HarmonyWedge.hymnTexture:
        return "𝄞 = 𝄢";

      case HarmonyWedge.soloSopranoTexture:
        return "𝄞";

      case HarmonyWedge.soloTenorTexture:
        return "𝄢";

      case HarmonyWedge.peglegTexture:
        return "👢";
    }
  }

  Color wedgeColor(HarmonyState state) {
    switch (state) {
      case HarmonyState.incomplete:
        return Colors.grey;

      case HarmonyState.complete:
        return gold;

      case HarmonyState.embellished:
        return Colors.black;
    }
  }

  Color iconColor(HarmonyState state) {
    switch (state) {
      case HarmonyState.incomplete:
        return Colors.black;

      case HarmonyState.complete:
        return Colors.black;

      case HarmonyState.embellished:
        return gold;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Card(
          elevation: 3,

          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),

          child: Padding(
            padding: const EdgeInsets.all(14),

            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                SizedBox(
                  width: MediaQuery.of(context).size.width * 0.55,

                  height: MediaQuery.of(context).size.width * 0.55,

                  child: Stack(
                    alignment: Alignment.center,

                    children: [
                      locked
                          ? Align(
                              alignment: Alignment.centerLeft,

                              child: Padding(
                                padding: const EdgeInsets.only(left: 18),

                                child: SvgPicture.asset(
                                  'assets/Lock_Icon.svg',

                                  width: 110,
                                  height: 110,
                                ),
                              ),
                            )
                          : mastered
                          ? Align(
                              alignment: Alignment.centerLeft,

                              child: Padding(
                                padding: const EdgeInsets.only(left: 18),

                                child: SvgPicture.asset(
                                  'assets/Bach_Seal.svg',

                                  width: 180,
                                  height: 180,
                                ),
                              ),
                            )
                          : CustomPaint(
                              size: Size.infinite,

                              painter: ExpandedHarmonyPainter(
                                competency: competency,

                                wedgeColor: wedgeColor,

                                iconColor: iconColor,

                                wedgeIcon: wedgeIcon,
                              ),
                            ),
                      locked || mastered
                          ? const SizedBox()
                          : Container(
                              width: 90,
                              height: 90,

                              decoration: const BoxDecoration(
                                color: Colors.white,

                                shape: BoxShape.circle,
                              ),

                              alignment: Alignment.center,

                              child: competency.centerIcon == 'CLOSE'
                                  ? SvgPicture.asset(
                                      'assets/CLOSE.svg',

                                      width: 48,
                                      height: 48,
                                    )
                                  : competency.centerIcon == 'FAR'
                                  ? SvgPicture.asset(
                                      'assets/FAR.svg',

                                      width: 48,
                                      height: 48,
                                    )
                                  : competency.centerIcon == 'PED'
                                  ? SvgPicture.asset(
                                      'assets/Ped.svg',

                                      width: 48,
                                      height: 48,
                                    )
                                  : Text(
                                      competency.centerIcon,

                                      textAlign: TextAlign.center,

                                      style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                    ],
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: Text(
                    competency.title,

                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        Positioned(
          top: 16,
          left: 24,

          child: Text(
            "$number",

            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}

class ExpandedHarmonyPainter extends CustomPainter {
  final HarmonyCompetency competency;

  final Color Function(HarmonyState) wedgeColor;

  final Color Function(HarmonyState) iconColor;

  final String Function(HarmonyWedge) wedgeIcon;

  ExpandedHarmonyPainter({
    required this.competency,
    required this.wedgeColor,
    required this.iconColor,
    required this.wedgeIcon,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);

    final wedges = [
      HarmonyWedge.hands,

      HarmonyWedge.hymnTexture,

      HarmonyWedge.soloSopranoTexture,

      HarmonyWedge.soloTenorTexture,

      HarmonyWedge.peglegTexture,

      HarmonyWedge.keys3,

      HarmonyWedge.keys5,

      HarmonyWedge.keys7,
    ];

    for (int i = 0; i < 8; i++) {
      final wedge = wedges[i];

      final state = competency.wedges[wedge]!;

      final paint = Paint()..color = wedgeColor(state);

      final startAngle = ((i * 45) + 180) * 3.1415926535 / 180;

      final sweep = 45 * 3.1415926535 / 180;

      canvas.drawArc(rect, startAngle, sweep, true, paint);

      canvas.drawArc(
        rect,
        startAngle,
        sweep,
        true,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = Colors.black,
      );

      final angle = startAngle + sweep / 2;

      final radius = size.width * 0.34;

      final x = size.width / 2 + radius * cos(angle);

      final y = size.height / 2 + radius * sin(angle);

      final tp = TextPainter(textDirection: TextDirection.ltr);

      tp.text = TextSpan(
        text: wedgeIcon(wedge),

        style: TextStyle(
          color: iconColor(state),

          fontSize: 18,

          fontWeight: FontWeight.bold,
        ),
      );

      tp.layout();

      tp.paint(canvas, Offset(x - tp.width / 2, y - tp.height / 2));
    }

    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      size.width * 0.18,

      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}
