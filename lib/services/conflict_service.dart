import 'package:cloud_firestore/cloud_firestore.dart';

import 'firebase_paths.dart';

Future<List<DocumentSnapshot>>
loadConflictSessions(
  List<Map<String, dynamic>>
  sessionRefs,
) async {
  return await Future.wait(
    sessionRefs.map((ref) {
      return FirebasePaths
          .sessionDoc(
            uid: ref['uid'],

            weekId:
                ref['weekId'],

            sessionId:
                ref['sessionId'],
          )
          .get();
    }),
  );
}