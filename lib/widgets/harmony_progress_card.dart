import 'package:flutter/material.dart';

class HarmonyProgressCard extends StatelessWidget {
  const HarmonyProgressCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
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
                    return const HarmonyWheel(number: 12);
                  }),
                ),

                const SizedBox(height: 6),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,

                  children: List.generate(9, (index) {
                    return const HarmonyWheel(number: 12);
                  }),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class HarmonyWheel extends StatelessWidget {
  final int number;

  const HarmonyWheel({super.key, required this.number});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 24,
      height: 24,

      child: Stack(
        alignment: Alignment.center,

        children: [
          CustomPaint(size: const Size(24, 24), painter: HarmonyWheelPainter()),

          Container(
            width: 11,
            height: 11,

            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),

            alignment: Alignment.center,

            child: Text(
              "$number",

              style: const TextStyle(fontSize: 6, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

class HarmonyWheelPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final colors = [
      Colors.black,
      Color(0xFFD4AF37),
      Colors.grey,
      Colors.black,
      Color(0xFFD4AF37),
      Colors.grey,
      Colors.black,
      Color(0xFFD4AF37),
    ];

    final rect = Rect.fromLTWH(0, 0, size.width, size.height);

    for (int i = 0; i < 8; i++) {
      final paint = Paint()..color = colors[i];

      canvas.drawArc(
        rect,
        (i * 45) * 3.1415926535 / 180,
        45 * 3.1415926535 / 180,
        true,
        paint,
      );
    }

    final centerPaint = Paint()..color = Colors.white;

    canvas.drawCircle(Offset(size.width / 2, size.height / 2), 7, centerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}
