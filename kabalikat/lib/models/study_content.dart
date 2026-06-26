/// ─── STUDY CONTENT MODEL ───────────────────────────────────────────
/// Unified container for AI-generated study content.
/// Supports three modes: reviewer, flashcards, micro-quiz.
/// Used by both Gemini (online) and Ollama (offline) pipelines.

class ReviewerItem {
  final String concept;
  final String explanation;
  final String example;

  const ReviewerItem({
    required this.concept,
    required this.explanation,
    this.example = '',
  });

  factory ReviewerItem.fromJson(Map<String, dynamic> json) => ReviewerItem(
        concept: (json['concept'] ?? json['title'] ?? '').toString(),
        explanation: (json['explanation'] ?? json['summary'] ?? '').toString(),
        example: (json['example'] ?? '').toString(),
      );

  Map<String, dynamic> toJson() => {
        'concept': concept,
        'explanation': explanation,
        'example': example,
      };
}

class FlashcardItem {
  final String front;
  final String back;

  const FlashcardItem({required this.front, required this.back});

  factory FlashcardItem.fromJson(Map<String, dynamic> json) => FlashcardItem(
        front: (json['front'] ?? json['question'] ?? '').toString(),
        back: (json['back'] ?? json['answer'] ?? '').toString(),
      );

  Map<String, dynamic> toJson() => {'front': front, 'back': back};
}

class QuizItem {
  final String question;
  final List<String> options;
  final int correctIndex;

  const QuizItem({
    required this.question,
    required this.options,
    required this.correctIndex,
  });

  factory QuizItem.fromJson(Map<String, dynamic> json) {
    final rawOptions = json['options'];
    final List<String> opts = rawOptions is List
        ? rawOptions.map((e) => e.toString()).toList()
        : <String>[];

    var idx = json['correctIndex'] ?? json['answerIndex'] ?? json['answer'] ?? 0;
    int parsedIdx = 0;
    if (idx is int) {
      parsedIdx = idx;
    } else if (idx is String) {
      parsedIdx = int.tryParse(idx) ?? 0;
    }

    return QuizItem(
      question: (json['question'] ?? '').toString(),
      options: opts,
      correctIndex: parsedIdx.clamp(0, opts.isEmpty ? 0 : opts.length - 1),
    );
  }

  Map<String, dynamic> toJson() => {
        'question': question,
        'options': options,
        'correctIndex': correctIndex,
      };
}

/// Unified response from generateStudyContent().
class StudyContent {
  final List<ReviewerItem> reviewers;
  final List<FlashcardItem> flashcards;
  final List<QuizItem> quizzes;
  final bool generatedOffline;

  const StudyContent({
    this.reviewers = const [],
    this.flashcards = const [],
    this.quizzes = const [],
    this.generatedOffline = false,
  });
}
