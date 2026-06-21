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

/// Reads the frozen gold-star flag for a single user's CUSP for a given
/// week. Returns false if the CUSP doc doesn't exist or the flag was
/// never set (i.e. that user did not win gold star that week).
Future<bool> getIsGoldStar({
  required String uid,
  required String weekId,
}) async {
  final snapshot = await FirebasePaths.weekDoc(
    uid: uid,
    weekId: weekId,
  ).get();

  if (!snapshot.exists) {
    return false;
  }

  final data = snapshot.data()!;

  return (data['isGoldStar'] as bool?) ?? false;
}

/// Writes the frozen gold-star flag onto a single user's CUSP for a given
/// week. Called exactly once per week, at freeze time, only for the
/// winning user.
Future<void> setIsGoldStar({
  required String uid,
  required String weekId,
  required bool value,
}) async {
  await FirebasePaths.weekDoc(
    uid: uid,
    weekId: weekId,
  ).set({'isGoldStar': value}, SetOptions(merge: true));
}