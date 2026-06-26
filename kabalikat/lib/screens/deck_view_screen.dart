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
      body: widget.deck.flashcards.isEmpty
          ? Center(child: Text('This deck has no flashcards.'.tr(context)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Flashcards'.tr(context), style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  _buildFlashcardView(),
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

}
