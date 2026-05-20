import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/student_progress_service.dart';

class EditStudentPage extends StatefulWidget {
  const EditStudentPage({super.key});

  @override
  State<EditStudentPage> createState() => _EditStudentPageState();
}

class _EditStudentPageState extends State<EditStudentPage> {
  List<QueryDocumentSnapshot> userDocs = [];

  QueryDocumentSnapshot? selectedUser;

  String degree = 'DMA';

  String startTerm = 'Fall';

  int startYear = DateTime.now().year;

  int minimumHours = 12;

  final uidController = TextEditingController();

  final emailController = TextEditingController();

  @override
  void initState() {
    super.initState();

    loadUsers();
  }

  Future<void> loadUsers() async {
    final snapshot = await FirebaseFirestore.instance.collection('users').get();

    setState(() {
      userDocs = snapshot.docs;
    });
  }

  List<int> availableYears() {
    final current = DateTime.now().year;

    return List.generate(8, (i) => current - i);
  }

  void loadStudentData() {
    if (selectedUser == null) {
      return;
    }


    final data = selectedUser!.data() as Map<String, dynamic>;

    emailController.text = data['email'] ?? '';

    uidController.text = data['uid'] ?? '';

    degree = data['degree'] ?? 'DMA';

    final semesterStarted = data['semesterStarted'] ?? {};

    startTerm = semesterStarted['term'] ?? 'Fall';

    startYear = semesterStarted['year'] ?? DateTime.now().year;

    minimumHours = ((data['minimumWeeklyMinutes'] ?? 720) ~/ 60);

    setState(() {});
  }

  Future<void> saveChanges() async {
    if (selectedUser == null) {
      return;
    }

    await FirebaseFirestore.instance
        .collection('users')
        .doc(selectedUser!.id)
        .update({
          'uid': uidController.text.trim(),
          'degree': degree,
          'email': emailController.text.trim(),
          'semesterStarted': {'term': startTerm, 'year': startYear},

          'minimumWeeklyMinutes': minimumHours * 60,
        });

    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Student updated")));
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
      appBar: AppBar(title: const Text("Edit Student")),

      floatingActionButton: selectedUser == null
          ? null
          : FloatingActionButton.extended(
              onPressed: saveChanges,

              icon: const Icon(Icons.save),

              label: const Text("Save Changes"),
            ),

      body: Padding(
        padding: const EdgeInsets.all(16),

        child: ListView(
          children: [
            DropdownButton<QueryDocumentSnapshot>(
              value: selectedUser,

              isExpanded: true,

              hint: const Text("Select Student"),

              items: userDocs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;

                return DropdownMenuItem(
                  value: doc,

                  child: Text(data['name'] ?? ''),
                );
              }).toList(),

              onChanged: (v) {
                setState(() {
                  selectedUser = v;
                });

                loadStudentData();
              },
            ),

            const SizedBox(height: 20),

            TextField(
              controller: emailController,

              decoration: const InputDecoration(labelText: 'Email'),
            ),

            const SizedBox(height: 20),

            TextField(
              controller: uidController,

              keyboardType: TextInputType.number,

              decoration: const InputDecoration(labelText: 'UID (8 digits)'),
            ),

            const SizedBox(height: 20),

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
              "Year: $yearLabel",

              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 10),

            Text(
              "Semester: $semesterNumber   Default: $defaultMinimum h",

              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 20),

            DropdownButton<int>(
              value: minimumHours,

              isExpanded: true,

              items: List.generate(20, (i) => i + 1).map((h) {
                return DropdownMenuItem(value: h, child: Text("$h hours"));
              }).toList(),

              onChanged: (v) {
                setState(() {
                  minimumHours = v!;
                });
              },
            ),

            const SizedBox(height: 20),

            if (selectedUser != null)
              Text(
                "Firebase document ID: ${selectedUser!.id}",

                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
          ],
        ),
      ),
    );
  }
}
