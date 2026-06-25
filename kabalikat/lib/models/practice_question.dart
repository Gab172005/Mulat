/// A multiple-choice practice item. Difficulty 1 (easy) .. 3 (hard).
class PracticeQuestion {
  final String topic;
  final int difficulty;
  final String prompt; // English
  final String promptFil; // Filipino
  final List<String> choices;
  final int answerIndex;
  final String explanation;
  final String explanationFil;

  const PracticeQuestion({
    required this.topic,
    required this.difficulty,
    required this.prompt,
    required this.promptFil,
    required this.choices,
    required this.answerIndex,
    required this.explanation,
    required this.explanationFil,
  });

  factory PracticeQuestion.fromJson(Map<String, dynamic> j) => PracticeQuestion(
        topic: j['topic'] ?? 'General',
        difficulty: j['difficulty'] ?? 1,
        prompt: j['prompt'] ?? '',
        promptFil: j['promptFil'] ?? j['prompt'] ?? '',
        choices: List<String>.from(j['choices'] ?? const []),
        answerIndex: j['answerIndex'] ?? 0,
        explanation: j['explanation'] ?? '',
        explanationFil: j['explanationFil'] ?? j['explanation'] ?? '',
      );
}
