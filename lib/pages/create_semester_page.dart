import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CreateSemesterPage extends StatefulWidget {
  const CreateSemesterPage({super.key});

  @override
  State<CreateSemesterPage> createState() => _CreateSemesterPageState();
}

class _CreateSemesterPageState extends State<CreateSemesterPage> {
  final nameController = TextEditingController();

  final weekCountController = TextEditingController(text: '16');

  String semesterType = 'Fall';

  String customSemesterName = '';

  int selectedYear = DateTime.now().year + 1;

  DateTime? selectedDate;

  List<Map<String, dynamic>> generatedWeeks = [];

  DateTime mondayOf(DateTime d) {
    final normalized = DateTime(d.year, d.month, d.day);

    return normalized.subtract(Duration(days: normalized.weekday - 1));
  }

  List<int> availableYears() {
    final current = DateTime.now().year;

    return List.generate(6, (i) => current + 1 - i);
  }

  void generateWeeks() {
    if (selectedDate == null) {
      return;
    }

    final weekCount = int.tryParse(weekCountController.text) ?? 16;

    final firstMonday = mondayOf(selectedDate!);

    List<Map<String, dynamic>> weeks = [];

    for (int i = 0; i < weekCount; i++) {
      final monday = DateTime(
        firstMonday.year,
        firstMonday.month,
        firstMonday.day + (i * 7),
      );

      weeks.add({'weekNumber': i + 1, 'start': monday, 'deadWeek': false});
    }

    setState(() {
      generatedWeeks = weeks;
    });
  }

  String formatDate(DateTime d) {
    const months = [
      "Jan",
      "Feb",
      "Mar",
      "Apr",
      "May",
      "Jun",
      "Jul",
      "Aug",
      "Sep",
      "Oct",
      "Nov",
      "Dec",
    ];

    return "${d.day} ${months[d.month - 1]} ${d.year}";
  }

  Future<void> saveSemester() async {
    final generatedName = semesterType == 'Other'
        ? "$customSemesterName $selectedYear"
        : "$semesterType $selectedYear";

    final existing = await FirebaseFirestore.instance
        .collection('semesters')
        .where('name', isEqualTo: generatedName)
        .get();

    if (existing.docs.isNotEmpty) {
      if (!mounted) return;

      showDialog(
        context: context,

        builder: (_) => AlertDialog(
          title: const Text("Semester Exists"),

          content: const Text("Semester already created. Go to Edit Semester."),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },

              child: const Text("OK"),
            ),
          ],
        ),
      );

      return;
    }

    await FirebaseFirestore.instance.collection('semesters').add({
      'name': generatedName,

      'weekCount': generatedWeeks.length,

      'weeks': generatedWeeks
          .map(
            (w) => {
              'weekNumber': w['weekNumber'],

              'start': w['start'],

              'deadWeek': w['deadWeek'],
            },
          )
          .toList(),
    });

    if (!mounted) return;

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: generatedWeeks.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: saveSemester,

              backgroundColor: Colors.black,

              foregroundColor: Colors.white,

              icon: const Icon(Icons.save),

              label: const Text("Save Semester"),
            ),
      appBar: AppBar(title: const Text("Create Semester")),

      body: Padding(
        padding: const EdgeInsets.all(16),

        child: Column(
          children: [
            DropdownButton<String>(
              value: semesterType,

              isExpanded: true,

              items: const [
                DropdownMenuItem(value: 'Fall', child: Text('Fall')),

                DropdownMenuItem(value: 'Spring', child: Text('Spring')),

                DropdownMenuItem(value: 'Summer', child: Text('Summer')),

                DropdownMenuItem(value: 'Winter', child: Text('Winter')),

                DropdownMenuItem(value: 'Other', child: Text('Other')),
              ],

              onChanged: (v) {
                setState(() {
                  semesterType = v!;
                });
              },
            ),

            const SizedBox(height: 12),

            DropdownButton<int>(
              value: selectedYear,

              isExpanded: true,

              items: availableYears()
                  .map(
                    (y) =>
                        DropdownMenuItem(value: y, child: Text(y.toString())),
                  )
                  .toList(),

              onChanged: (v) {
                setState(() {
                  selectedYear = v!;
                });
              },
            ),

            const SizedBox(height: 12),

            if (semesterType == 'Other')
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Custom Semester Name',
                ),

                onChanged: (v) {
                  customSemesterName = v;
                },
              ),

            const SizedBox(height: 12),

            const SizedBox(height: 12),

            TextField(
              controller: weekCountController,

              keyboardType: TextInputType.number,

              decoration: const InputDecoration(labelText: "Number of Weeks"),
            ),

            const SizedBox(height: 12),

            ElevatedButton(
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,

                  initialDate: DateTime.now(),

                  firstDate: DateTime(2020),

                  lastDate: DateTime(2035),
                );

                if (picked != null) {
                  selectedDate = picked;

                  generateWeeks();
                }
              },

              child: const Text("Select First Week Date"),
            ),

            const SizedBox(height: 20),

            Expanded(
              child: ListView(
                children: generatedWeeks.map((week) {
                  return Row(
                    children: [
                      Expanded(child: Text("Week ${week['weekNumber']}")),

                      Expanded(child: Text(formatDate(week['start']))),

                      Checkbox(
                        value: week['deadWeek'],

                        onChanged: (v) {
                          setState(() {
                            week['deadWeek'] = v ?? false;
                          });
                        },
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
