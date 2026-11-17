import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/scan_record.dart';

class Achievement {
  const Achievement({required this.id, required this.title, required this.description, required this.icon, required this.metric, required this.target});
  final String id, title, description, icon, metric;
  final int target;

  factory Achievement.fromJson(Map<String, dynamic> j) => Achievement(
        id: j['id'] as String,
        title: j['title'] as String,
        description: j['description'] as String,
        icon: j['icon'] as String,
        metric: j['metric'] as String,
        target: j['target'] as int,
      );
}

class PointRules {
  const PointRules({this.reliableScan = 10, this.verification = 5, this.lesson = 15, this.quizPass = 20});
  final int reliableScan, verification, lesson, quizPass;

  factory PointRules.fromJson(Map<String, dynamic> j) => PointRules(
        reliableScan: j['reliable_scan'] as int,
        verification: j['verification'] as int,
        lesson: j['lesson'] as int,
        quizPass: j['quiz_pass'] as int,
      );
}

class Progress {
  const Progress({
    required this.points,
    required this.currentStreak,
    required this.bestStreak,
    required this.metrics,
    required this.unlocked,
  });
  final int points;
  final int currentStreak;
  final int bestStreak;
  final Map<String, int> metrics;
  final Set<String> unlocked;

  Map<String, Object?> toFirestore() => {
        'points': points,
        'current_streak': currentStreak,
        'best_streak': bestStreak,
        'badges': unlocked.toList()..sort(),
      };
}

/// Points, streaks and badges derived from scans and lessons (identification spec §14).
///
/// Everything is recomputed from the records, so results are deterministic,
/// work offline and cannot drift. Unreliable predictions earn nothing.
class ProgressCalculator {
  const ProgressCalculator({required this.rules, required this.achievements});
  final PointRules rules;
  final List<Achievement> achievements;

  static const quizLessonId = 'quiz';

  /// A scan counts if the app trusted it or the user verified it.
  static bool earnsPoints(ScanRecord s) => s.isReliable;

  Progress compute({required List<ScanRecord> scans, required Map<String, DateTime> lessonsDone, DateTime? now}) {
    final today = _day(now ?? DateTime.now());
    final reliable = scans.where(earnsPoints).toList();
    final verified = scans.where((s) => s.userVerified).length;
    final lessons = lessonsDone.keys.where((k) => k != quizLessonId).length;
    final quizPassed = lessonsDone.containsKey(quizLessonId) ? 1 : 0;
    final polymers = {for (final s in reliable) if (s.plasticType != null) s.plasticType!};

    final points = reliable.length * rules.reliableScan +
        verified * rules.verification +
        lessons * rules.lesson +
        quizPassed * rules.quizPass;

    final activeDays = <DateTime>{
      for (final s in reliable) _day(s.createdAt),
      for (final d in lessonsDone.values) _day(d.toLocal()),
    };
    final (current, best) = _streaks(activeDays, today);

    final metrics = {
      'reliable_scans': reliable.length,
      'verified_scans': verified,
      'polymers_found': polymers.length,
      'collection_size': scans.where((s) => s.inCollection).length,
      'lessons_done': lessons,
      'quiz_passed': quizPassed,
      'best_streak': best,
    };
    return Progress(
      points: points,
      currentStreak: current,
      bestStreak: best,
      metrics: metrics,
      unlocked: {for (final a in achievements) if ((metrics[a.metric] ?? 0) >= a.target) a.id},
    );
  }

  static DateTime _day(DateTime t) => DateTime(t.year, t.month, t.day);

  /// (current streak ending today or yesterday, best streak ever).
  static (int, int) _streaks(Set<DateTime> days, DateTime today) {
    if (days.isEmpty) return (0, 0);
    final sorted = days.toList()..sort();
    var best = 1, run = 1;
    for (var i = 1; i < sorted.length; i++) {
      run = sorted[i].difference(sorted[i - 1]).inDays == 1 ? run + 1 : 1;
      if (run > best) best = run;
    }
    var current = 0;
    var cursor = days.contains(today) ? today : today.subtract(const Duration(days: 1));
    while (days.contains(cursor)) {
      current++;
      cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
    }
    return (current, best);
  }
}

/// App-facing wrapper: loads rules, recomputes when scans/lessons change.
class ProgressService extends ChangeNotifier {
  ProgressService(this.calculator);
  final ProgressCalculator calculator;
  Progress? _progress;
  Set<String> _previouslyUnlocked = {};

  /// Badges unlocked by the latest change (for a celebration snackbar).
  Set<String> newlyUnlocked = {};

  Progress get progress => _progress!;
  List<Achievement> get achievements => calculator.achievements;

  static Future<ProgressCalculator> loadCalculator([AssetBundle? bundle]) async {
    final j = jsonDecode(await (bundle ?? rootBundle).loadString('assets/data/achievements.json')) as Map<String, dynamic>;
    return ProgressCalculator(
      rules: PointRules.fromJson(j['points'] as Map<String, dynamic>),
      achievements: (j['achievements'] as List).map((a) => Achievement.fromJson(a as Map<String, dynamic>)).toList(),
    );
  }

  void update(List<ScanRecord> scans, Map<String, DateTime> lessonsDone) {
    final next = calculator.compute(scans: scans, lessonsDone: lessonsDone);
    newlyUnlocked = _progress == null ? {} : next.unlocked.difference(_previouslyUnlocked);
    _previouslyUnlocked = next.unlocked;
    _progress = next;
    notifyListeners();
  }
}
