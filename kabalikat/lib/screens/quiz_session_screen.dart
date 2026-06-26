import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/study_deck.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../services/l10n_service.dart';

class QuizSessionScreen extends StatefulWidget {
  final StudyDeck deck;
  const QuizSessionScreen({super.key, required this.deck});

  @override
  State<QuizSessionScreen> createState() => _QuizSessionScreenState();
}

class _QuizSessionScreenState extends State<QuizSessionScreen> {
  int _currentIndex = 0;
  int? _selected;
  int _correct = 0;
  bool _sessionDone = false;

  List<Microquiz> get _quizzes => widget.deck.quizzes;
  Microquiz get _current => _quizzes[_currentIndex];

  Future<void> _choose(int i) async {
    if (_selected != null) return;
    final state = context.read<AppState>();
    final correct = i == _current.answerIndex;
    setState(() {
      _selected = i;
      if (correct) _correct++;
    });
    await state.recordAnswer(widget.deck.title, correct);
  }

  void _next() {
    if (_currentIndex < _quizzes.length - 1) {
      setState(() {
        _currentIndex++;
        _selected = null;
      });
    } else {
      // Session finished — record the score so spaced repetition can
      // schedule the next review of this deck (adaptive forgetting curve).
      final pct = (_correct / _quizzes.length * 100).round();
      context.read<AppState>().recordReviewSession(widget.deck.title, pct);
      setState(() => _sessionDone = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_sessionDone) return _buildSummary();

    final q = _current;
    final answered = _currentIndex + (_selected != null ? 1 : 0);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.deck.title),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: (_currentIndex + 1) / _quizzes.length,
            backgroundColor: kBg,
            color: kPrimary,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Chip(label: Text('${_currentIndex + 1} / ${_quizzes.length}')),
                Text('Score: $_correct/$answered'),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              q.question,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 20),
            for (var i = 0; i < q.options.length; i++)
              _ChoiceTile(
                text: q.options[i],
                state: _tileState(i, q.answerIndex),
                onTap: () => _choose(i),
              ),
            if (_selected != null) ...[
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(
                    _selected == q.answerIndex ? 'Tama! ✅' : 'Mali — okay lang! ❌',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _selected == q.answerIndex
                          ? const Color(0xFF6BE39A)
                          : const Color(0xFFFF9D6B),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _next,
                  child: Text(
                    _currentIndex < _quizzes.length - 1
                        ? 'Next question'.tr(context)
                        : 'See results'.tr(context),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSummary() {
    final pct = (_correct / _quizzes.length * 100).round();
    return Scaffold(
      appBar: AppBar(title: Text(widget.deck.title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                pct >= 70 ? Icons.emoji_events : Icons.school,
                size: 72,
                color: pct >= 70 ? kAccent : kPrimary,
              ),
              const SizedBox(height: 16),
              Text(
                '$pct%',
                style: const TextStyle(fontSize: 56, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                '$_correct / ${_quizzes.length} correct',
                style: const TextStyle(fontSize: 18, color: Colors.white70),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Back to Practice'.tr(context)),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  setState(() {
                    _currentIndex = 0;
                    _selected = null;
                    _correct = 0;
                    _sessionDone = false;
                  });
                },
                child: Text('Try again'.tr(context)),
              ),
            ],
          ),
        ),
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
  const _ChoiceTile({required this.text, required this.state, required this.onTap});

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
            border: Border.all(
              color: border,
              width: state == _TileState.neutral ? 1.0 : 2.0,
            ),
          ),
          child: Text(text, style: const TextStyle(fontSize: 16)),
        ),
      ),
    );
  }
}
