import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/student_progress_service.dart';

class AddStudentPage extends StatefulWidget {
  const AddStudentPage({super.key});

  @override
  State<AddStudentPage> createState() => _AddStudentPageState();
}

class _AddStudentPageState extends State<AddStudentPage> {
  final nameController = TextEditingController();

  final emailController = TextEditingController();
  final uidController = TextEditingController();

  String degree = 'DMA';

  String startTerm = 'Fall';

  late int startYear;

  @override
  void initState() {
    super.initState();

    startYear = DateTime.now().year;
  }

  List<int> availableYears() {
    final current = DateTime.now().year;

    return List.generate(8, (i) => current - i);
  }

  Future<void> saveStudent() async {
    final semesterNumber = computeSemesterNumber(
      startTerm: startTerm,
      startYear: startYear,
    );

    final defaultMinimum = computeDefaultMinimum(
      degree: degree,
      semesterNumber: semesterNumber,
    );

    final uid = uidController.text.trim();

    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'name': nameController.text,

      'uid': uidController.text.trim(),

      'role': 'student',

      'email': emailController.text,

      'degree': degree,

      'semesterStarted': {'term': startTerm, 'year': startYear},

      'minimumWeeklyMinutes': defaultMinimum * 60,

      'harmonyProgress': {},
    });

    if (!mounted) return;

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final semesterNumber = computeSemesterNumber(
      startTerm: startTerm,
      startYear: startYear,
    );

    final yearLabel = computeYearLabel(
      degree: degree,
      semesterNumber: semesterNumber,
    );

    final defaultMinimum = computeDefaultMinimum(
      degree: degree,
      semesterNumber: semesterNumber,
    );

    return Scaffold(
      appBar: AppBar(title: const Text("Add Student")),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: saveStudent,

        icon: const Icon(Icons.save),

        label: const Text("Save Student"),
      ),

      body: Padding(
        padding: const EdgeInsets.all(16),

        child: ListView(
          children: [
            TextField(
              controller: nameController,

              decoration: const InputDecoration(labelText: 'Name'),
            ),

            const SizedBox(height: 12),

            TextField(
              controller: emailController,

              decoration: const InputDecoration(labelText: 'Email'),
            ),

            const SizedBox(height: 12),

            TextField(
              controller: uidController,

              keyboardType: TextInputType.number,

              decoration: const InputDecoration(labelText: 'UID (8 digits)'),
            ),

            const SizedBox(height: 20),

            const Text(
              "Degree",

              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.purple,
              ),
            ),

            DropdownButton<String>(
              value: degree,

              isExpanded: true,

              items: const [
                DropdownMenuItem(value: 'DMA', child: Text('DMA')),

                DropdownMenuItem(value: 'MA', child: Text('MA')),

                DropdownMenuItem(value: 'BM', child: Text('BM')),

                DropdownMenuItem(value: 'BA', child: Text('BA')),

                DropdownMenuItem(value: 'Other', child: Text('Other')),
              ],

              onChanged: (v) {
                setState(() {
                  degree = v!;
                });
              },
            ),

            const SizedBox(height: 20),

            const Text(
              "Year started at UI",

              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.purple,
              ),
            ),

            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: DropdownButton<String>(
                    value: startTerm,

                    isExpanded: true,

                    items: const [
                      DropdownMenuItem(value: 'Fall', child: Text('Fall')),

                      DropdownMenuItem(value: 'Spring', child: Text('Spring')),
                    ],

                    onChanged: (v) {
                      setState(() {
                        startTerm = v!;
                      });
                    },
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: DropdownButton<int>(
                    value: startYear,

                    isExpanded: true,

                    items: availableYears().map((y) {
                      return DropdownMenuItem(
                        value: y,

                        child: Text(y.toString()),
                      );
                    }).toList(),

                    onChanged: (v) {
                      setState(() {
                        startYear = v!;
                      });
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 30),

            Text(
              "Current Year: $yearLabel",
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 10),

            Text(
              "Semester Number: $semesterNumber",
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 10),

            Text(
              "Default Minimum: $defaultMinimum hours",
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
