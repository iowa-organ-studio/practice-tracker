
import 'package:flutter/material.dart';

import '../services/practice_report_service.dart';
import '../services/web_practice_report_service.dart';
import '../theme/app_colors.dart';

class AdminLessonReportPreviewPage extends StatefulWidget {
  final String studentUid;
  final String studentName;
  final DateTime startDate;
  final DateTime endDate;

  const AdminLessonReportPreviewPage({
    super.key,
    required this.studentUid,
    required this.studentName,
    required this.startDate,
    required this.endDate,
  });

  @override
  State<AdminLessonReportPreviewPage> createState() =>
      _AdminLessonReportPreviewPageState();
}

class _AdminLessonReportPreviewPageState
    extends State<AdminLessonReportPreviewPage> {
  late Future<PracticeReport> organFuture;
  late Future<WebPracticeReport> webFuture;

  @override
  void initState() {
    super.initState();

    organFuture = PracticeReportService.generate(
      uid: widget.studentUid,
      startDate: widget.startDate,
      endDate: widget.endDate,
    );

    webFuture = WebPracticeReportService.generate(
      uid: widget.studentUid,
      startDate: widget.startDate,
      endDate: widget.endDate,
    );
  }

  String dateLabel(DateTime date) =>
      '${date.month}/${date.day}/${date.year}';

  String timeLabel(int seconds) {
    final minutes = (seconds / 60).round();
    return '${minutes ~/ 60}h ${minutes % 60}m';
  }

  Widget sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(top: 22, bottom: 10),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.bold,
          ),
        ),
      );

  Widget organSection() {
    return FutureBuilder<PracticeReport>(
      future: organFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text('Could not load organ practice: ${snapshot.error}');
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final report = snapshot.data!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            sectionTitle('Organ Practice'),
            Text(
              'Total recorded time: ${timeLabel(report.totalSeconds)}',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '${report.sessionCount} sessions · '
              '${report.daysPracticed} days practiced',
            ),
            sectionTitle('Daily Practice'),
            ...report.days.map((day) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    '${day.date.month}/${day.date.day}',
                  ),
                  trailing: Text(timeLabel(day.totalSeconds)),
                )),
            sectionTitle('Time by Organ'),
            if (report.organs.isEmpty)
              const Text('No organ practice recorded.')
            else
              ...report.organs.map((organ) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(organ.instrument),
                    trailing: Text(timeLabel(organ.totalSeconds)),
                  )),
            sectionTitle('Goals Worked On'),
            if (report.goals.isEmpty)
              const Text('No goals recorded for this period.')
            else
              ...report.goals.map((goal) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(goal.title),
                    subtitle: Text(
                      '${goal.sessions} sessions · '
                      '${goal.daysPracticed} days',
                    ),
                  )),
          ],
        );
      },
    );
  }

  Widget webSection() {
    return FutureBuilder<WebPracticeReport>(
      future: webFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text(
            'Could not load figured bass practice: ${snapshot.error}',
          );
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final report = snapshot.data!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            sectionTitle('Figured Bass Practice'),
            Text(
              '${report.totalPhrases} phrases displayed · '
              '${timeLabel(report.totalSeconds)} estimated',
            ),
            const SizedBox(height: 10),
            ...report.apps.map((app) => Card(
                  child: ListTile(
                    title: Text(app.displayName),
                    subtitle: Text(
                      '${app.phraseCount} phrases · '
                      '${timeLabel(app.totalSeconds)}',
                    ),
                    trailing: Text(
                      '${(app.averageSeconds / 60).toStringAsFixed(1)}m avg',
                    ),
                  ),
                )),
            sectionTitle('Phrases by Key'),
            if (report.phrases.isEmpty)
              const Text('No figured bass phrases recorded.')
            else
              ...report.phrases.map((phrase) {
                final keyDetails = phrase.keyCounts.entries
                    .where((entry) => entry.value > 0)
                    .map((entry) =>
                        '${entry.key}: ${entry.value}')
                    .join(' · ');

                return Card(
                  child: ListTile(
                    title: Text(phrase.exercise),
                    subtitle: Text(keyDetails),
                    trailing: Text('${phrase.total}'),
                  ),
                );
              }),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lesson Report Preview'),
        backgroundColor: Colors.black,
        foregroundColor: gold,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            widget.studentName,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${dateLabel(widget.startDate)} – '
            '${dateLabel(widget.endDate)}',
          ),
          const Divider(height: 30),
          organSection(),
          const Divider(height: 36),
          webSection(),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
