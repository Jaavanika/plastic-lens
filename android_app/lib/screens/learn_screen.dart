import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../services/learning_service.dart';
import '../services/material_repository.dart';
import '../services/progress_service.dart';
import '../widgets/common.dart';
import 'material_details_screen.dart';

String polymerLessonId(String code) => 'polymer-$code';

class LearnScreen extends StatelessWidget {
  const LearnScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final learning = context.watch<LearningService>();
    final materials = context.read<MaterialRepository>().all;
    final quizDone = learning.isDone(ProgressCalculator.quizLessonId);

    Widget tile({required String title, required String subtitle, required bool done, required VoidCallback onTap, Widget? leading}) => Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: leading ?? const Icon(Icons.menu_book_outlined),
            title: Text(title),
            subtitle: Text(subtitle),
            trailing: Icon(done ? Icons.check_circle : Icons.chevron_right, color: done ? Theme.of(context).colorScheme.primary : null),
            onTap: onTap,
          ),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Learn')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 24), children: [
        const SectionTitle('Recycling basics'),
        for (final l in learning.lessons)
          tile(
            title: l.title,
            subtitle: '${l.minutes} min read',
            done: learning.isDone(l.id),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => LessonScreen(lesson: l))),
          ),
        const SectionTitle('Know your polymers'),
        for (final m in materials)
          tile(
            leading: PolymerChip(code: m.code, resinCode: m.resinCode),
            title: m.fullName,
            subtitle: 'Properties, uses and recycling',
            done: learning.isDone(polymerLessonId(m.code)),
            onTap: () async {
              await Navigator.of(context).push(MaterialPageRoute(builder: (_) => MaterialDetailsScreen(code: m.code)));
              await learning.markDone(polymerLessonId(m.code));
            },
          ),
        const SectionTitle('Test yourself'),
        tile(
          leading: const Icon(Icons.quiz_outlined),
          title: 'Recycling quiz',
          subtitle: quizDone ? 'Passed. You can retake it any time' : '${learning.quiz.questions.length} questions · pass with ${learning.quiz.passMark}',
          done: quizDone,
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const QuizScreen())),
        ),
      ]),
    );
  }
}

class LessonScreen extends StatelessWidget {
  const LessonScreen({super.key, required this.lesson});
  final Lesson lesson;

  @override
  Widget build(BuildContext context) {
    final learning = context.watch<LearningService>();
    final done = learning.isDone(lesson.id);
    return Scaffold(
      appBar: AppBar(title: Text(lesson.title)),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        for (final p in lesson.paragraphs)
          Padding(padding: const EdgeInsets.only(bottom: 16), child: Text(p, style: Theme.of(context).textTheme.bodyLarge)),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: done
              ? null
              : () async {
                  await learning.markDone(lesson.id);
                  if (context.mounted) Navigator.of(context).pop();
                },
          icon: Icon(done ? Icons.check : Icons.done_all),
          label: Text(done ? 'Completed' : 'Mark as read'),
        ),
      ]),
    );
  }
}

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key});
  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  int _index = 0;
  int _score = 0;
  int? _chosen;

  @override
  Widget build(BuildContext context) {
    final learning = context.read<LearningService>();
    final quiz = learning.quiz;
    final t = Theme.of(context).textTheme;

    if (_index >= quiz.questions.length) {
      final passed = _score >= quiz.passMark;
      return Scaffold(
        appBar: AppBar(title: const Text('Quiz')),
        body: EmptyState(
          icon: passed ? Icons.emoji_events_outlined : Icons.refresh,
          title: 'You scored $_score / ${quiz.questions.length}',
          message: passed ? 'Well done! Quiz passed.' : 'You need ${quiz.passMark} to pass. Have another go.',
          action: FilledButton(
            onPressed: () => passed ? Navigator.of(context).pop() : setState(() => _index = _score = 0),
            child: Text(passed ? 'Done' : 'Try again'),
          ),
        ),
      );
    }

    final q = quiz.questions[_index];
    return Scaffold(
      appBar: AppBar(title: Text('Question ${_index + 1} of ${quiz.questions.length}')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Text(q.question, style: t.titleLarge),
        const SizedBox(height: 16),
        for (var i = 0; i < q.options.length; i++)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            color: _chosen == null
                ? null
                : i == q.answer
                    ? Colors.green.withValues(alpha: 0.18)
                    : (i == _chosen ? Colors.red.withValues(alpha: 0.15) : null),
            child: ListTile(
              title: Text(q.options[i]),
              onTap: _chosen != null
                  ? null
                  : () => setState(() {
                        _chosen = i;
                        if (i == q.answer) _score++;
                      }),
            ),
          ),
        const SizedBox(height: 12),
        if (_chosen != null)
          FilledButton(
            onPressed: () async {
              final last = _index == quiz.questions.length - 1;
              if (last && _score >= quiz.passMark) await learning.markDone(ProgressCalculator.quizLessonId);
              setState(() {
                _index++;
                _chosen = null;
              });
            },
            child: Text(_index == quiz.questions.length - 1 ? 'See result' : 'Next'),
          ),
      ]),
    );
  }
}
