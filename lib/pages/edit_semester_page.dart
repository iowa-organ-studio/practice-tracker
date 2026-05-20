import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EditSemesterPage extends StatefulWidget {
  const EditSemesterPage({super.key});

  @override
  State<EditSemesterPage> createState() => _EditSemesterPageState();
}

class _EditSemesterPageState extends State<EditSemesterPage> {
  List<QueryDocumentSnapshot> semesterDocs = [];

  QueryDocumentSnapshot? selectedSemester;

  List<Map<String, dynamic>> editableWeeks = [];

  @override
  void initState() {
    super.initState();

    loadSemesters();
  }

  Future<void> loadSemesters() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('semesters')
        .get();

    final docs = snapshot.docs;

    docs.sort((a, b) {
      final aName = a['name'] ?? '';

      final bName = b['name'] ?? '';

      return bName.compareTo(aName);
    });

    setState(() {
      semesterDocs = docs;
    });
  }

  String formatDate(dynamic raw) {
    DateTime d;

    if (raw is Timestamp) {
      d = raw.toDate();
    } else if (raw is String) {
      d = DateTime.parse(raw);
    } else {
      return "Invalid date";
    }

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

  void loadWeeks() {
    if (selectedSemester == null) {
      return;
    }

    final data = selectedSemester!.data() as Map<String, dynamic>;

    final rawWeeks = List<Map<String, dynamic>>.from(data['weeks'] ?? []);

    setState(() {
      editableWeeks = rawWeeks;
    });
  }

  Future<void> saveChanges() async {
    if (selectedSemester == null) {
      return;
    }

    await FirebaseFirestore.instance
        .collection('semesters')
        .doc(selectedSemester!.id)
        .update({'weeks': editableWeeks});

    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Semester updated")));
  }

  Future<void> deleteSemester() async {
    if (selectedSemester == null) {
      return;
    }

    final data = selectedSemester!.data() as Map<String, dynamic>;

    final confirmed = await showDialog<bool>(
      context: context,

      builder: (_) => AlertDialog(
        title: const Text("Delete Semester"),

        content: Text("Are you sure you want to delete ${data['name']}?"),

        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context, false);
            },

            child: const Text("No"),
          ),

          TextButton(
            onPressed: () {
              Navigator.pop(context, true);
            },

            child: const Text("Yes"),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    await FirebaseFirestore.instance
        .collection('semesters')
        .doc(selectedSemester!.id)
        .delete();

    setState(() {
      selectedSemester = null;

      editableWeeks = [];
    });

    await loadSemesters();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Edit Semester")),

      floatingActionButton: editableWeeks.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: saveChanges,

              icon: const Icon(Icons.save),

              label: const Text("Save Changes"),
            ),

      body: Padding(
        padding: const EdgeInsets.all(16),

        child: Column(
          children: [
            DropdownButton<QueryDocumentSnapshot>(
              value: selectedSemester,

              isExpanded: true,

              hint: const Text("Select Semester"),

              items: semesterDocs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;

                return DropdownMenuItem(value: doc, child: Text(data['name']));
              }).toList(),

              onChanged: (v) {
                setState(() {
                  selectedSemester = v;
                });
              },
            ),

            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: selectedSemester == null ? null : loadWeeks,

                    child: const Text("Display Weeks"),
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),

                    onPressed: selectedSemester == null ? null : deleteSemester,

                    child: const Text("Delete Semester"),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            Expanded(
              child: ListView(
                children: editableWeeks.map((week) {
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
