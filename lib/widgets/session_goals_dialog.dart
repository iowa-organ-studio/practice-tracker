
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/practice_goal.dart';
import '../theme/app_colors.dart';

Future<void> showSessionGoalsDialog({
  required BuildContext context,
  required String studentUid,
  required String weekId,
  required String sessionId,
}) async {
  final sessionRef = FirebaseFirestore.instance
      .collection('users')
      .doc(studentUid)
      .collection('weeks')
      .doc(weekId)
      .collection('sessions')
      .doc(sessionId);

  // Read the session's existing goal selections.
  final sessionSnapshot = await sessionRef.get();

  final existingGoalIds = List<String>.from(
    sessionSnapshot.data()?['goalIds'] ?? [],
  );

  // Load all goals, including archived goals.
  // This allows editing older sessions.
  final goalsSnapshot = await FirebaseFirestore.instance
      .collection('users')
      .doc(studentUid)
      .collection('goals')
      .get();

  final goals = goalsSnapshot.docs
      .map((doc) => PracticeGoal.fromFirestore(doc))
      .where((goal) =>
          !goal.isArchived ||
          existingGoalIds.contains(goal.id))
      .toList();

  if (!context.mounted) return;

  if (goals.isEmpty) return;

  final selectedGoalIds = existingGoalIds.toSet();

  final shouldSave = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text("What did you work on?"),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView(
                shrinkWrap: true,
                children: goals.map((goal) {
                  return CheckboxListTile(
                    title: Text(goal.title),
                    subtitle: goal.description.isEmpty
                        ? null
                        : Text(goal.description),
                    value: selectedGoalIds.contains(goal.id),
                    onChanged: (checked) {
                      setDialogState(() {
                        if (checked == true) {
                          selectedGoalIds.add(goal.id);
                        } else {
                          selectedGoalIds.remove(goal.id);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () =>
                    Navigator.pop(dialogContext, false),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: gold,
                ),
                onPressed: () =>
                    Navigator.pop(dialogContext, true),
                child: const Text("Save Goals"),
              ),
            ],
          );
        },
      );
    },
  );

  if (shouldSave != true) return;

  await sessionRef.update({
    'goalIds': selectedGoalIds.toList(),
  });
}
