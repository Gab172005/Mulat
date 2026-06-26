import 'package:uuid/uuid.dart';

class StudyDeck {
  final String id;
  final String title;
  final DateTime createdAt;
  final List<Flashcard> flashcards;
  final List<Microquiz> quizzes;

  StudyDeck({
    String? id,
    required this.title,
    DateTime? createdAt,
    this.flashcards = const [],
    this.quizzes = const [],
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  factory StudyDeck.fromJson(Map<String, dynamic> json) {
    return StudyDeck(
      id: json['id'] as String?,
      title: json['title'] as String,
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
      flashcards: (json['flashcards'] as List?)
              ?.map((e) => Flashcard.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      quizzes: (json['quizzes'] as List?)
              ?.map((e) => Microquiz.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'createdAt': createdAt.toIso8601String(),
      'flashcards': flashcards.map((e) => e.toJson()).toList(),
      'quizzes': quizzes.map((e) => e.toJson()).toList(),
    };
  }
}

class Flashcard {
  final String front;
  final String back;

  Flashcard({required this.front, required this.back});

  factory Flashcard.fromJson(Map<String, dynamic> json) {
    return Flashcard(
      front: (json['front'] ?? json['question'] ?? '').toString(),
      back: (json['back'] ?? json['answer'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'front': front,
      'back': back,
    };
  }
}

class Microquiz {
  final String question;
  final List<String> options;
  final int answerIndex;

  Microquiz({
    required this.question,
    required this.options,
    required this.answerIndex,
  });

  factory Microquiz.fromJson(Map<String, dynamic> json) {
    var rawOptions = json['options'];
    List<String> optionsList = [];
    if (rawOptions is List) {
      optionsList = rawOptions.map((e) => e.toString()).toList();
    }

    var index = json['answerIndex'];
    int parsedIndex = 0;
    if (index is int) {
      parsedIndex = index;
    } else if (index is String) {
      parsedIndex = int.tryParse(index) ?? 0;
    }

    return Microquiz(
      question: (json['question'] ?? '').toString(),
      options: optionsList,
      answerIndex: parsedIndex,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'question': question,
      'options': options,
      'answerIndex': answerIndex,
    };
  }
}
