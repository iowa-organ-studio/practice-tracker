import 'package:cloud_firestore/cloud_firestore.dart';

class ImprovisationTime {
  final String modelId;
  final String modelName;
  int seconds = 0;

  ImprovisationTime({required this.modelId, required this.modelName});
}

class AdditionalWebPracticeReport {
  final List<ImprovisationTime> improvisation;
  final int hymnCount;
  final int hymnSeconds;

  AdditionalWebPracticeReport({
    required this.improvisation,
    required this.hymnCount,
    required this.hymnSeconds,
  });

  int get improvisationSeconds =>
      improvisation.fold<int>(0, (sum, item) => sum + item.seconds);

  double get hymnAverageSeconds => hymnCount == 0 ? 0 : hymnSeconds / hymnCount;
}

class AdditionalWebPracticeReportService {
  static Future<AdditionalWebPracticeReport> generate({
    required String uid,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final start = DateTime(startDate.year, startDate.month, startDate.day);

    final endExclusive = DateTime(endDate.year, endDate.month, endDate.day + 1);

    if (!start.isBefore(endExclusive)) {
      throw ArgumentError('Invalid report date range');
    }

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('webPractice')
        .where('startedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('startedAt', isLessThan: Timestamp.fromDate(endExclusive))
        .get();

    final models = <String, ImprovisationTime>{};

    int hymnCount = 0;
    int hymnSeconds = 0;

    for (final document in snapshot.docs) {
      final data = document.data();
      final app = data['app']?.toString() ?? '';

      final rawDuration = data['durationSeconds'];
      final seconds = rawDuration is num
          ? rawDuration.toInt().clamp(0, 300)
          : 0;

      if (app == 'hymn-tune') {
        hymnCount++;
        hymnSeconds += seconds;
      }

      if (app == 'improvisation-models') {
        final modelId = (data['modelId'] ?? '').toString().trim();

        final modelName = (data['model'] ?? 'Unknown model').toString().trim();

        // Group all phrases belonging to the same
        // improvisation model under one heading.
        final identity = modelName.toLowerCase();

        final model = models.putIfAbsent(
          identity,
          () => ImprovisationTime(modelId: modelId, modelName: modelName),
        );

        model.seconds += seconds;
      }
    }

    final improvisation = models.values.toList()
      ..sort(
        (a, b) =>
            a.modelName.toLowerCase().compareTo(b.modelName.toLowerCase()),
      );

    return AdditionalWebPracticeReport(
      improvisation: improvisation,
      hymnCount: hymnCount,
      hymnSeconds: hymnSeconds,
    );
  }
}
