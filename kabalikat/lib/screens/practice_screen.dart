import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../models/practice_question.dart';
import '../strings.dart';
import '../theme.dart';

class PracticeScreen extends StatefulWidget {
  const PracticeScreen({super.key});

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen> {
  PracticeQuestion? _q;
  int? _selected;
  bool _loading = false;
  int _answered = 0;
  int _correct = 0;
  String _focusTopic = '';

  Future<void> _load() async {
    final state = context.read<AppState>();
    setState(() {
      _loading = true;
      _selected = null;
    });
    // Drill the student's weakest topic, at the right level for that topic,
    // skipping anything still on spaced-repetition cooldown.
    final topic = state.weakestTopic();
    final diff = state.difficultyFor(topic);
    final q = await state.ai.nextQuestion(
      p: state.profile,
      difficulty: diff,
      topic: topic,
      exclude: state.cooldownExclude,
    );
    await state.markAsked(q.prompt);
    setState(() {
      _q = q;
      _focusTopic = topic;
      _loading = false;
    });
  }

  Future<void> _choose(int i) async {
    if (_selected != null) return;
    final state = context.read<AppState>();
    final correct = i == _q!.answerIndex;
    setState(() {
      _selected = i;
      _answered++;
      if (correct) _correct++;
    });
    await state.recordAnswer(_q!.topic, correct, _q!.difficulty);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final fil = state.isFilipino;
    final s = S(fil);

    if (_q == null && !_loading) {
      return _Intro(onStart: _load, s: s);
    }
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final q = _q!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Chip(label: Text('${q.topic} · ${s.level} ${q.difficulty}')),
              Text('${s.score}: $_correct/$_answered'),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            s.focus(_focusTopic),
            style: const TextStyle(fontSize: 12, color: Colors.white54),
          ),
          const SizedBox(height: 16),
          Text(fil ? q.promptFil : q.prompt,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
          const SizedBox(height: 20),
          for (var i = 0; i < q.choicesFor(fil).length; i++)
            _ChoiceTile(
              text: q.choicesFor(fil)[i],
              state: _tileState(i, q.answerIndex),
              onTap: () => _choose(i),
            ),
          if (_selected != null) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selected == q.answerIndex ? s.correct() : s.wrong(),
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _selected == q.answerIndex
                              ? const Color(0xFF6BE39A)
                              : const Color(0xFFFF9D6B)),
                    ),
                    const SizedBox(height: 6),
                    Text(fil ? q.explanationFil : q.explanation),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _load,
                child: Text(s.nextQuestion),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              s.difficultyNote(
                  _focusTopic, (state.masteryFor(_focusTopic) * 100).round()),
              style: const TextStyle(fontSize: 12, color: Colors.white54),
            ),
          ],
        ],
      ),
    );
  }

  _TileState _tileState(int i, int answer) {
    if (_selected == null) return _TileState.neutral;
    if (i == answer) return _TileState.correct;
    if (i == _selected) return _TileState.wrong;
    return _TileState.neutral;
  }
}

enum _TileState { neutral, correct, wrong }

class _ChoiceTile extends StatelessWidget {
  final String text;
  final _TileState state;
  final VoidCallback onTap;
  const _ChoiceTile(
      {required this.text, required this.state, required this.onTap});

  @override
  Widget build(BuildContext context) {
    Color border = Colors.white24;
    if (state == _TileState.correct) border = const Color(0xFF6BE39A);
    if (state == _TileState.wrong) border = const Color(0xFFFF9D6B);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: kSurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: border, width: 1.5),
          ),
          child: Text(text, style: const TextStyle(fontSize: 16)),
        ),
      ),
    );
  }
}

class _Intro extends StatelessWidget {
  final VoidCallback onStart;
  final S s;
  const _Intro({required this.onStart, required this.s});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.quiz_outlined, size: 64, color: kAccent),
            const SizedBox(height: 16),
            Text(s.adaptivePractice,
                style:
                    const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              s.practiceIntro,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: onStart, child: Text(s.startPractice)),
          ],
        ),
      ),
    );
  }
}
