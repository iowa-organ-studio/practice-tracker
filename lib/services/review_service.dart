import 'package:cloud_firestore/cloud_firestore.dart';

import 'firebase_paths.dart';

class ReviewSession {
  final Map<String, dynamic> data;

  final String weekId;

  final String sessionId;

  ReviewSession({
    required this.data,
    required this.weekId,
    required this.sessionId,
  });
}

Future<List<ReviewSession>>
loadReviewSessions(
  String uid,
) async {
  final weeks =
      await FirebaseFirestore
          .instance
          .collection('users')
          .doc(uid)
          .collection('weeks')
          .get();

  List<ReviewSession>
  sessions = [];

  for (final weekDoc
      in weeks.docs) {
    final weekId =
        weekDoc.id;

    final sessionSnapshot =
        await FirebasePaths
            .sessionsCollection(
              uid: uid,
              weekId: weekId,
            )
            .get();

    for (final doc
        in sessionSnapshot.docs) {
      sessions.add(
        ReviewSession(
          data: doc.data(),

          weekId: weekId,

          sessionId: doc.id,
        ),
      );
    }
  }

  sessions.sort((a, b) {
    final aStart =
        (a.data['startTime']
                as Timestamp)
            .toDate();

    final bStart =
        (b.data['startTime']
                as Timestamp)
            .toDate();

    return bStart.compareTo(
      aStart,
    );
  });

  return sessions;
}