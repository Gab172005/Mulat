import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../models/student_profile.dart';
import '../models/practice_question.dart';
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

  Future<void> _load() async {
    final state = context.read<AppState>();
    setState(() {
      _loading = true;
      _selected = null;
    });
    final diff = state.adaptiveDifficulty();
    final q = await state.ai
        .nextQuestion(p: state.profile, difficulty: diff, topic: 'General');
    setState(() {
      _q = q;
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
    await state.recordAnswer(_q!.topic, correct);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final fil = state.profile.language == AppLanguage.filipino ||
        state.profile.language == AppLanguage.taglish;

    if (_q == null && !_loading) {
      return _Intro(onStart: _load);
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
              Chip(label: Text('${q.topic} · Level ${q.difficulty}')),
              Text('Score: $_correct/$_answered'),
            ],
          ),
          const SizedBox(height: 16),
          Text(fil ? q.promptFil : q.prompt,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
          const SizedBox(height: 20),
          for (var i = 0; i < q.choices.length; i++)
            _ChoiceTile(
              text: q.choices[i],
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
                      _selected == q.answerIndex ? 'Tama! ✅' : 'Mali — okay lang!',
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
                child: const Text('Next question'),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Difficulty adapts to your mastery (${(state.overallMastery * 100).round()}%).',
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
    Color border = kBorder;
    if (state == _TileState.correct) border = const Color(0xFF6BE39A);
    if (state == _TileState.wrong) border = const Color(0xFFFF9D6B);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: kSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: border, width: state == _TileState.neutral ? 1.0 : 2.0),
          ),
          child: Text(text, style: const TextStyle(fontSize: 16)),
        ),
      ),
    );
  }
}

class _Intro extends StatelessWidget {
  final VoidCallback onStart;
  const _Intro({required this.onStart});

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
            const Text('Adaptive Practice',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text(
              'Questions get easier or harder based on how you answer. '
              'Works offline with cached items.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: onStart, child: const Text('Start practice')),
          ],
        ),
      ),
    );
  }
}
