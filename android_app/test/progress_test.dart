import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:plastic_lens/models/classification.dart';
import 'package:plastic_lens/services/progress_service.dart';

import 'helpers.dart';

/// Section 9 "done when": achievements unlock correctly in a scripted scenario.
void main() {
  final j = jsonDecode(File('assets/data/achievements.json').readAsStringSync()) as Map<String, dynamic>;
  final calc = ProgressCalculator(
    rules: PointRules.fromJson(j['points'] as Map<String, dynamic>),
    achievements: (j['achievements'] as List).map((a) => Achievement.fromJson(a as Map<String, dynamic>)).toList(),
  );
  final now = DateTime(2026, 11, 14, 18);
  DateTime day(int d) => DateTime(2026, 11, d, 10);

  test('new user has nothing', () {
    final p = calc.compute(scans: [], lessonsDone: {}, now: now);
    expect(p.points, 0);
    expect(p.unlocked, isEmpty);
    expect(p.currentStreak, 0);
  });

  test('unreliable scans earn no points or badges', () {
    final p = calc.compute(scans: [
      scan('a', type: 'PET', state: ResultState.low),
      scan('b', type: 'PP', state: ResultState.medium),
    ], lessonsDone: {}, now: now);
    expect(p.points, 0);
    expect(p.unlocked, isEmpty);
  });

  test('verifying a medium scan makes it count, with a bonus', () {
    final p = calc.compute(scans: [scan('b', type: 'PP', state: ResultState.medium, verified: true)], lessonsDone: {}, now: now);
    expect(p.points, 10 + 5);
    expect(p.unlocked, contains('first_scan'));
  });

  test('scripted week: polymers, verification, lessons, quiz and streak', () {
    final scans = [
      scan('1', type: 'PET', at: day(8)),
      scan('2', type: 'HDPE', at: day(9)),
      scan('3', type: 'PVC', at: day(10), verified: true),
      scan('4', type: 'LDPE', at: day(11), verified: true),
      scan('5', type: 'PP', at: day(12), verified: true, saved: true),
      scan('6', type: 'PS', at: day(13)),
      scan('7', state: ResultState.nonPlastic, at: day(14)),
      scan('8', type: 'PET', state: ResultState.low, at: day(14)), // ignored
    ];
    final lessons = {
      'resin-codes': day(14),
      'clean-dry-loose': day(14),
      'polymer-PET': day(14),
      ProgressCalculator.quizLessonId: day(14),
    };
    final p = calc.compute(scans: scans, lessonsDone: lessons, now: now);

    expect(p.metrics['reliable_scans'], 7);
    expect(p.metrics['polymers_found'], 6);
    expect(p.points, 7 * 10 + 3 * 5 + 3 * 15 + 20);
    expect(p.currentStreak, 7);
    expect(p.bestStreak, 7);
    expect(p.unlocked, containsAll(['first_scan', 'three_polymers', 'all_polymers', 'verifier', 'learner', 'quiz_pass', 'streak_3', 'streak_7']));
    expect(p.unlocked, isNot(contains('scans_10')));
    expect(p.unlocked, isNot(contains('collector')));
  });

  test('streak breaks after a missed day but best streak is kept', () {
    final p = calc.compute(scans: [
      scan('1', type: 'PET', at: day(1)),
      scan('2', type: 'PET', at: day(2)),
      scan('3', type: 'PET', at: day(3)),
      scan('4', type: 'PET', at: day(13)),
      scan('5', type: 'PET', at: day(14)),
    ], lessonsDone: {}, now: now);
    expect(p.currentStreak, 2);
    expect(p.bestStreak, 3);
    expect(p.unlocked, contains('streak_3'));
  });

  test('a streak ending yesterday is still current', () {
    final p = calc.compute(scans: [scan('1', type: 'PET', at: day(12)), scan('2', type: 'PET', at: day(13))], lessonsDone: {}, now: now);
    expect(p.currentStreak, 2);
  });
}
