
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../models/practice_goal.dart';
import '../services/goal_service.dart';

class AdminGoalsPage extends StatelessWidget {
  const AdminGoalsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Manage Student Goals"),
        backgroundColor: Colors.black,
        foregroundColor: gold,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text("Error loading students: ${snapshot.error}"),
            );
          }

          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final students = snapshot.data!.docs.toList();

       
students.sort((a, b) {
  String sortName(String name) {
    final parts = name.trim().toLowerCase().split(RegExp(r'\s+'));

    if (parts.length < 2) return name.toLowerCase();

    final lastName = parts.last;
    final firstName = parts.sublist(0, parts.length - 1).join(' ');

    return '$lastName, $firstName';
  }

  final nameA = (a.data()['name'] ?? a.id).toString();
  final nameB = (b.data()['name'] ?? b.id).toString();

  return sortName(nameA).compareTo(sortName(nameB));
});


          return ListView.builder(
            itemCount: students.length,
            itemBuilder: (context, index) {
              final student = students[index];
              final data = student.data();
              final name = (data['name'] ?? student.id).toString();

              return ListTile(
                leading: const Icon(Icons.person_outline),
                title: Text(name),
                subtitle: Text(student.id),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => StudentGoalsAdminPage(
                        studentUid: student.id,
                        studentName: name,
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class StudentGoalsAdminPage extends StatefulWidget {
  final String studentUid;
  final String studentName;

  const StudentGoalsAdminPage({
    super.key,
    required this.studentUid,
    required this.studentName,
  });

  @override
  State<StudentGoalsAdminPage> createState() =>
      _StudentGoalsAdminPageState();
}

class _StudentGoalsAdminPageState
    extends State<StudentGoalsAdminPage> {
  bool showArchive = false;

  Future<void> showGoalDialog({PracticeGoal? goal}) async {
    String title = goal?.title ?? '';
    String description = goal?.description ?? '';

    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(goal == null ? "Assign Goal" : "Edit Goal"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                initialValue: title,
                autofocus: true,
                maxLength: 150,
                onChanged: (value) => title = value,
                decoration: const InputDecoration(
                  labelText: "Goal",
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: description,
                maxLines: 3,
                onChanged: (value) => description = value,
                decoration: const InputDecoration(
                  labelText: "Notes (optional)",
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(dialogContext, true),
            child: Text(
              goal == null ? "Assign" : "Save Changes",
            ),
          ),
        ],
      ),
    );

    if (!mounted || shouldSave != true) return;

    title = title.trim();
    description = description.trim();

    if (title.isEmpty) return;

    try {
      if (goal == null) {
        await GoalService.createGoal(
          studentUid: widget.studentUid,
          title: title,
          description: description,
          createdBy: GoalCreator.admin,
        );
      } else {
        await GoalService.updateGoal(
          studentUid: widget.studentUid,
          goalId: goal.id,
          title: title,
          description: description,
        );
      }
    } catch (e) {
      showError(e);
    }
  }

  void showError(Object error) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Goal update failed: $error")),
    );
  }

  Future<void> completeGoal(PracticeGoal goal) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Teacher Complete"),
        content: Text(
          'Mark "${goal.title}" as teacher completed '
          'and move it to the archive?',
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(dialogContext, true),
            child: const Text("Complete & Archive"),
          ),
        ],
      ),
    );

    if (!mounted || confirmed != true) return;

    try {
      await GoalService.teacherCompleteGoal(
        studentUid: widget.studentUid,
        goalId: goal.id,
      );
    } catch (e) {
      showError(e);
    }
  }

  Future<void> needsMoreWork(PracticeGoal goal) async {
    try {
      await GoalService.returnToInProgress(
        studentUid: widget.studentUid,
        goalId: goal.id,
      );
    } catch (e) {
      showError(e);
    }
  }

  
  Widget buildGoalCard(PracticeGoal goal) {
    final readyForReview =
        goal.status == GoalStatus.studentReportedCompleted;

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 6,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => showGoalDialog(goal: goal),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      goal.title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.edit_outlined,
                    color: Colors.grey,
                    size: 20,
                  ),
                ],
              ),

              if (goal.description.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(goal.description),
              ],

              const SizedBox(height: 8),

              Text(
                goal.createdBy == GoalCreator.admin
                    ? "Assigned by teacher · Tap to edit"
                    : "Created by student · Tap to edit",
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),

              if (readyForReview)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    "Student reported completed — ready for review",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                ),

              const SizedBox(height: 12),

              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ElevatedButton(
                    onPressed: () => completeGoal(goal),
                    child: const Text("Teacher Complete"),
                  ),
                  if (readyForReview)
                    OutlinedButton(
                      onPressed: () => needsMoreWork(goal),
                      child: const Text("Needs More Work"),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }



  Widget buildArchivedGoalCard(PracticeGoal goal) {
    final completedAt = goal.teacherCompletedAt;

    final date = completedAt == null
        ? "Completion date unavailable"
        : "${completedAt.month}/${completedAt.day}/${completedAt.year}";

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 6,
      ),
      child: ListTile(
        leading: const Icon(
          Icons.check_circle,
          color: Colors.green,
        ),
        title: Text(goal.title),
        subtitle: Text("Teacher completed: $date"),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.studentName),
        backgroundColor: Colors.black,
        foregroundColor: gold,
      ),
      floatingActionButton: showArchive
          ? null
          : FloatingActionButton.extended(
              onPressed: () => showGoalDialog(),
              backgroundColor: Colors.black,
              foregroundColor: gold,
              icon: const Icon(Icons.add),
              label: const Text("Assign Goal"),
            ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: false,
                  label: Text("Active Goals"),
                ),
                ButtonSegment(
                  value: true,
                  label: Text("Archive"),
                ),
              ],
              selected: {showArchive},
              onSelectionChanged: (selection) {
                setState(() {
                  showArchive = selection.first;
                });
              },
            ),
          ),
          Expanded(
            child: StreamBuilder<List<PracticeGoal>>(
              stream: showArchive
                  ? GoalService.watchArchivedGoals(
                      widget.studentUid,
                    )
                  : GoalService.watchActiveGoals(
                      widget.studentUid,
                    ),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      "Error loading goals: ${snapshot.error}",
                    ),
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                final goals = snapshot.data!;

                if (goals.isEmpty) {
                  return Center(
                    child: Text(
                      showArchive
                          ? "No archived goals yet."
                          : "No active goals yet.",
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(
                    bottom: 90,
                  ),
                  itemCount: goals.length,
                  itemBuilder: (context, index) {
                    final goal = goals[index];

                    return showArchive
                        ? buildArchivedGoalCard(goal)
                        : buildGoalCard(goal);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
