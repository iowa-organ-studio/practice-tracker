
import 'package:cloud_firestore/cloud_firestore.dart';

enum GoalStatus {
  assigned,
  inProgress,
  studentReportedCompleted,
  teacherCompleted,
}

enum GoalCreator {
  student,
  admin,
}

class PracticeGoal {
  final String id;
  final String studentUid;
  final String title;
  final String description;
  final GoalCreator createdBy;
  final GoalStatus status;
  final DateTime createdAt;
  final DateTime? studentReportedCompletedAt;
  final DateTime? teacherCompletedAt;

  const PracticeGoal({
    required this.id,
    required this.studentUid,
    required this.title,
    required this.description,
    required this.createdBy,
    required this.status,
    required this.createdAt,
    this.studentReportedCompletedAt,
    this.teacherCompletedAt,
  });

  bool get isArchived =>
      status == GoalStatus.teacherCompleted;

  factory PracticeGoal.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;

    return PracticeGoal(
      id: doc.id,
      studentUid: data['studentUid'] as String? ?? '',
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      createdBy: GoalCreator.values.firstWhere(
        (value) => value.name == data['createdBy'],
        orElse: () => GoalCreator.admin,
      ),
      status: GoalStatus.values.firstWhere(
        (value) => value.name == data['status'],
        orElse: () => GoalStatus.assigned,
      ),
      createdAt:
          (data['createdAt'] as Timestamp).toDate(),
      studentReportedCompletedAt:
          (data['studentReportedCompletedAt'] as Timestamp?)
              ?.toDate(),
      teacherCompletedAt:
          (data['teacherCompletedAt'] as Timestamp?)
              ?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'studentUid': studentUid,
      'title': title,
      'description': description,
      'createdBy': createdBy.name,
      'status': status.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'studentReportedCompletedAt':
          studentReportedCompletedAt == null
              ? null
              : Timestamp.fromDate(
                  studentReportedCompletedAt!,
                ),
      'teacherCompletedAt':
          teacherCompletedAt == null
              ? null
              : Timestamp.fromDate(teacherCompletedAt!),
    };
  }
}
