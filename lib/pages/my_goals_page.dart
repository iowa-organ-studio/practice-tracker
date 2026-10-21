
import 'package:flutter/material.dart';

import '../models/practice_goal.dart';
import '../services/goal_service.dart';
import '../services/user_service.dart';
import '../theme/app_colors.dart';

class MyGoalsPage extends StatefulWidget {
  const MyGoalsPage({super.key});

  @override
  State<MyGoalsPage> createState() => _MyGoalsPageState();
}

class _MyGoalsPageState extends State<MyGoalsPage> {
  String? uid;
  bool showArchive = false;

  @override
  void initState() {
    super.initState();
    loadUid();
  }

  Future<void> loadUid() async {
    final value = await getUid();

    if (!mounted) return;

    setState(() {
      uid = value;
    });
  }

   
Future<void> createGoal() async {
  if (uid == null) return;

  String title = '';
  String description = '';

  final shouldSave = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text("Create New Goal"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                autofocus: true,
                maxLength: 150,
                initialValue: '',
                onChanged: (value) {
                  title = value;
                },
                decoration: const InputDecoration(
                  labelText: "Goal",
                  hintText: "What do you want to work on?",
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: '',
                maxLines: 3,
                onChanged: (value) {
                  description = value;
                },
                decoration: const InputDecoration(
                  labelText: "Notes (optional)",
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext, false);
            },
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext, true);
            },
            child: const Text("Create Goal"),
          ),
        ],
      );
    },
  );

  if (!mounted) return;

  title = title.trim();
  description = description.trim();

  if (shouldSave != true || title.isEmpty) return;

  try {
    await GoalService.createGoal(
      studentUid: uid!,
      title: title,
      description: description,
      createdBy: GoalCreator.student,
    );
  } catch (e) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Could not create goal: $e")),
    );
  }
}




Future<void> editGoal(PracticeGoal goal) async {
  if (uid == null) return;

  // Students can edit only their own goals.
  if (goal.createdBy != GoalCreator.student) return;

  String title = goal.title;
  String description = goal.description;

  final shouldSave = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text("Edit Goal"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                initialValue: goal.title,
                autofocus: true,
                maxLength: 150,
                onChanged: (value) {
                  title = value;
                },
                decoration: const InputDecoration(
                  labelText: "Goal",
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: goal.description,
                maxLines: 3,
                onChanged: (value) {
                  description = value;
                },
                decoration: const InputDecoration(
                  labelText: "Notes (optional)",
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext, false);
            },
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext, true);
            },
            child: const Text("Save Changes"),
          ),
        ],
      );
    },
  );

  if (!mounted) return;

  title = title.trim();
  description = description.trim();

  if (shouldSave != true || title.isEmpty) return;

  try {
    await GoalService.updateGoal(
      studentUid: uid!,
      goalId: goal.id,
      title: title,
      description: description,
    );
  } catch (e) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Could not update goal: $e")),
    );
  }
}

  Future<void> reportCompleted(PracticeGoal goal) async {
    if (uid == null) return;

    try {
      await GoalService.studentReportCompleted(
        studentUid: uid!,
        goalId: goal.id,
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Could not update goal: $e")),
      );
    }
  }

  Future<void> resumeGoal(PracticeGoal goal) async {
    if (uid == null) return;

    try {
      await GoalService.returnToInProgress(
        studentUid: uid!,
        goalId: goal.id,
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Could not update goal: $e")),
      );
    }
  }

 
Widget buildGoalCard(PracticeGoal goal) {
  final readyForReview =
      goal.status == GoalStatus.studentReportedCompleted;

  final studentCreated =
      goal.createdBy == GoalCreator.student;

  return Card(
    margin: const EdgeInsets.symmetric(
      horizontal: 16,
      vertical: 6,
    ),
    child: InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: studentCreated
          ? () => editGoal(goal)
          : null,
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
                if (studentCreated)
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
              studentCreated
                  ? "Created by me · Tap to edit"
                  : "Assigned by teacher",
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),

            const SizedBox(height: 10),

            if (readyForReview)
              OutlinedButton(
                onPressed: () => resumeGoal(goal),
                child: const Text(
                  "Student reported completed — Resume Goal",
                ),
              )
            else
              ElevatedButton(
                onPressed: () => reportCompleted(goal),
                child: const Text(
                  "Report Goal Completed",
                ),
              ),
          ],
        ),
      ),
    ),
  );
}


  Widget buildArchivedGoalCard(PracticeGoal goal) {
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
        subtitle: Text(
          goal.teacherCompletedAt == null
              ? "Teacher completed"
              : "Teacher completed: "
                  "${goal.teacherCompletedAt!.month}/"
                  "${goal.teacherCompletedAt!.day}/"
                  "${goal.teacherCompletedAt!.year}",
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          showArchive ? "My Goal Archive" : "My Goals",
        ),
        backgroundColor: Colors.black,
        foregroundColor: gold,
      ),
      floatingActionButton: showArchive
          ? null
          : FloatingActionButton.extended(
              onPressed: createGoal,
              backgroundColor: Colors.black,
              foregroundColor: gold,
              icon: const Icon(Icons.add),
              label: const Text("New Goal"),
            ),
      body: uid == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
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
                        ? GoalService.watchArchivedGoals(uid!)
                        : GoalService.watchActiveGoals(uid!),
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
                                ? "No completed goals yet."
                                : "No active goals yet.\n"
                                  "Tap New Goal to create one.",
                            textAlign: TextAlign.center,
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
