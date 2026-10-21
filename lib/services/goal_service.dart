
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/practice_goal.dart';

class GoalService {
  static final FirebaseFirestore _db =
      FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>>
      _goals(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('goals');
  }

  // --------------------------------------------------
  // Create a goal
  // --------------------------------------------------

  static Future<String> createGoal({
    required String studentUid,
    required String title,
    String description = '',
    required GoalCreator createdBy,
  }) async {
    final doc = _goals(studentUid).doc();

    final goal = PracticeGoal(
      id: doc.id,
      studentUid: studentUid,
      title: title.trim(),
      description: description.trim(),
      createdBy: createdBy,
      status: GoalStatus.assigned,
      createdAt: DateTime.now(),
    );

    await doc.set(goal.toFirestore());

    return doc.id;
  }

  // --------------------------------------------------
  // Read active goals
  // --------------------------------------------------

  static Stream<List<PracticeGoal>> watchActiveGoals(
    String studentUid,
  ) {
    return _goals(studentUid).snapshots().map((snapshot) {
      final goals = snapshot.docs
          .map(PracticeGoal.fromFirestore)
          .where((goal) => !goal.isArchived)
          .toList();

      goals.sort(
        (a, b) => a.createdAt.compareTo(b.createdAt),
      );

      return goals;
    });
  }

  // --------------------------------------------------
  // Read archived goals, newest first
  // --------------------------------------------------

  static Stream<List<PracticeGoal>> watchArchivedGoals(
    String studentUid,
  ) {
    return _goals(studentUid).snapshots().map((snapshot) {
      final goals = snapshot.docs
          .map(PracticeGoal.fromFirestore)
          .where((goal) => goal.isArchived)
          .toList();

      goals.sort((a, b) {
        final aDate = a.teacherCompletedAt ?? a.createdAt;
        final bDate = b.teacherCompletedAt ?? b.createdAt;
        return bDate.compareTo(aDate);
      });

      return goals;
    });
  }

  // --------------------------------------------------
  // Student reports goal completed
  // --------------------------------------------------

  static Future<void> studentReportCompleted({
    required String studentUid,
    required String goalId,
  }) async {
    await _goals(studentUid).doc(goalId).update({
      'status': GoalStatus.studentReportedCompleted.name,
      'studentReportedCompletedAt':
          FieldValue.serverTimestamp(),
    });
  }

  // --------------------------------------------------
  // Student resumes working on goal
  // --------------------------------------------------

  static Future<void> returnToInProgress({
    required String studentUid,
    required String goalId,
  }) async {
    await _goals(studentUid).doc(goalId).update({
      'status': GoalStatus.inProgress.name,
      'studentReportedCompletedAt': null,
    });
  }

  // --------------------------------------------------
  // Teacher confirms goal completed
  // --------------------------------------------------

  static Future<void> teacherCompleteGoal({
    required String studentUid,
    required String goalId,
  }) async {
    await _goals(studentUid).doc(goalId).update({
      'status': GoalStatus.teacherCompleted.name,
      'teacherCompletedAt': FieldValue.serverTimestamp(),
    });
  }

  // --------------------------------------------------
  // Update title or description
  // --------------------------------------------------

  static Future<void> updateGoal({
    required String studentUid,
    required String goalId,
    required String title,
    required String description,
  }) async {
    await _goals(studentUid).doc(goalId).update({
      'title': title.trim(),
      'description': description.trim(),
    });
  }
}
