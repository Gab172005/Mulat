import 'dart:convert';
import 'dart:io' show Platform;
import 'package:http/http.dart' as http;

import '../models/student_profile.dart';
import '../models/practice_question.dart';
import '../models/study_deck.dart';
import '../models/study_content.dart';
import '../data/offline_content.dart';
import '../services/prompt_builder.dart';
import '../services/json_parser.dart';
import 'connectivity_service.dart';
import 'storage_service.dart';

/// Result of a tutor turn: the text plus whether it came from cache.
class TutorReply {
  final String text;
  final bool offline;
  TutorReply(this.text, {this.offline = false});
}

/// ─── HYBRID AI SERVICE ───────────────────────────────────────────────
/// Repository-pattern AI brain that routes between TWO backends:
///
///   ┌────────────────────┐
///   │ ConnectivityManager │
///   └────────┬───────────┘
///            │ isOnline?
///     ┌──────┴──────┐
///     ▼             ▼
///  ┌──────┐   ┌──────────┐
///  │Gemini│   │  Ollama   │
///  │ API  │   │ localhost │
///  └──────┘   └──────────┘
///     │             │
///     └──────┬──────┘
///            ▼
///    SecureJsonParser
///            │
///            ▼
///     StudyContent / StudyDeck
///
/// OFFLINE-FALLBACK MECHANICS:
/// 1. Check ConnectivityManager.isOnline FIRST.
/// 2. If online AND Gemini API key exists → call Gemini.
/// 3. If online call fails → fall through to Ollama.
/// 4. If offline → go directly to Ollama.
/// 5. If Ollama also fails → return bundled offline content.
///
/// This ensures the app NEVER crashes due to network issues.
class AiService {
  final ConnectivityManager connectivity;
  final StorageService storage;

  AiService(this.connectivity, this.storage);

  // ── Gemini API Configuration ───────────────────────────────────────
  // Using Google's Generative AI REST API directly for simplicity.
  // The API key is stored in StorageService (set by user in Settings).
  static const _geminiModel = 'gemini-2.0-flash-lite';

  String get _geminiUrl =>
      'https://generativelanguage.googleapis.com/v1beta/models/$_geminiModel:generateContent?key=${storage.apiKey ?? ''}';

  // ── Ollama Configuration ───────────────────────────────────────────
  // Model priority:
  //   1. kabalikat — custom Modelfile with baked params + system prompt
  //   2. Explicit quantization tags for quality/speed sweet spots
  //   3. Smaller fallbacks for low-memory devices
  static const _ollamaModels = [
    'kabalikat',                       // Custom Modelfile (preferred)
    'llama3.2:3b-instruct-q4_K_M',    // Explicit quant for quality
    'llama3.2:3b',                     // Default quant fallback
    'gemma2:2b-instruct-q5_K_M',      // Gemma needs q5 for Taglish
    'gemma2:2b',                       // Default Gemma fallback
    'llama3.2:1b-instruct-q8_0',      // 1B needs q8 to compensate
    'qwen2.5:0.5b',                    // Emergency fallback
  ];

  bool get _canUseGemini =>
      connectivity.isOnline &&
      (storage.apiKey != null && storage.apiKey!.isNotEmpty);

  // ══════════════════════════════════════════════════════════════════
  //  REPOSITORY PATTERN: generateStudyContent()
  // ══════════════════════════════════════════════════════════════════
  /// The main entry point. Routes to Gemini or Ollama based on
  /// connectivity. Mode can be 'reviewer', 'flashcards', or 'quiz'.
  ///
  /// Returns a [StudyContent] with parsed items. Never throws to the
  /// UI — wraps all errors and returns empty content on total failure.
  Future<StudyContent> generateStudyContent(
    String extractedText,
    String mode,
  ) async {
    // Map string mode to enum.
    final contentMode = switch (mode) {
      'reviewer' => ContentMode.reviewer,
      'flashcards' => ContentMode.flashcards,
      'quiz' => ContentMode.quiz,
      _ => ContentMode.flashcards, // Default to flashcards.
    };

    // Smart truncate: preserve sentence boundaries instead of cutting
    // mid-sentence, which confuses small models.
    final text = _smartTruncate(extractedText);

    // ── ROUTE 1: Try Gemini (online) ─────────────────────────────
    if (_canUseGemini) {
      try {
        final raw = await _callGemini(
          _buildGeminiPrompt(text, contentMode),
          maxTokens: 4096,
        );
        final content = _parseResponse(raw, contentMode, offline: false);
        if (_hasContent(content)) return content;
        // If Gemini returned empty/bad JSON, fall through to Ollama.
      } catch (e) {
        print('[AiService] Gemini failed, falling back to Ollama: $e');
      }
    }

    // ── ROUTE 2: Try Ollama (offline / fallback) ─────────────────
    try {
      final prompts = buildOllamaPrompt(
        extractedText: text,
        mode: contentMode,
      );
      final raw = await _callOllama(prompts.system, prompts.user);
      return _parseResponse(raw, contentMode, offline: true);
    } catch (e) {
      print('[AiService] Ollama also failed: $e');
      // Return empty content — UI handles gracefully.
      return const StudyContent(generatedOffline: true);
    }
  }

  // ══════════════════════════════════════════════════════════════════
  //  LEGACY: generateStudyDeck() — backwards compatible
  // ══════════════════════════════════════════════════════════════════
  /// Generates a full StudyDeck (flashcards + quizzes) for the Decks
  /// screen. Uses generateStudyContent() internally.
  Future<StudyDeck> generateStudyDeck(String documentText, String title) async {
    // Smart truncate: preserve sentence boundaries.
    final text = _smartTruncate(documentText);

    // Generate flashcards and quizzes in parallel for speed.
    final results = await Future.wait([
      generateStudyContent(text, 'flashcards'),
      generateStudyContent(text, 'quiz'),
    ]);

    final flashcardContent = results[0];
    final quizContent = results[1];

    // Convert StudyContent models to StudyDeck models.
    final flashcards = flashcardContent.flashcards
        .map((f) => Flashcard(front: f.front, back: f.back))
        .toList();

    final quizzes = quizContent.quizzes
        .map((q) => Microquiz(
              question: q.question,
              options: q.options,
              answerIndex: q.correctIndex,
            ))
        .toList();

    return StudyDeck(
      title: title,
      flashcards: flashcards,
      quizzes: quizzes,
    );
  }

  // ══════════════════════════════════════════════════════════════════
  //  TUTOR (kept for backward compatibility)
  // ══════════════════════════════════════════════════════════════════
  Future<TutorReply> tutor(String question, StudentProfile p) async {
    if (_canUseGemini) {
      try {
        final text = await _callGemini(
          'You are Kabalikat, a patient study companion for a Grade ${p.grade} '
          'Filipino student. ${p.language.promptHint} Keep it short, use a '
          'simple local example, and end with one quick check-question. '
          'Student asks: "$question"',
        );
        return TutorReply(text);
      } catch (_) {
        // Fall through to offline.
      }
    }

    // Try Ollama for tutor if available.
    try {
      final raw = await _callOllama(
        'You are Kabalikat, a patient AI study companion for Filipino students. '
        '${p.language.promptHint} Keep answers concise.',
        'Student (Grade ${p.grade}) asks: "$question"\n'
        'Give a clear, helpful answer with a simple example. '
        'End with one quick check-question.',
      );
      return TutorReply(raw);
    } catch (_) {}

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
    final tips = p.language == AppLanguage.english
        ? "I'm offline right now, so I can't generate a full answer — but here's a tip: break the problem into smaller steps and try a worked example. Reconnect for a detailed explanation, or open Practice for cached exercises."
        : "Offline muna ako kaya hindi pa ako makagawa ng buong sagot — pero subukan mong hatiin sa maliliit na hakbang ang problema. Kumonekta ulit para sa detalyadong paliwanag, o pumunta sa Practice para sa naka-cache na ehersisyo.";
    return tips;
  }

  // ══════════════════════════════════════════════════════════════════
  //  PRACTICE (kept for backward compatibility)
  // ══════════════════════════════════════════════════════════════════
  Future<PracticeQuestion> nextQuestion({
    required StudentProfile p,
    required int difficulty,
    String topic = 'General',
  }) async {
    if (_canUseGemini) {
      try {
        return await _generateQuestion(p, difficulty, topic);
      } catch (_) {}
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
    final raw = await _callGemini(
      'Create ONE $diffLabel multiple-choice question for a Grade ${p.grade} '
      'Filipino student${topic == 'General' ? '' : ' about $topic'}. '
      'Return ONLY valid JSON with keys: topic, difficulty ($difficulty), '
      'prompt, promptFil, choices (array of 4), answerIndex (0-3), '
      'explanation, explanationFil. promptFil/explanationFil are Filipino.',
      maxTokens: 600,
    );
    final jsonStr = raw.substring(raw.indexOf('{'), raw.lastIndexOf('}') + 1);
    return PracticeQuestion.fromJson(jsonDecode(jsonStr));
  }

  // ══════════════════════════════════════════════════════════════════
  //  RESPONSE PARSING — Uses SecureJsonParser
  // ══════════════════════════════════════════════════════════════════
  StudyContent _parseResponse(String raw, ContentMode mode, {required bool offline}) {
    switch (mode) {
      case ContentMode.reviewer:
        return StudyContent(
          reviewers: SecureJsonParser.parseReviewers(raw),
          generatedOffline: offline,
        );
      case ContentMode.flashcards:
        return StudyContent(
          flashcards: SecureJsonParser.parseFlashcards(raw),
          generatedOffline: offline,
        );
      case ContentMode.quiz:
        return StudyContent(
          quizzes: SecureJsonParser.parseQuizzes(raw),
          generatedOffline: offline,
        );
    }
  }

  bool _hasContent(StudyContent c) =>
      c.reviewers.isNotEmpty || c.flashcards.isNotEmpty || c.quizzes.isNotEmpty;

  // ══════════════════════════════════════════════════════════════════
  //  GEMINI PROMPT BUILDER
  // ══════════════════════════════════════════════════════════════════
  String _buildGeminiPrompt(String text, ContentMode mode) {
    // Gemini is smart enough to follow instructions without few-shot,
    // but we still enforce JSON-only output and Taglish preference.
    final modeInstruction = switch (mode) {
      ContentMode.reviewer =>
        'Generate a reviewer (key concepts summary). Return JSON with key "reviewers", '
        'each item having "concept", "explanation", "example". Generate at least 5 items.',
      ContentMode.flashcards =>
        'Generate flashcards. Return JSON with key "flashcards", '
        'each item having "front" (question) and "back" (answer). Generate at least 10.',
      ContentMode.quiz =>
        'Generate multiple-choice quiz questions. Return JSON with key "quizzes", '
        'each item having "question", "options" (array of 4), "correctIndex" (0-based). '
        'Generate at least 10.',
    };

    return '''You are an expert study content generator for Filipino students.
$modeInstruction
Write all content in Taglish (mix of Filipino and English).
Extract information ONLY from the provided document text.
Return ONLY valid JSON. No markdown, no explanation.

Document Text:
$text''';
  }

  // ══════════════════════════════════════════════════════════════════
  //  GEMINI API CALL
  // ══════════════════════════════════════════════════════════════════
  Future<String> _callGemini(String prompt, {int maxTokens = 4096}) async {
    final res = await http.post(
      Uri.parse(_geminiUrl),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': prompt}
            ]
          }
        ],
        'generationConfig': {
          'maxOutputTokens': maxTokens,
          'temperature': 0.2,
          'responseMimeType': 'application/json',
        },
      }),
    ).timeout(const Duration(seconds: 30));

    if (res.statusCode != 200) {
      throw Exception('Gemini error ${res.statusCode}: ${res.body}');
    }
    final data = jsonDecode(res.body);
    // Gemini response structure: candidates[0].content.parts[0].text
    return (data['candidates'][0]['content']['parts'][0]['text'] as String).trim();
  }

  // ══════════════════════════════════════════════════════════════════
  //  OLLAMA API CALL — Optimized with Dynamic Context + Multi-Fallback
  // ══════════════════════════════════════════════════════════════════
  /// Calls the local Ollama API with:
  ///   • {"format": "json"} to force JSON output.
  ///   • Dynamic context window sizing to minimize KV-cache memory.
  ///   • Optimized sampling params (temp 0.15, top_p 0.85, top_k 35).
  ///   • Multi-host fallback for Android emulator (10.0.2.2) vs device.
  ///   • Multi-model fallback in case preferred model isn't pulled.
  Future<String> _callOllama(String systemPrompt, String userPrompt) async {
    final hosts =
        Platform.isAndroid ? ['10.0.2.2', '127.0.0.1'] : ['localhost'];

    // Dynamic context window: size to actual input, not a fixed 8192.
    final numCtx = _calculateNumCtx(systemPrompt, userPrompt);

    http.Response? res;
    dynamic lastError;

    // Try each host + model combination.
    for (final host in hosts) {
      for (final model in _ollamaModels) {
        try {
          // The kabalikat custom model has params baked in via Modelfile.
          // Other models need explicit configuration.
          final isCustomModel = model == 'kabalikat';

          final candidate = await http.post(
            Uri.parse('http://$host:11434/api/generate'),
            headers: {'content-type': 'application/json'},
            body: jsonEncode({
              'model': model,
              'system': systemPrompt,
              'prompt': userPrompt,
              'stream': false,
              // ── Force JSON mode ──
              'format': 'json',
              'options': {
                // Custom model has sampling params baked in;
                // only inject for fallback models.
                if (!isCustomModel) ...{
                  'temperature': 0.15,    // Enough entropy for Taglish variety
                  'top_p': 0.85,          // Tighter nucleus for bilingual
                  'top_k': 35,            // Eliminates JSON-breaking tokens
                  'repeat_penalty': 1.15, // Prevents duplicate items
                  'repeat_last_n': 256,   // Covers ~3-4 complete JSON objects
                },
                'num_predict': 3072,    // Hard ceiling prevents rambling
                'num_ctx': numCtx,      // Dynamic: saves RAM + speeds inference
              },
            }),
          ).timeout(const Duration(seconds: 90));

          if (candidate.statusCode == 200) {
            res = candidate;
            print('[AiService] Ollama success: $model@$host (ctx=$numCtx)');
            break;
          } else {
            lastError = Exception(
                'Ollama $model@$host: HTTP ${candidate.statusCode}');
          }
        } catch (e) {
          lastError = e;
          // Try next model/host combo.
        }
      }
      if (res != null) break;
    }

    if (res == null) {
      throw lastError ?? Exception('Ollama connection failed on all hosts/models');
    }

    final data = jsonDecode(res.body);
    return (data['response'] as String? ?? '').trim();
  }

  // ══════════════════════════════════════════════════════════════════
  //  CONTEXT WINDOW & TEXT MANAGEMENT
  // ══════════════════════════════════════════════════════════════════

  /// Calculate optimal context window size for the given input.
  /// Rounds up to nearest power of 2 for memory alignment efficiency.
  /// Prevents over-allocating KV-cache on memory-constrained devices.
  int _calculateNumCtx(String systemPrompt, String userPrompt) {
    // Rough tokenization: ~1 token per 3.5 characters for mixed
    // Taglish/English (Filipino tokens are less efficiently tokenized
    // by Llama's BPE vocabulary than English).
    final inputTokens =
        ((systemPrompt.length + userPrompt.length) / 3.5).ceil();

    // Output budget: ~120 tokens per flashcard/quiz item × 12 items
    // + 20% safety margin = ~1730 tokens.
    const outputBudget = 1800;

    final needed = inputTokens + outputBudget;

    // Round up to nearest power of 2 for memory alignment.
    if (needed <= 2048) return 2048;
    if (needed <= 4096) return 4096;
    if (needed <= 8192) return 8192;
    return 8192; // Hard cap — don't go higher on consumer hardware.
  }

  /// Truncate text to fit context window while preserving sentence
  /// boundaries. Prioritizes the beginning (key definitions) and
  /// end (summaries/conclusions) of the document.
  static String _smartTruncate(String text, {int maxChars = 5500}) {
    if (text.length <= maxChars) return text;

    // Split into sentences (rough heuristic).
    final sentences = text.split(RegExp(r'(?<=[.!?])\s+'));
    if (sentences.isEmpty) {
      return text.substring(0, maxChars);
    }

    // Take from the beginning until we hit 70% of budget.
    final headBudget = (maxChars * 0.7).toInt();
    final tailBudget = maxChars - headBudget;

    final headBuffer = StringBuffer();
    for (final s in sentences) {
      if (headBuffer.length + s.length + 1 > headBudget) break;
      headBuffer.write('$s ');
    }

    // Take from the end for the remaining budget.
    final tailBuffer = StringBuffer();
    final reversedSentences = sentences.reversed.toList();
    for (final s in reversedSentences) {
      if (tailBuffer.length + s.length + 1 > tailBudget) break;
      tailBuffer.write('$s ');
    }

    final head = headBuffer.toString().trim();
    final tail = tailBuffer.toString().trim();

    // Avoid duplication if head and tail overlap.
    if (head.contains(tail)) return head;

    return '$head\n\n[...]\n\n$tail';
  }
}
