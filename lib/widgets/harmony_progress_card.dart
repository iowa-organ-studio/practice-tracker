import 'package:flutter/material.dart';
import '../data/harmony_competencies.dart';
import '../models/harmony_competency.dart';
import '../models/harmony_state.dart';

import '../models/harmony_wedge.dart';
import '../pages/harmony_progress_page.dart';

class HarmonyProgressCard extends StatelessWidget {
  const HarmonyProgressCard({super.key});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,

          MaterialPageRoute(builder: (_) => const HarmonyProgressPage()),
        );
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
                      final competency = harmonyCompetencies[index];

                      return HarmonyWheel(
                        competency: competency,

                        number: index + 1,
                      );
                    }),
                  ),

                  const SizedBox(height: 14),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,

                    children: List.generate(9, (index) {
                      final competency = harmonyCompetencies[index + 9];

                      return HarmonyWheel(
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
      height: 44,

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

    final wedges = HarmonyWedge.values;

    for (int i = 0; i < 8; i++) {
      final wedge = wedges[i];

      final state = competency.wedges[wedge]!;

      Color color;

      switch (state) {
        case HarmonyState.incomplete:
          color = Colors.grey;
          break;

        case HarmonyState.complete:
          color = Colors.black;
          break;

        case HarmonyState.embellished:
          color = const Color(0xFFD4AF37);
          break;
      }

      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;

      canvas.drawArc(
        rect,
        (i * 45) * 3.1415926535 / 180,

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
        (i * 45) * 3.1415926535 / 180,

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
    return false;
  }
}
