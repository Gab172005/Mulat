import 'dart:convert';
import 'dart:io' show Platform;
import 'package:http/http.dart' as http;

import '../models/student_profile.dart';
import '../models/practice_question.dart';
import '../models/study_deck.dart';
import '../data/offline_content.dart';
import 'connectivity_service.dart';
import 'storage_service.dart';

/// Result of a tutor turn: the text plus whether it came from cache.
class TutorReply {
  final String text;
  final bool offline;
  TutorReply(this.text, {this.offline = false});
}

/// Hybrid AI brain.
///  - ONLINE + API key  -> live LLM (bilingual, grade-aware).
///  - OFFLINE / no key   -> bundled cached content (keyword tutor + question bank).
/// Either way the app keeps working; offline is the default, not an error.
class AiService {
  final ConnectivityService connectivity;
  final StorageService storage;

  AiService(this.connectivity, this.storage);

  // Anthropic Messages API. Swap baseUrl/headers for any OpenAI-compatible
  // endpoint if your team prefers.
  static const _baseUrl = 'https://api.anthropic.com/v1/messages';
  static const _model = 'claude-haiku-4-5-20251001';

  bool get _canUseLive =>
      connectivity.isOnline &&
      (storage.apiKey != null && storage.apiKey!.isNotEmpty);

  // ---------------------------------------------------------------- TUTOR
  Future<TutorReply> tutor(String question, StudentProfile p) async {
    if (_canUseLive) {
      try {
        final text = await _callLlm(
          'You are Kabalikat, a patient study companion for a Grade ${p.grade} '
          'Filipino student. ${p.language.promptHint} Keep it short, use a '
          'simple local example, and end with one quick check-question. '
          'Student asks: "$question"',
        );
        return TutorReply(text);
      } catch (_) {
        // fall through to offline
      }
    }
    return TutorReply(_offlineTutor(question, p), offline: true);
  }

  String _offlineTutor(String question, StudentProfile p) {
    final q = question.toLowerCase();
    for (final entry in kOfflineLessons.entries) {
      if (q.contains(entry.key)) {
        final body = p.language == AppLanguage.filipino
            ? entry.value['fil']!
            : p.language == AppLanguage.taglish
                ? '${entry.value['fil']}\n\n(In English: ${entry.value['en']})'
                : entry.value['en']!;
        return body;
      }
    }
    // Generic offline guidance.
    final tips = p.language == AppLanguage.english
        ? "I'm offline right now, so I can't generate a full answer — but here's a tip: break the problem into smaller steps and try a worked example. Reconnect for a detailed explanation, or open Practice for cached exercises."
        : "Offline muna ako kaya hindi pa ako makagawa ng buong sagot — pero subukan mong hatiin sa maliliit na hakbang ang problema. Kumonekta ulit para sa detalyadong paliwanag, o pumunta sa Practice para sa naka-cache na ehersisyo.";
    return tips;
  }

  // ------------------------------------------------------------- PRACTICE
  /// Picks/creates a question at the target difficulty (1..3).
  Future<PracticeQuestion> nextQuestion({
    required StudentProfile p,
    required int difficulty,
    String topic = 'General',
  }) async {
    if (_canUseLive) {
      try {
        return await _generateQuestion(p, difficulty, topic);
      } catch (_) {
        // fall through to offline bank
      }
    }
    return _offlineQuestion(difficulty);
  }

  PracticeQuestion _offlineQuestion(int difficulty) {
    final pool =
        kOfflineQuestions.where((q) => q.difficulty == difficulty).toList();
    final fallback = pool.isNotEmpty ? pool : kOfflineQuestions;
    fallback.shuffle();
    return fallback.first;
  }

  Future<PracticeQuestion> _generateQuestion(
      StudentProfile p, int difficulty, String topic) async {
    final diffLabel = ['', 'easy', 'medium', 'hard'][difficulty];
    final raw = await _callLlm(
      'Create ONE $diffLabel multiple-choice question for a Grade ${p.grade} '
      'Filipino student${topic == 'General' ? '' : ' about $topic'}. '
      'Return ONLY valid JSON with keys: topic, difficulty ($difficulty), '
      'prompt, promptFil, choices (array of 4), answerIndex (0-3), '
      'explanation, explanationFil. promptFil/explanationFil are Filipino.',
    );
    final jsonStr = raw.substring(raw.indexOf('{'), raw.lastIndexOf('}') + 1);
    return PracticeQuestion.fromJson(jsonDecode(jsonStr));
  }

  // ------------------------------------------------------------- DECK GEN
  Future<StudyDeck> generateStudyDeck(String documentText, String title) async {
    // Truncate document text if too long for local model context
    final maxLength = 6000;
    final text = documentText.length > maxLength
        ? documentText.substring(0, maxLength)
        : documentText;

    final prompt = '''
You are a helpful study assistant. Create a study deck from the following document.
Return ONLY valid JSON with no markdown formatting. The JSON must have two keys: "flashcards" and "quizzes".
"flashcards" is an array of objects with "front" (question/concept) and "back" (answer/definition).
"quizzes" is an array of objects with "question", "options" (array of 4 strings), and "answerIndex" (0-3).

Document Text:
$text
''';

    final host = Platform.isAndroid ? '10.0.2.2' : 'localhost';
    final res = await http.post(
      Uri.parse('http://$host:11434/api/generate'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({
        'model': 'llama3.2:latest',
        'prompt': prompt,
        'stream': false,
        'format': 'json',
      }),
    );

    if (res.statusCode != 200) {
      throw Exception('Ollama error ${res.statusCode}');
    }

    final data = jsonDecode(res.body);
    final responseText = data['response'] as String;

    try {
      final jsonMap = jsonDecode(responseText);
      return StudyDeck.fromJson({
        'title': title,
        'flashcards': jsonMap['flashcards'] ?? [],
        'quizzes': jsonMap['quizzes'] ?? [],
      });
    } catch (e) {
      throw Exception('Failed to parse Study Deck JSON from Ollama: $e\\nResponse was: $responseText');
    }
  }

  // ------------------------------------------------------------ LLM CALL
  Future<String> _callLlm(String prompt) async {
    final res = await http.post(
      Uri.parse(_baseUrl),
      headers: {
        'content-type': 'application/json',
        'x-api-key': storage.apiKey ?? '',
        'anthropic-version': '2023-06-01',
      },
      body: jsonEncode({
        'model': _model,
        'max_tokens': 600,
        'messages': [
          {'role': 'user', 'content': prompt}
        ],
      }),
    );
    if (res.statusCode != 200) {
      throw Exception('LLM error ${res.statusCode}');
    }
    final data = jsonDecode(res.body);
    return (data['content'][0]['text'] as String).trim();
  }
}
