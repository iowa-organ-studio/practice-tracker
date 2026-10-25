import 'package:flutter/material.dart';

import '../services/practice_report_service.dart';
import '../services/web_practice_report_service.dart';
import '../theme/app_colors.dart';

import '../services/additional_web_practice_report_service.dart';

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
  late Future<AdditionalWebPracticeReport> additionalFuture;

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

    // Load Improvisation and Hymn Practice data.
    additionalFuture = AdditionalWebPracticeReportService.generate(
      uid: widget.studentUid,
      startDate: widget.startDate,
      endDate: widget.endDate,
    );
  }

  String dateLabel(DateTime date) => '${date.month}/${date.day}/${date.year}';

  String timeLabel(int seconds) {
    final minutes = (seconds / 60).round();
    return '${minutes ~/ 60}h ${minutes % 60}m';
  }

  Widget sectionTitle(String text) => Padding(
    padding: const EdgeInsets.only(top: 22, bottom: 10),
    child: Text(
      text,
      style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
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
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            Text(
              '${report.sessionCount} sessions · '
              '${report.daysPracticed} days practiced',
            ),
            sectionTitle('Daily Practice'),
            ...report.days.map(
              (day) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text('${day.date.month}/${day.date.day}'),
                trailing: Text(timeLabel(day.totalSeconds)),
              ),
            ),
            sectionTitle('Time by Organ'),
            if (report.organs.isEmpty)
              const Text('No organ practice recorded.')
            else
              ...report.organs.map(
                (organ) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(organ.instrument),
                  trailing: Text(timeLabel(organ.totalSeconds)),
                ),
              ),
            sectionTitle('Goals Worked On'),
            if (report.goals.isEmpty)
              const Text('No goals recorded for this period.')
            else
              ...report.goals.map(
                (goal) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(goal.title),
                  subtitle: Text(
                    '${goal.sessions} sessions · '
                    '${goal.daysPracticed} days',
                  ),
                ),
              ),
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
            ...report.apps.map(
              (app) => Card(
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
              ),
            ),
          ],
        );
      },
    );
  }

  Widget additionalWebSections() {
    return FutureBuilder<AdditionalWebPracticeReport>(
      future: additionalFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text(
            'Could not load additional web practice: '
            '${snapshot.error}',
          );
        }

        if (!snapshot.hasData) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
          );
        }

        final report = snapshot.data!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            sectionTitle('Improvisation Practice'),

            if (report.improvisation.isEmpty)
              const Text(
                'No improvisation practice recorded '
                'for this period.',
              )
            else ...[
              ...report.improvisation.map(
                (model) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(model.modelName),
                  trailing: Text(timeLabel(model.seconds)),
                ),
              ),

              const Divider(),

              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Total Improvisation',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                trailing: Text(
                  timeLabel(report.improvisationSeconds),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],

            sectionTitle('Hymn Practice'),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Table(
                  children: [
                    TableRow(
                      children: [
                        const Text('Hymns displayed'),
                        Text('${report.hymnCount}', textAlign: TextAlign.right),
                      ],
                    ),
                    TableRow(
                      children: [
                        const Text('Estimated time'),
                        Text(
                          timeLabel(report.hymnSeconds),
                          textAlign: TextAlign.right,
                        ),
                      ],
                    ),
                    TableRow(
                      children: [
                        const Text('Average per hymn'),
                        Text(
                          '${(report.hymnAverageSeconds / 60).toStringAsFixed(1)} min',
                          textAlign: TextAlign.right,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
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
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
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
          const Divider(height: 36),
          additionalWebSections(),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
