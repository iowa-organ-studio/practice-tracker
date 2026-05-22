import 'package:cloud_firestore/cloud_firestore.dart';

class FirebasePaths {
  static DocumentReference<Map<String, dynamic>>
  userDoc(String uid) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid);
  }

  static DocumentReference<Map<String, dynamic>>
  weekDoc({
    required String uid,
    required String weekId,
  }) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('weeks')
        .doc(weekId);
  }

  static CollectionReference<Map<String, dynamic>>
  sessionsCollection({
    required String uid,
    required String weekId,
  }) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('weeks')
        .doc(weekId)
        .collection('sessions');
  }

  static DocumentReference<Map<String, dynamic>>
  sessionDoc({
    required String uid,
    required String weekId,
    required String sessionId,
  }) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('weeks')
        .doc(weekId)
        .collection('sessions')
        .doc(sessionId);
  }

  static CollectionReference<Map<String, dynamic>>
  conflictsCollection() {
    return FirebaseFirestore.instance
        .collection('conflicts');
  }
}