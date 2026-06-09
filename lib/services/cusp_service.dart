import 'package:cloud_firestore/cloud_firestore.dart';

import 'firebase_paths.dart';

Future<int> getWeekPracticeTotal({
  required String uid,
  required String weekId,
}) async {
  final snapshot =
      await FirebasePaths.weekDoc(
        uid: uid,
        weekId: weekId,
      ).get();

  if (!snapshot.exists) {
    return 0;
  }

  final data = snapshot.data()!;

  return (data['totalPracticeSeconds']
          as int?) ??
      0;
}