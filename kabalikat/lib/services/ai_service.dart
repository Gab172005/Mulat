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
    const maxLength = 6000;
    final text = documentText.length > maxLength
        ? documentText.substring(0, maxLength)
        : documentText;

    final flashcardsPrompt = '''
You are an expert study assistant proficient in Filipino. Your task is to extract facts ONLY from the provided document, translate the content, and explain it in clear Filipino.
ALL flashcard questions and answers MUST be written in Filipino.
CRITICAL REQUIREMENT: You MUST generate AT LEAST 10 flashcards.
Return ONLY valid JSON. Do not include markdown formatting like ```json.
The JSON must follow this exact structure:
{
  "flashcards": [
    {"front": "[Question in Filipino]", "back": "[Answer in Filipino]"}
  ]
}

Document Text:
$text
''';

    final quizzesPrompt = '''
You are an expert study assistant proficient in Filipino. Your task is to extract facts ONLY from the provided document, translate the content, and explain it in clear Filipino.
ALL quiz questions and choices MUST be written in Filipino.
CRITICAL REQUIREMENT: You MUST generate AT LEAST 10 quizzes.
Return ONLY valid JSON. Do not include markdown formatting like ```json.
The JSON must follow this exact structure:
{
  "quizzes": [
    {"question": "[Question in Filipino]", "options": ["[Option A]", "[Option B]", "[Option C]", "[Option D]"], "answerIndex": 0}
  ]
}

Document Text:
$text
''';

    Future<String> getResponse(String prompt) async {
      if (_canUseLive) {
        try {
          return await _callLlm(prompt, maxTokens: 2000);
        } catch (_) {}
      }
      return await _generateWithOllama(prompt);
    }

    List<dynamic> flashcardsList = [];
    try {
      final responseText = await getResponse(flashcardsPrompt);
      flashcardsList = _parseFlashcardsRobustly(responseText);
    } catch (e) {
      throw Exception('Failed to generate/parse Flashcards: $e');
    }

    List<dynamic> quizzesList = [];
    try {
      final responseText = await getResponse(quizzesPrompt);
      quizzesList = _parseQuizzesRobustly(responseText);
    } catch (e) {
      throw Exception('Failed to generate/parse Quizzes: $e');
    }

    return StudyDeck.fromJson({
      'title': title,
      'flashcards': flashcardsList,
      'quizzes': quizzesList,
    });
  }

  List<dynamic> _parseFlashcardsRobustly(String text) {
    try {
      var cleanText = text.trim();
      if (cleanText.startsWith('```json')) {
        cleanText = cleanText.substring(7);
      } else if (cleanText.startsWith('```')) {
        cleanText = cleanText.substring(3);
      }
      if (cleanText.endsWith('```')) {
        cleanText = cleanText.substring(0, cleanText.length - 3);
      }
      cleanText = cleanText.trim();
      final map = jsonDecode(cleanText);
      if (map['flashcards'] is List) return map['flashcards'];
    } catch (_) {}
    
    String fixed = text.trim();
    int quotes = 0;
    bool escaped = false;
    for (int i = 0; i < fixed.length; i++) {
      if (fixed[i] == '\\') {
        escaped = !escaped;
      } else if (fixed[i] == '"' && !escaped) {
        quotes++;
      } else {
        escaped = false;
      }
    }
    if (quotes % 2 != 0) {
      fixed += '"';
    }
    
    final closings = ['', '}', ']}', '}]}', ']}]}', '}}]}'];
    for (final close in closings) {
      try {
        var cText = (fixed + close).trim();
        if (cText.startsWith('```json')) {
          cText = cText.substring(7);
        } else if (cText.startsWith('```')) {
          cText = cText.substring(3);
        }
        if (cText.endsWith('```')) {
          cText = cText.substring(0, cText.length - 3);
        }
        final map = jsonDecode(cText.trim());
        if (map['flashcards'] is List) {
          return map['flashcards'];
        }
      } catch (_) {}
    }
    
    List<dynamic> fallback = [];
    final regExp = RegExp(r'\{[^}]*\}');
    final matches = regExp.allMatches(text);
    for (final m in matches) {
      try {
        final obj = jsonDecode(m.group(0)!);
        if (obj is Map && obj.containsKey('front') && obj.containsKey('back')) {
          fallback.add(obj);
        }
      } catch (_) {}
    }
    return fallback;
  }

  List<dynamic> _parseQuizzesRobustly(String text) {
    try {
      var cleanText = text.trim();
      if (cleanText.startsWith('```json')) {
        cleanText = cleanText.substring(7);
      } else if (cleanText.startsWith('```')) {
        cleanText = cleanText.substring(3);
      }
      if (cleanText.endsWith('```')) {
        cleanText = cleanText.substring(0, cleanText.length - 3);
      }
      cleanText = cleanText.trim();
      final map = jsonDecode(cleanText);
      if (map['quizzes'] is List) return map['quizzes'];
    } catch (_) {}
    
    String fixed = text.trim();
    int quotes = 0;
    bool escaped = false;
    for (int i = 0; i < fixed.length; i++) {
      if (fixed[i] == '\\') {
        escaped = !escaped;
      } else if (fixed[i] == '"' && !escaped) {
        quotes++;
      } else {
        escaped = false;
      }
    }
    if (quotes % 2 != 0) {
      fixed += '"';
    }
    
    final closings = ['', '}', ']}', '}]}', ']}]}', '}}]}'];
    for (final close in closings) {
      try {
        var cText = (fixed + close).trim();
        if (cText.startsWith('```json')) {
          cText = cText.substring(7);
        } else if (cText.startsWith('```')) {
          cText = cText.substring(3);
        }
        if (cText.endsWith('```')) {
          cText = cText.substring(0, cText.length - 3);
        }
        final map = jsonDecode(cText.trim());
        if (map['quizzes'] is List) {
          return map['quizzes'];
        }
      } catch (_) {}
    }
    
    List<dynamic> fallback = [];
    final regExp = RegExp(r'\{[^}]*\}');
    final matches = regExp.allMatches(text);
    for (final m in matches) {
      try {
        final obj = jsonDecode(m.group(0)!);
        if (obj is Map && obj.containsKey('question') && obj.containsKey('options')) {
          fallback.add(obj);
        }
      } catch (_) {}
    }
    return fallback;
  }

  Future<String> _generateWithOllama(String prompt) async {
    final hosts = Platform.isAndroid ? ['127.0.0.1', '10.0.2.2'] : ['localhost'];
    http.Response? res;
    dynamic lastError;

    for (final host in hosts) {
      try {
        final candidate = await http.post(
          Uri.parse('http://$host:11434/api/generate'),
          headers: {'content-type': 'application/json'},
          body: jsonEncode({
            'model': 'qwen2.5:0.5b',
            'prompt': prompt,
            'stream': false,
            'format': 'json',
            'options': {
              'temperature': 0.1,
              'top_p': 0.9,
              'num_predict': 4096,
              'num_ctx': 8192,
            },
          }),
        );
        if (candidate.statusCode == 200) {
          res = candidate;
          break;
        } else {
          lastError = Exception('Ollama error ${candidate.statusCode}');
        }
      } catch (e) {
        lastError = e;
      }
    }

    if (res == null) {
      if (lastError != null) {
        throw lastError;
      }
      throw Exception('Ollama connection failed');
    }

    final data = jsonDecode(res.body);
    return data['response'] as String;
  }

  // ------------------------------------------------------------ LLM CALL
  Future<String> _callLlm(String prompt, {int maxTokens = 600}) async {
    final res = await http.post(
      Uri.parse(_baseUrl),
      headers: {
        'content-type': 'application/json',
        'x-api-key': storage.apiKey ?? '',
        'anthropic-version': '2023-06-01',
      },
      body: jsonEncode({
        'model': _model,
        'max_tokens': maxTokens,
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
