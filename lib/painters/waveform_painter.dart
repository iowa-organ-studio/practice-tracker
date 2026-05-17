import 'package:flutter/material.dart';
import '../models/wave_point.dart';

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