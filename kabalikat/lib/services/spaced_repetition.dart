import '../models/review_state.dart';

/// A lightweight SM-2-style scheduler. After a deck is reviewed, it comes
/// back on expanding intervals when the learner does well, and much sooner
/// when they slip. This is how Kabalikat "detects forgetting" and keeps
/// knowledge fresh instead of being a one-and-done quiz app.
///
/// Adapted to Kabalikat's document-driven decks (the upstream prototype
/// used a fixed curriculum graph; here each generated deck is a unit).
class SpacedRepetition {
  /// Pass threshold — a quiz score at/above this counts as "remembered".
  static const double passThreshold = 0.7;

  /// Update [state] after a quiz session that scored [scorePct] (0..100).
  static void recordSession(ReviewState state, int scorePct) {
    final passed = scorePct >= passThreshold * 100;
    final now = DateTime.now();

    state.lastScorePct = scorePct;
    state.lastReviewed = now;

    // Nudge mastery toward the achieved score (exponential moving average),
    // so a single lucky/unlucky run doesn't swing it wildly.
    final target = (scorePct / 100).clamp(0.0, 1.0);
    state.mastery = (state.mastery * 0.6 + target * 0.4).clamp(0.0, 1.0);

    if (!passed) {
      // Forgot it — reset the streak and bring it back tomorrow.
      state.repetitions = 0;
      state.intervalDays = 1;
      state.ease = (state.ease - 0.2).clamp(1.3, 3.0);
      state.nextReview = now.add(const Duration(days: 1));
      return;
    }

    state.repetitions += 1;
    if (state.repetitions == 1) {
      state.intervalDays = 1;
    } else if (state.repetitions == 2) {
      state.intervalDays = 3;
    } else {
      state.intervalDays =
          (state.intervalDays * state.ease).round().clamp(1, 365);
    }
    // Higher scores grow the ease (and thus the interval) a little faster.
    final easeBonus = scorePct >= 90 ? 0.15 : 0.08;
    state.ease = (state.ease + easeBonus).clamp(1.3, 3.0);
    state.nextReview = now.add(Duration(days: state.intervalDays));
  }

  /// Human-friendly "due in N days" / "due now" label.
  static String dueLabel(ReviewState state) {
    final nr = state.nextReview;
    if (nr == null) return 'New';
    final diff = nr.difference(DateTime.now());
    if (diff.isNegative || diff.inHours < 12) return 'Review due';
    final days = (diff.inHours / 24).ceil();
    if (days <= 1) return 'Due tomorrow';
    return 'Due in $days days';
  }
}
