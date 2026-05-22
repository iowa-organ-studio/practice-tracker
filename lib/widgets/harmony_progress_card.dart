import 'package:flutter/material.dart';
import '../data/harmony_competencies.dart';
import '../models/harmony_competency.dart';
import '../models/harmony_state.dart';

import '../models/harmony_wedge.dart';
import '../pages/harmony_progress_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/user_service.dart';
import 'package:flutter_svg/flutter_svg.dart';

class HarmonyProgressCard extends StatefulWidget {
  const HarmonyProgressCard({super.key});

  @override
  State<HarmonyProgressCard> createState() => _HarmonyProgressCardState();
}

class _HarmonyProgressCardState extends State<HarmonyProgressCard> {
  int refreshCounter = 0;

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

  Future<List<HarmonyCompetency>> loadCompetencies() async {
    final uid = await getUid();

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();

    if (!snapshot.exists) {
      return harmonyCompetencies;
    }

    final user = snapshot.data()!;

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

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<HarmonyCompetency>>(
      future: loadCompetencies().then((v) => v),

      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox();
        }

        final competencies = snapshot.data!;

        return InkWell(
          onTap: () async {
            await Navigator.push(
              context,

              MaterialPageRoute(builder: (_) => const HarmonyProgressPage()),
            );

            if (mounted) {
              setState(() {
                refreshCounter++;
              });
            }
          },

          child: Card(
            elevation: 3,

            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),

            child: Padding(
              padding: const EdgeInsets.all(10),

              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,

                children: [
                  const Text(
                    "Harmony Progress",

                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 8),

                  Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,

                        children: List.generate(9, (index) {
                          final competency = competencies[index];

                          final locked = competencyLocked(competencies, index);

                          final mastered = competencyMastered(competency);

                          return locked
                              ? SizedBox(
                                  width: 30,
                                  height: 44,

                                  child: Column(
                                    children: [
                                      Text(
                                        "${index + 1}",

                                        style: const TextStyle(
                                          fontSize: 8,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),

                                      const SizedBox(height: 2),

                                      SvgPicture.asset(
                                        'assets/Lock_Icon.svg',

                                        width: 26,
                                        height: 26,
                                      ),
                                    ],
                                  ),
                                )
                              : mastered
                              ? SizedBox(
                                  width: 30,
                                  height: 44,

                                  child: Column(
                                    children: [
                                      Text(
                                        "${index + 1}",

                                        style: const TextStyle(
                                          fontSize: 8,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),

                                      const SizedBox(height: 2),

                                      SvgPicture.asset(
                                        'assets/Bach_Seal.svg',

                                        width: 31,
                                        height: 31,
                                      ),
                                    ],
                                  ),
                                )
                              : HarmonyWheel(
                                  competency: competency,

                                  number: index + 1,
                                );
                        }),
                      ),

                      const SizedBox(height: 14),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,

                        children: List.generate(9, (index) {
                          final competency = competencies[index + 9];

                          final locked = competencyLocked(
                            competencies,
                            index + 9,
                          );

                          final mastered = competencyMastered(competency);

                          return locked
                              ? SizedBox(
                                  width: 30,
                                  height: 44,

                                  child: Column(
                                    children: [
                                      Text(
                                        "${index + 10}",

                                        style: const TextStyle(
                                          fontSize: 8,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),

                                      const SizedBox(height: 2),

                                      SvgPicture.asset(
                                        'assets/Lock_Icon.svg',

                                        width: 26,
                                        height: 26,
                                      ),
                                    ],
                                  ),
                                )
                              : mastered
                              ? SizedBox(
                                  width: 30,
                                  height: 44,

                                  child: Column(
                                    children: [
                                      Text(
                                        "${index + 10}",

                                        style: const TextStyle(
                                          fontSize: 8,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),

                                      const SizedBox(height: 2),

                                      SvgPicture.asset(
                                        'assets/Bach_Seal.svg',

                                        width: 26,
                                        height: 26,
                                      ),
                                    ],
                                  ),
                                )
                              : HarmonyWheel(
                                  competency: competency,

                                  number: index + 10,
                                );
                        }),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class HarmonyWheel extends StatelessWidget {
  final HarmonyCompetency competency;

  final int number;

  const HarmonyWheel({
    super.key,
    required this.competency,
    required this.number,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 30,
      height: 46,

      child: Column(
        children: [
          Text(
            "$number",

            style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 2),

          CustomPaint(
            size: const Size(30, 30),

            painter: HarmonyWheelPainter(competency: competency),
          ),
        ],
      ),
    );
  }
}

class HarmonyWheelPainter extends CustomPainter {
  final HarmonyCompetency competency;

  HarmonyWheelPainter({required this.competency});
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

      Color color;

      switch (state) {
        case HarmonyState.incomplete:
          color = Colors.grey;
          break;

        case HarmonyState.complete:
          color = const Color(0xFFD4AF37);
          break;

        case HarmonyState.embellished:
          color = Colors.black;
          break;
      }

      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;

      canvas.drawArc(
        rect,
        ((i * 45) + 180) * 3.1415926535 / 180,

        45 * 3.1415926535 / 180,

        true,
        paint,
      );

      final outlinePaint = Paint()
        ..color = Colors.black
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.7;

      canvas.drawArc(
        rect,
        ((i * 45) + 180) * 3.1415926535 / 180,

        45 * 3.1415926535 / 180,

        true,
        outlinePaint,
      );
    }

    final centerPaint = Paint()..color = Colors.white;

    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      3.5,
      centerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
