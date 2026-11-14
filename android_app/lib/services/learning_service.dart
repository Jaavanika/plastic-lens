import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class Lesson {
  const Lesson({required this.id, required this.title, required this.minutes, required this.paragraphs});
  final String id, title;
  final int minutes;
  final List<String> paragraphs;

  factory Lesson.fromJson(Map<String, dynamic> j) => Lesson(
        id: j['id'] as String,
        title: j['title'] as String,
        minutes: j['minutes'] as int,
        paragraphs: List<String>.from(j['paragraphs'] as List),
      );
}

class QuizQuestion {
  const QuizQuestion(this.question, this.options, this.answer);
  final String question;
  final List<String> options;
  final int answer;
}

class Quiz {
  const Quiz(this.passMark, this.questions);
  final int passMark;
  final List<QuizQuestion> questions;
}

/// Learning library content and which lessons the user has finished.
class LearningService extends ChangeNotifier {
  LearningService({required this.lessons, required this.quiz, required this.load, required this.save});

  final List<Lesson> lessons;
  final Quiz quiz;
  final Future<Map<String, DateTime>> Function() load;
  final Future<void> Function(String id, DateTime at) save;
  Map<String, DateTime> _done = {};

  Map<String, DateTime> get done => Map.unmodifiable(_done);
  bool isDone(String id) => _done.containsKey(id);

  static Future<(List<Lesson>, Quiz)> loadContent([AssetBundle? bundle]) async {
    final j = jsonDecode(await (bundle ?? rootBundle).loadString('assets/data/learn.json')) as Map<String, dynamic>;
    final q = j['quiz'] as Map<String, dynamic>;
    return (
      (j['lessons'] as List).map((l) => Lesson.fromJson(l as Map<String, dynamic>)).toList(),
      Quiz(
        q['pass_mark'] as int,
        (q['questions'] as List)
            .map((e) => e as Map<String, dynamic>)
            .map((e) => QuizQuestion(e['q'] as String, List<String>.from(e['options'] as List), e['answer'] as int))
            .toList(),
      ),
    );
  }

  Future<void> init() async {
    _done = await load();
    notifyListeners();
  }

  Future<void> markDone(String id) async {
    if (_done.containsKey(id)) return;
    final now = DateTime.now();
    _done[id] = now;
    await save(id, now);
    notifyListeners();
  }
}
