import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/practice_report_service.dart';
import '../services/user_service.dart';
import '../theme/app_colors.dart';

import '../services/web_practice_report_service.dart';

class PracticeOverviewPage extends StatefulWidget {
  const PracticeOverviewPage({super.key});

  @override
  State<PracticeOverviewPage> createState() => _PracticeOverviewPageState();
}

class _PracticeOverviewPageState extends State<PracticeOverviewPage> {
  int selectedDays = 7;
  Future<PracticeReport>? reportFuture;
  Future<WebPracticeReport>? webReportFuture;

 
Future<void> generateReport() async {
  final uid = await getUid();
  if (!mounted) return;

  final now = DateTime.now();

  // Include today in the reporting period.
  final lastDay = DateTime(
    now.year,
    now.month,
    now.day,
  );

  final firstDay = DateTime(
    lastDay.year,
    lastDay.month,
    lastDay.day - selectedDays + 1,
  );

  setState(() {
    reportFuture = PracticeReportService.generate(
      uid: uid,
      startDate: firstDay,
      endDate: lastDay,
    );

    webReportFuture = WebPracticeReportService.generate(
      uid: uid,
      startDate: firstDay,
      endDate: lastDay,
    );
  });
}


  String formatTime(int seconds) {
    final minutes = (seconds / 60).round();
    final hours = minutes ~/ 60;
    final remaining = minutes % 60;

    return '${hours}h ${remaining}m';
  }

  String dayLabel(DateTime date) {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${weekdays[date.weekday - 1]}\n${date.month}/${date.day}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Practice Overview'),
        backgroundColor: Colors.black,
        foregroundColor: gold,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 7, label: Text('7 days')),
                    ButtonSegment(value: 14, label: Text('14 days')),
                    ButtonSegment(value: 30, label: Text('30 days')),
                  ],
                  selected: {selectedDays},
                  onSelectionChanged: (selection) {
                    setState(() {
                      selectedDays = selection.first;
                      reportFuture = null;
                      webReportFuture = null;
                    });
                  },
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: generateReport,
                    icon: const Icon(Icons.bar_chart),
                    label: const Text('Generate Practice Report'),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: reportFuture == null
                ? const Center(
                    child: Text(
                      'Choose a period and generate a report.',
                      textAlign: TextAlign.center,
                    ),
                  )
                : FutureBuilder<PracticeReport>(
                    future: reportFuture,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Text(
                              'Could not generate report:\n${snapshot.error}',
                            ),
                          ),
                        );
                      }

                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final report = snapshot.data!;

                      return ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          _summary(report),
                          const SizedBox(height: 24),
                          _dailyChart(report),
                          const SizedBox(height: 24),
                          _organChart(report),
                          const SizedBox(height: 24),
                          _goalsTable(report),
                          const SizedBox(height: 24),
                          _webPracticeSection(),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _summary(PracticeReport report) {
    return Row(
      children: [
        _stat('Days active', '${report.daysPracticed}/${report.days.length}'),
        _stat('Sessions', '${report.sessionCount}'),
        _stat('Organs', '${report.organs.length}'),
      ],
    );
  }

  Widget _stat(String label, String value) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 5),
          child: Column(
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(fontSize: 11),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dailyChart(PracticeReport report) {
    final maximum = report.days.fold<int>(
      0,
      (largest, day) => math.max(largest, day.totalSeconds),
    );

    const colors = [Colors.green, Colors.amber, Colors.grey, Colors.red];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Daily Practice Activity',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 6,
          children: [
            _legend('Practice', colors[0]),
            _legend('Moving', colors[1]),
            _legend('Paused', colors[2]),
            _legend('Flagged', colors[3]),
          ],
        ),
        const SizedBox(height: 16),

        SizedBox(
          height: 280,
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Fit all seven days on screen.
              // Longer reports can scroll horizontally.
              final dayCount = report.days.length;
              final barWidth = constraints.maxWidth / dayCount;
              final showDailyLabels = dayCount <= 7;

              return Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: report.days.map((day) {
                  final total = day.totalSeconds;

                  final barHeight = maximum == 0 ? 0.0 : total / maximum * 195;

                  final segments = [
                    day.practiceSeconds,
                    day.movingSeconds,
                    day.pausedSeconds,
                    day.flaggedSeconds,
                  ];

                  return SizedBox(
                    width: barWidth,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (showDailyLabels)
                          Text(
                            '${(total / 60).round()}m',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        else
                          const SizedBox(height: 14),

                        const SizedBox(height: 5),

                        SizedBox(
                          height: barHeight,
                          width: math.max(
                            3.0,
                            math.min(dayCount <= 7 ? 35.0 : 18.0, barWidth - 3),
                          ),
                          child: Column(
                            children: [
                              for (int i = 3; i >= 0; i--)
                                if (segments[i] > 0)
                                  Expanded(
                                    flex: segments[i],
                                    child: Container(color: colors[i]),
                                  ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 8),

                        SizedBox(
                          height: 28,
                          child: showDailyLabels
                              ? Text(
                                  dayLabel(day.date),
                                  style: const TextStyle(fontSize: 10),
                                  textAlign: TextAlign.center,
                                )
                              : const SizedBox(),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ),

        if (report.days.length > 7)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${report.days.first.date.month}/'
                  '${report.days.first.date.day}',
                  style: const TextStyle(fontSize: 12),
                ),
                Text(
                  '${report.days.last.date.month}/'
                  '${report.days.last.date.day}',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),

        const SizedBox(height: 16),
        Center(
          child: Column(
            children: [
              const Text(
                'Total practice time (including moving/paused):',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                formatTime(report.totalSeconds),
                style: const TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _legend(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 11, height: 11, color: color),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }

  Widget _organChart(PracticeReport report) {
    final total = report.organs.fold<int>(
      0,
      (value, organ) => value + organ.totalSeconds,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Time by Organ',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        if (total == 0)
          const Text('No organ practice recorded.')
        else ...[
          Center(
            child: SizedBox(
              width: 250,
              height: 250,
              child: CustomPaint(painter: _OrganPiePainter(report.organs)),
            ),
          ),
          const SizedBox(height: 16),
          ...report.organs.map((organ) {
            final percentage = organ.totalSeconds / total * 100;

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(child: Text(organ.instrument)),
                  Text(
                    '${percentage.toStringAsFixed(1)}%  '
                    '${formatTime(organ.totalSeconds)}',
                  ),
                ],
              ),
            );
          }),
        ],
      ],
    );
  }

  Widget _goalsTable(PracticeReport report) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Goals Worked On',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        if (report.goals.isEmpty)
          const Text('No goals recorded for this period.')
        else
          ...report.goals.map(
            (goal) => Card(
              child: ListTile(
                title: Text(goal.title),
                subtitle: Text(
                  '${goal.sessions} sessions · '
                  '${goal.daysPracticed} days',
                ),
              ),
            ),
          ),
        const SizedBox(height: 40),
      ],
    );
  }


Widget _webPracticeSection() {
  if (webReportFuture == null) {
    return const SizedBox.shrink();
  }

  return FutureBuilder<WebPracticeReport>(
    future: webReportFuture,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Text(
          'Could not load figured bass activity: ${snapshot.error}',
        );
      }

      if (!snapshot.hasData) {
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: CircularProgressIndicator(),
          ),
        );
      }

      final report = snapshot.data!;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Figured Bass Practice',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Phrases displayed in the selected period',
          ),
          const SizedBox(height: 16),
          _webPracticeSummary(report),
          const SizedBox(height: 24),
          _webPracticeGrid(report),
          const SizedBox(height: 30),
        ],
      );
    },
  );
}

String _formatWebTime(int seconds) {
  final minutes = (seconds / 60).round();
  final hours = minutes ~/ 60;
  final remaining = minutes % 60;

  return '${hours}h ${remaining}m';
}

Widget _webPracticeSummary(WebPracticeReport report) {
  return Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Table(
        columnWidths: const {
          0: FlexColumnWidth(1.3),
          1: FlexColumnWidth(1),
          2: FlexColumnWidth(1.2),
          3: FlexColumnWidth(1.2),
        },
        children: [
          const TableRow(
            children: [
              Padding(
                padding: EdgeInsets.all(5),
                child: Text(
                  'App',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(5),
                child: Text(
                  'Phrases',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(5),
                child: Text(
                  'Time',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(5),
                child: Text(
                  'Avg.',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          ...report.apps.map((app) {
            return TableRow(
              children: [
                Padding(
                  padding: const EdgeInsets.all(5),
                  child: Text(app.displayName),
                ),
                Padding(
                  padding: const EdgeInsets.all(5),
                  child: Text('${app.phraseCount}'),
                ),
                Padding(
                  padding: const EdgeInsets.all(5),
                  child: Text(_formatWebTime(app.totalSeconds)),
                ),
                Padding(
                  padding: const EdgeInsets.all(5),
                  child: Text(
                    '${(app.averageSeconds / 60).toStringAsFixed(1)}m',
                  ),
                ),
              ],
            );
          }),
          TableRow(
            children: [
              const Padding(
                padding: EdgeInsets.all(5),
                child: Text(
                  'Total',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(5),
                child: Text('${report.totalPhrases}'),
              ),
              Padding(
                padding: const EdgeInsets.all(5),
                child: Text(_formatWebTime(report.totalSeconds)),
              ),
              Padding(
                padding: const EdgeInsets.all(5),
                child: Text(
                  '${(report.averageSeconds / 60).toStringAsFixed(1)}m',
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

Widget _webPracticeGrid(WebPracticeReport report) {
  if (report.phrases.isEmpty) {
    return const Text(
      'No figured bass exercises recorded for this period.',
    );
  }

  const appOrder = ['js-bach', 'boyvin', 'cpe-bach'];

  final appNames = WebPracticeReportService.appNames;
  final keys = WebPracticeReportService.keys;

  String keyLabel(String key) {
    return key.replaceAll('#', '♯').replaceAll('b', '♭');
  }

  final columnTotals = {
    for (final key in keys) key: 0,
  };

  for (final phrase in report.phrases) {
    for (final key in keys) {
      columnTotals[key] =
          columnTotals[key]! + (phrase.keyCounts[key] ?? 0);
    }
  }

  DataRow makeRow(
    String title,
    int total,
    Map<String, int> counts, {
    bool bold = false,
  }) {
    final style = TextStyle(
      fontWeight: bold ? FontWeight.bold : FontWeight.normal,
      fontSize: 12,
    );

    return DataRow(
      cells: [
        DataCell(Text(title, style: style)),
        DataCell(Text('$total', style: style)),
        ...keys.map((key) {
          final count = counts[key] ?? 0;
          return DataCell(
            Text(
              count == 0 ? '' : '$count',
              style: style,
            ),
          );
        }),
      ],
    );
  }

  final rows = <DataRow>[
    makeRow(
      'Totals',
      report.phrases.fold<int>(
        0,
        (total, phrase) => total + phrase.total,
      ),
      columnTotals,
      bold: true,
    ),
  ];

  for (final appId in appOrder) {
    final phrases = report.phrases
        .where((phrase) => phrase.appId == appId)
        .toList();

    if (phrases.isEmpty) continue;

    rows.add(
      makeRow(
        appNames[appId] ?? appId,
        phrases.fold<int>(
          0,
          (total, phrase) => total + phrase.total,
        ),
        const {},
        bold: true,
      ),
    );

    for (final phrase in phrases) {
      rows.add(
        makeRow(
          phrase.exercise,
          phrase.total,
          phrase.keyCounts,
        ),
      );
    }
  }

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Phrases by Key',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      const SizedBox(height: 8),
      const Text(
        'Scroll horizontally to see all keys.',
        style: TextStyle(fontSize: 12),
      ),
      const SizedBox(height: 10),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 15,
          horizontalMargin: 10,
          headingRowHeight: 38,
          dataRowMinHeight: 34,
          dataRowMaxHeight: 42,
          columns: [
            const DataColumn(label: Text('Phrase')),
            const DataColumn(label: Text('Total')),
            ...keys.map(
              (key) => DataColumn(
                label: Text(keyLabel(key)),
              ),
            ),
          ],
          rows: rows,
        ),
      ),
    ],
  );
}


}

class _OrganPiePainter extends CustomPainter {
  final List<OrganPracticeReport> organs;

  _OrganPiePainter(this.organs);

  static const colors = [
    Color(0xFF4169E1),
    Color(0xFFDAA520),
    Color(0xFF2E8B57),
    Color(0xFF9370DB),
    Color(0xFFE07045),
    Color(0xFF708090),
    Color(0xFFB05070),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final total = organs.fold<int>(
      0,
      (value, organ) => value + organ.totalSeconds,
    );

    if (total == 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 8;
    final rect = Rect.fromCircle(center: center, radius: radius);

    double angle = -math.pi / 2;

    for (int i = 0; i < organs.length; i++) {
      final organ = organs[i];
      final sweep = organ.totalSeconds / total * 2 * math.pi;

      final paint = Paint()
        ..color = colors[i % colors.length]
        ..style = PaintingStyle.fill;

      canvas.drawArc(rect, angle, sweep, true, paint);

      final middle = angle + sweep / 2;

      final labelRadius = radius * 0.65;

      final labelPosition = Offset(
        center.dx + math.cos(middle) * labelRadius,
        center.dy + math.sin(middle) * labelRadius,
      );

      final letter = organ.instrument.isEmpty
          ? '?'
          : organ.instrument[0].toUpperCase();

      final textPainter = TextPainter(
        text: TextSpan(
          text: letter,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
            shadows: [Shadow(color: Colors.black, blurRadius: 3)],
          ),
        ),
        textDirection: TextDirection.ltr,
      );

      textPainter.layout();

      textPainter.paint(
        canvas,
        Offset(
          labelPosition.dx - textPainter.width / 2,
          labelPosition.dy - textPainter.height / 2,
        ),
      );

      angle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _OrganPiePainter oldDelegate) =>
      oldDelegate.organs != organs;
}
