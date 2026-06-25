import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/student_profile.dart';
import '../models/practice_question.dart';
import '../data/offline_content.dart';
import 'connectivity_service.dart';
import 'storage_service.dart';
import 'local_model_service.dart';

/// Where a tutor answer came from — drives the badge shown in chat.
enum AnswerSource { cloud, onDevice, cached }

/// Result of a tutor turn: the text plus which tier produced it.
class TutorReply {
  final String text;
  final AnswerSource source;
  TutorReply(this.text, {this.source = AnswerSource.cloud});

  bool get offline => source != AnswerSource.cloud;
}

/// Hybrid AI brain — three tiers of graceful degradation:
///  1. ONLINE + API key      -> cloud LLM (best quality, bilingual, grade-aware)
///  2. OFFLINE + local model  -> on-device LLM (real AI, no signal)
///  3. OFFLINE / no model     -> bundled cached content (always works)
/// The app keeps teaching no matter what; each tier is a fallback, not an error.
class AiService {
  final ConnectivityService connectivity;
  final StorageService storage;
  final LocalModelService localModel;

  AiService(this.connectivity, this.storage, this.localModel);

  // Anthropic Messages API. Swap baseUrl/headers for any OpenAI-compatible
  // endpoint if your team prefers.
  static const _baseUrl = 'https://api.anthropic.com/v1/messages';
  static const _model = 'claude-haiku-4-5-20251001';

  bool get _canUseLive =>
      connectivity.isOnline &&
      (storage.apiKey != null && storage.apiKey!.isNotEmpty);

  String _tutorPrompt(String question, StudentProfile p) =>
      'You are Kabalikat, a patient study companion for a Grade ${p.grade} '
      'Filipino student. ${p.language.promptHint} Keep it short, use a '
      'simple local example, and end with one quick check-question. '
      'Student asks: "$question"';

  // ---------------------------------------------------------------- TUTOR
  Future<TutorReply> tutor(String question, StudentProfile p) async {
    // Tier 1: cloud LLM when online + key.
    if (_canUseLive) {
      try {
        final text = await _callLlm(_tutorPrompt(question, p));
        return TutorReply(text, source: AnswerSource.cloud);
      } catch (_) {
        // fall through
      }
    }
    // Tier 2: on-device model, if installed (works with no signal).
    if (localModel.isReady) {
      try {
        final text = await localModel.generate(_tutorPrompt(question, p));
        if (text != null && text.trim().isNotEmpty) {
          return TutorReply(text.trim(), source: AnswerSource.onDevice);
        }
      } catch (_) {
        // fall through
      }
    }
    // Tier 3: bundled cached content (always available).
    return TutorReply(_offlineTutor(question, p), source: AnswerSource.cached);
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
