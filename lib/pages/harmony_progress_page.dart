import 'package:flutter/material.dart';

import '../widgets/admin_header.dart';

import '../data/harmony_competencies.dart';

import '../models/harmony_competency.dart';
import '../models/harmony_state.dart';
import '../models/harmony_wedge.dart';

import '../theme/app_colors.dart';
import 'dart:math';
import '../services/user_service.dart';

class HarmonyProgressPage extends StatelessWidget {
  const HarmonyProgressPage({super.key});

  @override
  Widget build(BuildContext context) {
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
                itemCount: harmonyCompetencies.length,

                itemBuilder: (context, index) {
                  final competency = harmonyCompetencies[index];

                  return HarmonyCompetencyCard(
                    competency: competency,

                    number: index + 1,
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

class HarmonyCompetencyCard extends StatelessWidget {
  final HarmonyCompetency competency;

  final int number;

  const HarmonyCompetencyCard({
    super.key,
    required this.competency,
    required this.number,
  });

  String wedgeIcon(HarmonyWedge wedge) {
    switch (wedge) {
      case HarmonyWedge.hands:
        return "✋✋";

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
        return Colors.black;

      case HarmonyState.embellished:
        return gold;
    }
  }

  Color iconColor(HarmonyState state) {
    switch (state) {
      case HarmonyState.incomplete:
        return Colors.black;

      case HarmonyState.complete:
        return Colors.white;

      case HarmonyState.embellished:
        return Colors.black;
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
                      CustomPaint(
                        size: Size.infinite,

                        painter: ExpandedHarmonyPainter(
                          competency: competency,

                          wedgeColor: wedgeColor,

                          iconColor: iconColor,

                          wedgeIcon: wedgeIcon,
                        ),
                      ),

                      Container(
                        width: 90,
                        height: 90,

                        decoration: const BoxDecoration(
                          color: Colors.white,

                          shape: BoxShape.circle,
                        ),

                        alignment: Alignment.center,

                        child: Text(
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
