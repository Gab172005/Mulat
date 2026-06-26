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

  // Google Gemini API (key from Google AI Studio: https://aistudio.google.com/apikey).
  // Swap _model for any available Gemini model (e.g. gemini-2.5-flash).
  // Tried in order. If the newest model is overloaded (503), we retry, then
  // fall back to the next, steadier model so the live tier stays up.
  static const _models = ['gemini-3.5-flash', 'gemini-2.5-flash'];
  static const _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models';

  bool get _canUseLive =>
      connectivity.isOnline &&
      (storage.apiKey != null && storage.apiKey!.isNotEmpty);

  String _tutorPrompt(String question, StudentProfile p) =>
      'You are Kabalikat, a patient study companion for a Grade ${p.grade} '
      'Filipino student. ${p.language.promptHint} Keep it short, use a '
      'simple local example, and end with one quick check-question. '
      'Write in plain text only — no Markdown, asterisks, bullets, or headings. '
      'Student asks: "$question"';

  /// Strip leftover Markdown emphasis (**bold**, *italic*) so the plain-text
  /// chat bubble doesn't show literal asterisks.
  String _stripMarkdown(String s) => s
      .replaceAllMapped(RegExp(r'\*\*(.*?)\*\*'), (m) => m[1] ?? '')
      .replaceAll(RegExp(r'(?<!\*)\*(?!\*)'), '')
      .replaceAll(RegExp(r'^#{1,6}\s*', multiLine: true), '')
      .trim();

  // Temporary: surface live-AI errors in the chat so we can debug the key /
  // endpoint. Set back to false once the cloud tier is confirmed working.
  static const bool _debugShowCloudErrors = true;

  // ---------------------------------------------------------------- TUTOR
  Future<TutorReply> tutor(String question, StudentProfile p) async {
    // Tier 1: cloud LLM when online + key.
    if (_canUseLive) {
      try {
        final text = await _callLlm(_tutorPrompt(question, p));
        return TutorReply(_stripMarkdown(text), source: AnswerSource.cloud);
      } catch (e) {
        if (_debugShowCloudErrors) {
          return TutorReply('⚠️ Live AI failed:\n$e', source: AnswerSource.cached);
        }
        // fall through
      }
    }
    // Tier 2: on-device model, if installed (works with no signal).
    if (localModel.isReady) {
      try {
        final text = await localModel.generate(_tutorPrompt(question, p));
        if (text != null && text.trim().isNotEmpty) {
          return TutorReply(_stripMarkdown(text), source: AnswerSource.onDevice);
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
  /// Picks/creates a question for a specific [topic] at [difficulty],
  /// skipping anything in [exclude] (already-answered prompts this session).
  Future<PracticeQuestion> nextQuestion({
    required StudentProfile p,
    required int difficulty,
    required String topic,
    Set<String> exclude = const {},
  }) async {
    if (_canUseLive) {
      try {
        return await _generateQuestion(p, difficulty, topic);
      } catch (_) {
        // fall through to offline bank
      }
    }
    return _offlineQuestion(topic, difficulty, exclude);
  }

  /// Offline picker that stays on-target: prefer the exact topic+difficulty,
  /// then relax step by step, and only repeat a question as a last resort.
  PracticeQuestion _offlineQuestion(
      String topic, int difficulty, Set<String> exclude) {
    final tiers = <bool Function(PracticeQuestion)>[
      (q) => q.topic == topic && q.difficulty == difficulty && !exclude.contains(q.prompt),
      (q) => q.topic == topic && !exclude.contains(q.prompt),
      (q) => q.difficulty == difficulty && !exclude.contains(q.prompt),
      (q) => !exclude.contains(q.prompt),
    ];
    for (final match in tiers) {
      final pool = kOfflineQuestions.where(match).toList();
      if (pool.isNotEmpty) {
        pool.shuffle();
        return pool.first;
      }
    }
    // Everything's been seen — reset and reuse the closest match.
    final reset = kOfflineQuestions
        .where((q) => q.topic == topic && q.difficulty == difficulty)
        .toList();
    final list = reset.isNotEmpty ? reset : List.of(kOfflineQuestions);
    list.shuffle();
    return list.first;
  }

  Future<PracticeQuestion> _generateQuestion(
      StudentProfile p, int difficulty, String topic) async {
    final diffLabel = ['', 'easy', 'medium', 'hard'][difficulty];
    final raw = await _callLlm(
      'Create ONE $diffLabel multiple-choice question for a Grade ${p.grade} '
      'Filipino student${topic == 'General' ? '' : ' about $topic'}. '
      'Return ONLY valid JSON with keys: topic, difficulty ($difficulty), '
      'prompt, promptFil, choices (array of 4), choicesFil (the same 4 '
      'choices in Filipino, same order), answerIndex (0-3), '
      'explanation, explanationFil. promptFil/explanationFil are Filipino.',
    );
    final jsonStr = raw.substring(raw.indexOf('{'), raw.lastIndexOf('}') + 1);
    final map = jsonDecode(jsonStr) as Map<String, dynamic>;
    // Force our canonical topic/difficulty so mastery is tracked consistently
    // (the model sometimes returns "Mathematics" instead of "Math").
    map['topic'] = topic;
    map['difficulty'] = difficulty;
    return PracticeQuestion.fromJson(map);
  }

  // ------------------------------------------------------------ LLM CALL
  Future<String> _callLlm(String prompt) async {
    final key = storage.apiKey ?? '';
    final body = jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': prompt}
          ]
        }
      ],
      'generationConfig': {
        'maxOutputTokens': 800,
        // Disable "thinking": faster replies, and the token budget goes to the
        // actual answer instead of internal reasoning.
        'thinkingConfig': {'thinkingBudget': 0},
      },
    });

    Object? lastError;
    // Try each model; retry transient overloads (503/500/429) with backoff.
    for (final model in _models) {
      for (var attempt = 0; attempt < 2; attempt++) {
        try {
          final res = await http.post(
            Uri.parse('$_baseUrl/$model:generateContent'),
            headers: {'content-type': 'application/json', 'x-goog-api-key': key},
            body: body,
          );
          if (res.statusCode == 200) {
            final data = jsonDecode(res.body);
            return (data['candidates'][0]['content']['parts'][0]['text']
                    as String)
                .trim();
          }
          lastError = 'Gemini error ${res.statusCode}: ${res.body}';
          // Only retry/fall back on transient server issues.
          final transient = res.statusCode == 503 ||
              res.statusCode == 500 ||
              res.statusCode == 429;
          if (!transient) throw Exception(lastError);
          await Future.delayed(Duration(milliseconds: 600 * (attempt + 1)));
        } catch (e) {
          lastError = e;
          await Future.delayed(const Duration(milliseconds: 400));
        }
      }
    }
    throw Exception(lastError ?? 'Gemini call failed');
  }
}
