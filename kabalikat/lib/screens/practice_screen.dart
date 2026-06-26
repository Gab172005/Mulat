import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/l10n_service.dart';
import '../services/spaced_repetition.dart';
import '../state/app_state.dart';
import '../models/study_deck.dart';
import '../models/review_state.dart';
import '../theme.dart';
import 'quiz_session_screen.dart';

class PracticeScreen extends StatelessWidget {
  const PracticeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final decks =
        state.decks.where((d) => d.quizzes.isNotEmpty).toList();

    if (decks.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.quiz_outlined, size: 64, color: kAccent),
              const SizedBox(height: 16),
              Text(
                'No practice quizzes yet'.tr(context),
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Upload a document in the Decks tab to generate practice quizzes.'
                    .tr(context),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
      );
    }

    // ── ADAPTIVE ORDERING ──────────────────────────────────────────────
    // Spaced repetition decides what to study first: decks that are due for
    // review surface at the top, then the weakest decks, then the rest.
    decks.sort((a, b) {
      final dueA = state.isDue(a.title);
      final dueB = state.isDue(b.title);
      if (dueA != dueB) return dueA ? -1 : 1;
      final ma = state.masteryFor(a.title);
      final mb = state.masteryFor(b.title);
      if (ma != mb) return ma.compareTo(mb); // weakest first
      return a.title.compareTo(b.title);
    });

    final dueCount = state.dueDeckTitles.length;

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: decks.length + 1,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (index == 0) return _Header(dueCount: dueCount);
        return _QuizDeckCard(deck: decks[index - 1]);
      },
    );
  }
}

class _Header extends StatelessWidget {
  final int dueCount;
  const _Header({required this.dueCount});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Adaptive Practice'.tr(context),
              style:
                  const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(
            dueCount > 0
                ? '$dueCount ${'Due for review'.tr(context).toLowerCase()}'
                : 'Keep going 💪',
            style: const TextStyle(color: Colors.white60, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _QuizDeckCard extends StatelessWidget {
  final StudyDeck deck;
  const _QuizDeckCard({required this.deck});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final mastery = state.mastery[deck.title];
    final review = state.reviewFor(deck.title);
    final due = review?.isDue ?? false;

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => QuizSessionScreen(deck: deck)),
      ),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: due ? kAccent : kBorder,
            width: due ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: kPrimary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.quiz_outlined, color: kPrimary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    deck.title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 16),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        '${deck.quizzes.length} questions',
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 13),
                      ),
                      const SizedBox(width: 8),
                      _StatusChip(review: review),
                    ],
                  ),
                  if (mastery != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: LinearProgressIndicator(
                            value: mastery,
                            backgroundColor: kBg,
                            color: kPrimary,
                            borderRadius: BorderRadius.circular(4),
                            minHeight: 4,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${(mastery * 100).round()}%',
                          style: const TextStyle(
                              fontSize: 11, color: Colors.white54),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_ios,
                size: 16, color: Colors.white38),
          ],
        ),
      ),
    );
  }
}

/// Small pill showing the spaced-repetition status of a deck.
class _StatusChip extends StatelessWidget {
  final ReviewState? review;
  const _StatusChip({required this.review});

  @override
  Widget build(BuildContext context) {
    final r = review;
    if (r == null || !r.isStarted) return const SizedBox.shrink();

    String label;
    Color color;
    if (r.isDue) {
      label = 'Review due'.tr(context);
      color = kAccent;
    } else if (r.isMastered) {
      label = 'Mastered'.tr(context);
      color = const Color(0xFF6BE39A);
    } else {
      label = SpacedRepetition.dueLabel(r);
      color = Colors.white54;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, color: color, fontWeight: FontWeight.w600)),
    );
  }
}
