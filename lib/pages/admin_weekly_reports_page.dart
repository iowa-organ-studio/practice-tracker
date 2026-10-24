import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'admin_lesson_report_preview_page.dart';
import '../theme/app_colors.dart';

class AdminWeeklyReportsPage extends StatelessWidget {
  const AdminWeeklyReportsPage({super.key});

  static const lessonDays = [
    'Not set',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  Future<void> showReportPeriodDialog({
    required BuildContext context,
    required String studentUid,
    required String studentName,
    required int lessonDay,
  }) async {
    String selectedPeriod = 'lesson';

    final selected = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: const Text('Generate Practice Report'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(studentName),
                  const SizedBox(height: 14),
                  RadioGroup<String>(
                    groupValue: selectedPeriod,
                    onChanged: (value) {
                      if (value == null) return;
                      setDialogState(() {
                        selectedPeriod = value;
                      });
                    },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        RadioListTile<String>(
                          title: const Text('Week prior to lesson'),
                          value: 'lesson',
                          enabled: lessonDay >= 1 && lessonDay <= 7,
                        ),
                        const RadioListTile<String>(
                          title: Text('Last 7 days'),
                          value: '7',
                        ),
                        const RadioListTile<String>(
                          title: Text('Last 14 days'),
                          value: '14',
                        ),
                        const RadioListTile<String>(
                          title: Text('Last 30 days'),
                          value: '30',
                        ),
                      ],
                    ),
                  ),
                  if (lessonDay == 0)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        'Set a weekly lesson day to use '
                        '"Week prior to lesson".',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: selectedPeriod == 'lesson' && lessonDay == 0
                      ? null
                      : () => Navigator.pop(dialogContext, selectedPeriod),
                  child: const Text('Generate Report'),
                ),
              ],
            );
          },
        );
      },
    );

    if (selected == null || !context.mounted) return;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    late DateTime firstDay;
    late DateTime lastDay;

    if (selected == 'lesson') {
      // Most recent lesson day, including today if it
      // is the student's regular lesson day.
      final daysSinceLesson = (today.weekday - lessonDay + 7) % 7;

      final lessonDate = today.subtract(Duration(days: daysSinceLesson));

      // Seven completed days immediately before lesson.
      lastDay = DateTime(lessonDate.year, lessonDate.month, lessonDate.day - 1);

      firstDay = DateTime(
        lessonDate.year,
        lessonDate.month,
        lessonDate.day - 7,
      );
    } else {
      final days = int.parse(selected);

      // Rolling period includes today.
      lastDay = today;

      firstDay = DateTime(today.year, today.month, today.day - days + 1);
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminLessonReportPreviewPage(
          studentUid: studentUid,
          studentName: studentName,
          startDate: firstDay,
          endDate: lastDay,
        ),
      ),
    );
  }

  String sortName(String name) {
    final parts = name.trim().toLowerCase().split(RegExp(r'\s+'));

    if (parts.length < 2) return name.toLowerCase();

    final lastName = parts.last;
    final firstName = parts.sublist(0, parts.length - 1).join(' ');

    return '$lastName, $firstName';
  }

  Future<void> saveLessonDay({required String uid, required int day}) async {
    final reference = FirebaseFirestore.instance.collection('users').doc(uid);

    if (day == 0) {
      await reference.update({'lessonDay': FieldValue.delete()});
    } else {
      await reference.update({'lessonDay': day});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Weekly Lesson Reports'),
        backgroundColor: Colors.black,
        foregroundColor: gold,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('users').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text('Error loading students: ${snapshot.error}'),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          // Exclude administrator accounts.
          final students = snapshot.data!.docs.where((doc) {
            final data = doc.data();
            return (data['role'] ?? 'student') != 'admin';
          }).toList();

          // Sort alphabetically by last name.
          students.sort((a, b) {
            final nameA = (a.data()['name'] ?? a.id).toString();
            final nameB = (b.data()['name'] ?? b.id).toString();

            return sortName(nameA).compareTo(sortName(nameB));
          });

          if (students.isEmpty) {
            return const Center(child: Text('No students found.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: students.length,
            itemBuilder: (context, index) {
              final student = students[index];
              final data = student.data();

              final name = (data['name'] ?? student.id).toString();

              final rawDay = data['lessonDay'];

              final day = rawDay is int && rawDay >= 1 && rawDay <= 7
                  ? rawDay
                  : 0;

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Student name and UID.
                      Row(
                        children: [
                          const Icon(Icons.person_outline, size: 28),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  student.id,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // Weekly lesson day selector.
                      DropdownButtonFormField<int>(
                        key: ValueKey('${student.id}-$day'),
                        initialValue: day,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Weekly lesson day',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: List.generate(
                          lessonDays.length,
                          (index) => DropdownMenuItem<int>(
                            value: index,
                            child: Text(lessonDays[index]),
                          ),
                        ),
                        onChanged: (newDay) async {
                          if (newDay == null || newDay == day) {
                            return;
                          }

                          try {
                            await saveLessonDay(uid: student.id, day: newDay);
                          } catch (error) {
                            if (!context.mounted) return;

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Could not save lesson day: $error',
                                ),
                              ),
                            );
                          }
                        },
                      ),

                      const SizedBox(height: 12),

                      // Manual report generation.
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            showReportPeriodDialog(
                              context: context,
                              studentUid: student.id,
                              studentName: name,
                              lessonDay: day,
                            );
                          },
                          icon: const Icon(Icons.description_outlined),
                          label: const Text('Generate Report'),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
