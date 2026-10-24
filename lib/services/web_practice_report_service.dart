
import 'package:cloud_firestore/cloud_firestore.dart';

class WebPracticeAppSummary {
  final String appId;
  final String displayName;

  int phraseCount = 0;
  int totalSeconds = 0;

  WebPracticeAppSummary({
    required this.appId,
    required this.displayName,
  });

  double get averageSeconds =>
      phraseCount == 0 ? 0 : totalSeconds / phraseCount;
}

class WebPracticePhrase {
  final String appId;
  final String exercise;

  final Map<String, int> keyCounts = {};

  WebPracticePhrase({
    required this.appId,
    required this.exercise,
  });

  int get total =>
      keyCounts.values.fold<int>(0, (total, n) => total + n);
}

class WebPracticeReport {
  final List<WebPracticeAppSummary> apps;
  final List<WebPracticePhrase> phrases;

  WebPracticeReport({
    required this.apps,
    required this.phrases,
  });

  int get totalPhrases =>
      apps.fold<int>(0, (total, app) => total + app.phraseCount);

  int get totalSeconds =>
      apps.fold<int>(0, (total, app) => total + app.totalSeconds);

  double get averageSeconds =>
      totalPhrases == 0 ? 0 : totalSeconds / totalPhrases;
}

class WebPracticeReportService {
  static const appNames = {
    'js-bach': 'JSB',
    'boyvin': 'Boyvin',
    'cpe-bach': 'CPE',
  };

  // Same 30 keys as the J. S. Bach scoreboard.
  // Uppercase = major; lowercase = minor.
  static const keys = [
    'C', 'G', 'D', 'A',
    'E', 'B', 'F#', 'C#',
    'F', 'Bb', 'Eb', 'Ab',
    'Db', 'Gb', 'Cb',
    'a', 'e', 'b', 'f#',
    'c#', 'g#', 'd#', 'a#',
    'd', 'g', 'c', 'f',
    'bb', 'eb', 'ab',
  ];

  static String? normalizeKey(String value) {
    var text = value
        .trim()
        .replaceFirst(
          RegExp(r'^Current key:\s*', caseSensitive: false),
          '',
        )
        .replaceAll('♯', '#')
        .replaceAll('♭', 'b');

    final isMinor = RegExp(
      r'\bminor\b',
      caseSensitive: false,
    ).hasMatch(text);

    text = text.replaceAll(
      RegExp(r'\b(major|minor)\b', caseSensitive: false),
      '',
    ).trim();

    if (!RegExp(r'^[A-Ga-g][#b]?$').hasMatch(text)) {
      return null;
    }

    final letter = isMinor
        ? text[0].toLowerCase()
        : text[0].toUpperCase();

    final key = letter + text.substring(1);

    return keys.contains(key) ? key : null;
  }

  static int compareNaturally(String a, String b) {
    final pattern = RegExp(r'(\d+)|(\D+)');

    final aParts = pattern
        .allMatches(a.toLowerCase())
        .map((m) => m.group(0)!)
        .toList();

    final bParts = pattern
        .allMatches(b.toLowerCase())
        .map((m) => m.group(0)!)
        .toList();

    final count = aParts.length < bParts.length
        ? aParts.length
        : bParts.length;

    for (var i = 0; i < count; i++) {
      final aNum = int.tryParse(aParts[i]);
      final bNum = int.tryParse(bParts[i]);

      int result;

      if (aNum != null && bNum != null) {
        result = aNum.compareTo(bNum);
      } else {
        result = aParts[i].compareTo(bParts[i]);
      }

      if (result != 0) return result;
    }

    return aParts.length.compareTo(bParts.length);
  }

  static Future<WebPracticeReport> generate({
    required String uid,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final firstDay = DateTime(
      startDate.year,
      startDate.month,
      startDate.day,
    );

    final lastDayExclusive = DateTime(
      endDate.year,
      endDate.month,
      endDate.day + 1,
    );

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('webPractice')
        .get();

    final summaries = {
      for (final entry in appNames.entries)
        entry.key: WebPracticeAppSummary(
          appId: entry.key,
          displayName: entry.value,
        ),
    };

    final phraseMap = <String, WebPracticePhrase>{};

    for (final doc in snapshot.docs) {
      final data = doc.data();

      final appId = data['app']?.toString();

      if (appId == null || !summaries.containsKey(appId)) {
        continue;
      }

      final timestamp = data['startedAt'];

      if (timestamp is! Timestamp) continue;

      final startedAt = timestamp.toDate().toLocal();

      if (startedAt.isBefore(firstDay) ||
          !startedAt.isBefore(lastDayExclusive)) {
        continue;
      }

      final summary = summaries[appId]!;

      summary.phraseCount++;

      final rawDuration = data['durationSeconds'];

      final seconds = rawDuration is num
          ? rawDuration.toInt().clamp(0, 300)
          : 0;

      summary.totalSeconds += seconds;

      final exercise =
          (data['exercise'] ?? 'Unknown exercise').toString();

      final rawKey = (data['key'] ?? '').toString();

      final key = normalizeKey(rawKey);

      if (key == null) continue;

      final phraseId = '$appId::$exercise';

      final phrase = phraseMap.putIfAbsent(
        phraseId,
        () => WebPracticePhrase(
          appId: appId,
          exercise: exercise,
        ),
      );

      phrase.keyCounts[key] =
          (phrase.keyCounts[key] ?? 0) + 1;
    }

    final phrases = phraseMap.values.toList()
      ..sort((a, b) {
        final appOrder = appNames.keys.toList();

        final appComparison = appOrder
            .indexOf(a.appId)
            .compareTo(appOrder.indexOf(b.appId));

        if (appComparison != 0) return appComparison;

        return compareNaturally(a.exercise, b.exercise);
      });

    return WebPracticeReport(
      apps: summaries.values.toList(),
      phrases: phrases,
    );
  }
}
