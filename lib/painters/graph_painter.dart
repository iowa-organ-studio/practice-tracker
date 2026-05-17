import 'package:flutter/material.dart';
import '../models/segment.dart';

import '../theme/app_colors.dart';

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