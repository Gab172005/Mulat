import 'package:flutter/material.dart';
import '../models/study_deck.dart';
import '../services/l10n_service.dart';

class DeckViewScreen extends StatefulWidget {
  final StudyDeck deck;
  const DeckViewScreen({super.key, required this.deck});

  @override
  State<DeckViewScreen> createState() => _DeckViewScreenState();
}

class _DeckViewScreenState extends State<DeckViewScreen> {
  int _currentCardIndex = 0;
  bool _isFlipped = false;

  void _nextCard() {
    if (_currentCardIndex < widget.deck.flashcards.length - 1) {
      setState(() {
        _currentCardIndex++;
        _isFlipped = false;
      });
    }
  }

  void _prevCard() {
    if (_currentCardIndex > 0) {
      setState(() {
        _currentCardIndex--;
        _isFlipped = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.deck.title),
      ),
      body: widget.deck.flashcards.isEmpty && widget.deck.quizzes.isEmpty
          ? Center(child: Text('This deck is empty.'.tr(context)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.deck.flashcards.isNotEmpty) ...[
                    Text('Flashcards'.tr(context), style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    _buildFlashcardView(),
                    const SizedBox(height: 24),
                  ],
                  if (widget.deck.quizzes.isNotEmpty) ...[
                    Text('Microquizzes'.tr(context), style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    ...widget.deck.quizzes.map((q) => _buildQuizCard(q)),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildFlashcardView() {
    final card = widget.deck.flashcards[_currentCardIndex];
    return Column(
      children: [
        GestureDetector(
          onTap: () => setState(() => _isFlipped = !_isFlipped),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: 200,
            width: double.infinity,
            alignment: Alignment.center,
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                  color: _isFlipped ? Theme.of(context).colorScheme.primary : Colors.white12,
                  width: _isFlipped ? 2.0 : 1.0),
            ),
            child: Text(
              _isFlipped ? card.back : card.front,
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).textTheme.bodyLarge?.color),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: _currentCardIndex > 0 ? _prevCard : null,
            ),
            Text('${_currentCardIndex + 1} / ${widget.deck.flashcards.length}'),
            IconButton(
              icon: const Icon(Icons.arrow_forward),
              onPressed: _currentCardIndex < widget.deck.flashcards.length - 1 ? _nextCard : null,
            ),
          ],
        )
      ],
    );
  }

  Widget _buildQuizCard(Microquiz quiz) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(quiz.question, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            ...quiz.options.asMap().entries.map((entry) {
              final idx = entry.key;
              final text = entry.value;
              return ListTile(
                title: Text(text),
                leading: CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  child: Text('${idx + 1}', style: TextStyle(color: Theme.of(context).colorScheme.primary)),
                ),
                onTap: () {
                  final isCorrect = idx == quiz.answerIndex;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(isCorrect ? 'Correct!' : 'Incorrect. Try again.'),
                      backgroundColor: isCorrect ? Colors.green : Colors.red,
                      duration: const Duration(seconds: 1),
                    ),
                  );
                },
              );
            }),
          ],
        ),
      ),
    );
  }
}
