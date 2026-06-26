/// Durable spaced-repetition state for ONE study deck.
///
/// This is the app's "educational memory" — not a chat log, but the
/// knowledge state that drives WHEN a deck comes back for review and how
/// the app detects that a learner is forgetting. Persists across sessions.
class ReviewState {
  double mastery; // 0..1 demonstrated understanding of this deck
  int repetitions; // consecutive passing reviews (drives the interval)
  double ease; // SM-2 ease factor (how fast intervals grow)
  int intervalDays; // current gap between reviews
  int lastScorePct; // most recent quiz score (0..100)
  DateTime? lastReviewed;
  DateTime? nextReview;

  ReviewState({
    this.mastery = 0.3,
    this.repetitions = 0,
    this.ease = 2.5,
    this.intervalDays = 0,
    this.lastScorePct = 0,
    this.lastReviewed,
    this.nextReview,
  });

  bool get isDue =>
      nextReview != null && !nextReview!.isAfter(DateTime.now());

  bool get isStarted => lastReviewed != null;

  /// Mastered = strong score history AND not currently overdue.
  bool get isMastered => mastery >= 0.8 && repetitions >= 2;

  Map<String, dynamic> toJson() => {
        'mastery': mastery,
        'repetitions': repetitions,
        'ease': ease,
        'intervalDays': intervalDays,
        'lastScorePct': lastScorePct,
        'lastReviewed': lastReviewed?.toIso8601String(),
        'nextReview': nextReview?.toIso8601String(),
      };

  factory ReviewState.fromJson(Map<String, dynamic> j) => ReviewState(
        mastery: (j['mastery'] as num?)?.toDouble() ?? 0.3,
        repetitions: j['repetitions'] ?? 0,
        ease: (j['ease'] as num?)?.toDouble() ?? 2.5,
        intervalDays: j['intervalDays'] ?? 0,
        lastScorePct: j['lastScorePct'] ?? 0,
        lastReviewed: j['lastReviewed'] != null
            ? DateTime.tryParse(j['lastReviewed'])
            : null,
        nextReview:
            j['nextReview'] != null ? DateTime.tryParse(j['nextReview']) : null,
      );
}
