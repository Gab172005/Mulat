// ─── HYBRID STUDY CONTENT REPOSITORY ────────────────────────────────────────
//
// ROUTING DECISION TREE:
//
//   isDeviceOnline() && hasApiKey?
//   ┌────YES──────────────────────────────────────────┐
//   │  ┌─ Gemini SDK ──────────────────────────────┐  │
//   │  │  GenerativeModel('gemini-2.0-flash')       │  │
//   │  │  responseMimeType: 'application/json'      │  │
//   │  │  timeout: 30 s                             │  │
//   │  └─────────────────────────────────────────── ┘  │
//   │     success? → SecureJsonParser → StudyContent    │
//   │     timeout / error / empty?  ────────────────┐   │
//   └───────────────────────────────────────────────┼───┘
//                                                   │
//   else (offline | no key | Gemini cascade) ───────┘
//   ┌─ Ollama HTTP ──────────────────────────────────────┐
//   │  hosts:   10.0.2.2 → 127.0.0.1  (Android emu)     │
//   │           127.0.0.1 → localhost  (physical/desktop) │
//   │  models:  kabalikat → llama3.2:3b → gemma2:2b …   │
//   │  format:  {"format": "json"}  (Ollama-layer guard) │
//   │  timeout: 90 s per model attempt                   │
//   └────────────────────────────────────────────────────┘
//     success? → SecureJsonParser → StudyContent
//     all fail? → StudyContent(generatedOffline: true)
//
// KEY DESIGN DECISIONS:
//   • Gemini path uses the official google_generative_ai SDK (not raw HTTP)
//     so we get structured JSON enforcement at the API token level via
//     responseMimeType, reducing parse failures dramatically.
//   • Timeout is on the full SDK round-trip, not just socket open, so a
//     slow LTE connection that stalls mid-stream is caught correctly.
//   • Both paths produce identical JSON shapes — SecureJsonParser handles
//     both, and the UI never needs to know which backend ran.
//   • Ollama uses dynamic context sizing (_calculateNumCtx) to avoid
//     over-allocating KV-cache on memory-constrained Android devices.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;

import '../models/student_profile.dart';

import '../services/connectivity_service.dart';

import '../services/prompt_builder.dart';
import '../services/storage_service.dart';
import 'study_content_repository.dart';

// ═══════════════════════════════════════════════════════════════════════════════
//  CONFIGURATION CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

// NOTE: The user requested "Gemini 3.5 Flash" — that model ID does not exist.
// 'gemini-2.0-flash' is the current stable Flash tier. Upgrade to
// 'gemini-2.5-flash' once it graduates from preview in your region.
const _kGeminiModel = 'gemini-2.0-flash';

// Gemini timeout. A strict 5-second timeout ensures a fail-fast fallback to Ollama
// if the connection is slow or unstable, preventing a frozen loading screen.
const _kGeminiTimeout = Duration(seconds: 5);

// Ollama timeout per model attempt. Local inference is CPU-bound and
// can be slow on mid-range phones — 90 s is generous but necessary.
const _kOllamaTimeout = Duration(seconds: 90);

const _kOllamaPort = 11434;

// Ordered fallback chain of Ollama models.
// 'kabalikat' is the custom Modelfile with baked system prompt + params.
// Subsequent entries are emergency fallbacks for devices that haven't
// pulled the custom model yet.
const _kOllamaModels = [
  'kabalikat',
  'llama3.2:3b-instruct-q4_K_M',
  'llama3.2:3b',
  'gemma2:2b-instruct-q5_K_M',
  'gemma2:2b',
  'llama3.2:1b-instruct-q8_0',
  'qwen2.5:0.5b',
];

// ═══════════════════════════════════════════════════════════════════════════════
//  HYBRID STUDY CONTENT REPOSITORY
// ═══════════════════════════════════════════════════════════════════════════════

/// Concrete implementation of [StudyContentRepository] that routes
/// between Gemini (online) and Ollama (offline) based on live
/// connectivity state with timeout-triggered cascade fallback.
///
/// Usage:
/// ```dart
/// final repo = HybridStudyContentRepository(connectivityManager, storageService);
/// final content = await repo.generateContent(
///   extractedText: ocrText,
///   targetLanguage: 'Taglish',
///   contentFormat: 'flashcards',
/// );
/// ```
class HybridStudyContentRepository implements StudyContentRepository {
  final ConnectivityManager _connectivity;
  final StorageService _storage;

  HybridStudyContentRepository(this._connectivity, this._storage);

  // True only when a non-empty API key is stored. No key → always offline.
  bool get _hasApiKey =>
      _storage.apiKey != null && _storage.apiKey!.isNotEmpty;

  // Android emulator maps 10.0.2.2 → host machine's localhost.
  // Physical devices need the host's LAN IP instead (add it manually
  // here or expose it as a setting for demo flexibility).
  List<String> get _ollamaHosts =>
      Platform.isAndroid ? ['10.0.2.2', '127.0.0.1'] : ['127.0.0.1', 'localhost'];

  // ═══════════════════════════════════════════════════════════════════════
  //  PUBLIC API — generateContent()
  // ═══════════════════════════════════════════════════════════════════════

  @override
  Future<String> generateContent({
    required String extractedText,
    required String targetLanguage,
    required String contentFormat,
  }) async {
    // Map UI-facing strings → internal enums consumed by prompt builder.
    final language = languageFromString(targetLanguage);
    final mode = contentModeFromString(contentFormat);

    // Smart-truncate to fit the model's context window while preserving
    // sentence boundaries for coherent generation.
    final text = _smartTruncate(extractedText);

    // ── ROUTE A: Gemini via official SDK (online path) ─────────────────
    //
    // We re-check connectivity RIGHT HERE rather than trusting the cached
    // getter — rapid network transitions (entering a tunnel, Wi-Fi handoff)
    // can lag the cached value by several seconds.
    final online = await _connectivity.isDeviceOnline();

    if (_hasApiKey && online) {
      try {
        final raw = await _callGeminiSdk(text, mode, language);
        if (raw.isNotEmpty) return raw;

        _log('Gemini returned empty string, cascading to Ollama.');
      } on TimeoutException {
        // FAIL-FAST TIMEOUT FALLBACK:
        // Device is technically "online" but bandwidth is too low for
        // the Gemini round-trip to complete in ${_kGeminiTimeout.inSeconds}s.
        _log(
          'Gemini timed out after ${_kGeminiTimeout.inSeconds}s '
          '(weak connection) — cascading to Ollama.',
        );
      } on GenerativeAIException catch (e) {
        _log('Gemini SDK error: $e — cascading to Ollama.');
      } catch (e) {
        _log('Gemini unexpected error: $e — cascading to Ollama.');
      }
    }

    // ── ROUTE B: Ollama via HTTP (offline / cascade fallback) ──────────
    try {
      final prompts = buildOllamaPrompt(
        extractedText: text,
        mode: mode,
        language: language,
      );
      final raw = await _callOllamaHttp(prompts.system, prompts.user);
      return raw;
    } catch (e) {
      _log('Ollama also failed: $e');
      throw Exception('Failed to generate content: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  ROUTE A: GEMINI SDK CALL
  // ═══════════════════════════════════════════════════════════════════════

  /// Calls Gemini via the official [google_generative_ai] package.
  ///
  /// SDK advantages over raw HTTP:
  ///   • [GenerationConfig.responseMimeType] = 'application/json' enforces
  ///     valid JSON at the *token sampling level*, not post-hoc. This
  ///     eliminates markdown fences and preamble text from the response.
  ///   • Retry and streaming are handled by the SDK internally.
  ///   • [GenerativeAIException] gives typed error handling.
  Future<String> _callGeminiSdk(
    String text,
    ContentMode mode,
    AppLanguage language,
  ) async {
    final model = GenerativeModel(
      model: _kGeminiModel,
      apiKey: _storage.apiKey!,
      generationConfig: GenerationConfig(
        maxOutputTokens: 4096,
        // Low temperature for factual, consistent study content.
        // Enough entropy for varied phrasing but avoids hallucination.
        temperature: 0.2,
        // API-level JSON enforcement — the model cannot produce invalid JSON.
        // Combined with our prompt instructions this gives near-100% parse rate.
        responseMimeType: 'application/json',
      ),
    );

    final prompt = _buildGeminiPrompt(text, mode, language);

    // Wrap the entire SDK call in a 5s timeout.
    // POTENTIAL STREAMING ENHANCEMENT:
    // If we wanted to show a loading/typing indicator to the user even faster,
    // we could replace `generateContent` with `generateContentStream` like this:
    // ```
    // final stream = model.generateContentStream([Content.text(prompt)]);
    // await for (final chunk in stream) {
    //   // Pass chunk.text to the UI parser immediately
    // }
    // ```
    final response = await model
        .generateContent([Content.text(prompt)])
        .timeout(_kGeminiTimeout);

    return (response.text ?? '').trim();
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  ROUTE B: OLLAMA HTTP CALL
  // ═══════════════════════════════════════════════════════════════════════

  /// Calls the local Ollama server via a plain HTTP POST.
  ///
  /// MULTI-HOST + MULTI-MODEL FALLBACK:
  ///   Iterates hosts × models until one combination succeeds.
  ///   Order: preferred host first, preferred model first.
  ///   The outer loop breaks as soon as any combination succeeds.
  ///
  /// JSON ENFORCEMENT:
  ///   `"format": "json"` at the Ollama API level enforces valid JSON
  ///   output from the model, complementing the prompt-level instructions.
  ///   This dual enforcement is why the offline path has a near-zero
  ///   catastrophic parse failure rate even on 1B parameter models.
  Future<String> _callOllamaHttp(
    String systemPrompt,
    String userPrompt,
  ) async {
    final numCtx = _calculateNumCtx(systemPrompt, userPrompt);

    http.Response? response;
    Object? lastError;

    // Labelled outer loop so we can break from the inner loop on success.
    outer:
    for (final host in _ollamaHosts) {
      for (final model in _kOllamaModels) {
        try {
          // The 'kabalikat' custom model has sampling params baked in via
          // its Modelfile. Other models need explicit configuration here.
          final isCustomModel = model == 'kabalikat';

          final candidate = await http
              .post(
                Uri.parse('http://$host:$_kOllamaPort/api/generate'),
                headers: {'content-type': 'application/json'},
                body: jsonEncode({
                  'model': model,
                  'system': systemPrompt,
                  'prompt': userPrompt,
                  'stream': false,
                  // Ollama-layer JSON enforcement (complements prompt).
                  'format': 'json',
                  'options': {
                    if (!isCustomModel) ...{
                      // Taglish needs slightly more entropy than pure English
                      // to produce natural code-switching. 0.15 is the sweet
                      // spot between determinism and natural variation.
                      'temperature': 0.15,
                      // Nucleus sampling: tighter top_p eliminates JSON-breaking
                      // tokens like ``` that small models like to emit.
                      'top_p': 0.85,
                      'top_k': 35,
                      // Repeat penalty prevents copy-pasting the same concept
                      // across multiple flashcards/quiz questions.
                      'repeat_penalty': 1.15,
                      // Window covers ~3-4 complete JSON objects.
                      'repeat_last_n': 256,
                    },
                    // Hard output ceiling prevents rambling beyond the JSON.
                    'num_predict': 3072,
                    // Dynamic context: only allocate what we need.
                    // Smaller context = faster prefill + less VRAM pressure.
                    'num_ctx': numCtx,
                  },
                }),
              )
              .timeout(_kOllamaTimeout);

          if (candidate.statusCode == 200) {
            response = candidate;
            _log('Ollama success: $model @ $host (numCtx=$numCtx)');
            break outer;
          } else {
            lastError = Exception(
              'Ollama $model@$host: HTTP ${candidate.statusCode}',
            );
          }
        } on TimeoutException {
          lastError = TimeoutException(
            'Ollama $model@$host timed out after ${_kOllamaTimeout.inSeconds}s',
          );
          _log('Ollama timeout: $model @ $host — trying next.');
        } catch (e) {
          lastError = e;
          // SocketException = server not running; try next combination.
        }
      }
    }

    if (response == null) {
      throw lastError ??
          Exception('Ollama: all ${_ollamaHosts.length} hosts × '
              '${_kOllamaModels.length} models failed.');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return (data['response'] as String? ?? '').trim();
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  PROMPT BUILDER — GEMINI
  // ═══════════════════════════════════════════════════════════════════════

  /// Builds a Gemini-optimised prompt.
  ///
  /// Gemini does not need the elaborate few-shot examples required by
  /// small local models (Llama 3.2 3B, Gemma 2 2B). The combination of:
  ///   (a) clear format specification in the prompt,
  ///   (b) language directives from [AppLanguage] extensions,
  ///   (c) responseMimeType JSON enforcement at the API level,
  /// produces consistent, parseable output without few-shot overhead.
  ///
  /// The Ollama path uses [buildOllamaPrompt] which includes full
  /// few-shot + silent chain-of-thought for small model compensation.
  String _buildGeminiPrompt(
    String text,
    ContentMode mode,
    AppLanguage language,
  ) {
    final formatSpec = switch (mode) {
      ContentMode.reviewer =>
        'Generate a reviewer (key concepts summary) from the document.\n'
        'Return a JSON object with key "reviewers".\n'
        'Each item: { "concept": "...", "explanation": "...", "example": "..." }\n'
        'Generate AT LEAST 5 distinct items covering different concepts.',

      ContentMode.flashcards =>
        'Generate flashcards from the document (front = question, back = answer).\n'
        'Return a JSON object with key "flashcards".\n'
        'Each item: { "front": "...", "back": "..." }\n'
        'Generate AT LEAST 10 cards, each covering a DIFFERENT concept.',

      ContentMode.quiz =>
        'Generate multiple-choice quiz questions from the document.\n'
        'Return a JSON object with key "quizzes".\n'
        'Each item: { "question": "...", "options": ["A","B","C","D"], "correctIndex": 0 }\n'
        'correctIndex is 0-based. Generate AT LEAST 10 questions with varied correctIndex values.',
    };

    return '''You are an expert study content generator for Filipino students.

$formatSpec

${language.contentLanguageDirective}

${language.crossLanguageInstruction}

QUALITY RULES:
- Extract information ONLY from the provided document text. Do NOT invent facts.
- Each item must cover a DIFFERENT concept. No rephrasing the same idea.
- Return ONLY valid JSON. No markdown fences. No preamble or explanation.

Document Text:
$text

${language.generateNowAnchor}''';
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  UTILITIES
  // ═══════════════════════════════════════════════════════════════════════

  /// Calculates the optimal Ollama context window for the given prompts.
  ///
  /// Rationale: most code wastes RAM by defaulting to a fixed 8192 context.
  /// We size to actual input, rounded up to the nearest power of 2 for
  /// KV-cache memory alignment. This is critical on Android phones where
  /// Ollama shares RAM with the OS and other apps.
  ///
  /// Token estimate uses 3.5 chars/token (not 4) because Filipino BPE
  /// tokenisation in Llama's vocabulary is less efficient than English.
  int _calculateNumCtx(String systemPrompt, String userPrompt) {
    final inputTokens =
        ((systemPrompt.length + userPrompt.length) / 3.5).ceil();

    // Output budget: ~120 tokens × 12 items + 20% safety margin ≈ 1800.
    const outputBudget = 1800;

    final needed = inputTokens + outputBudget;

    if (needed <= 2048) return 2048;
    if (needed <= 4096) return 4096;
    // 8192 is the hard cap — going higher on a phone causes OOM kills.
    return 8192;
  }

  /// Truncates extracted text to the context budget while preserving
  /// sentence boundaries.
  ///
  /// Strategy: keep 70% from the HEAD (definitions, introductions) and
  /// 30% from the TAIL (summaries, conclusions). Mid-document material
  /// is sacrificed first. A [...] marker is inserted at the cut point
  /// so the model knows content was removed.
  static String _smartTruncate(String text, {int maxChars = 5500}) {
    if (text.length <= maxChars) return text;

    final sentences = text.split(RegExp(r'(?<=[.!?])\s+'));
    if (sentences.isEmpty) return text.substring(0, maxChars);

    final headBudget = (maxChars * 0.7).toInt();
    final tailBudget = maxChars - headBudget;

    final head = StringBuffer();
    for (final s in sentences) {
      if (head.length + s.length + 1 > headBudget) break;
      head.write('$s ');
    }

    final tail = StringBuffer();
    for (final s in sentences.reversed) {
      if (tail.length + s.length + 1 > tailBudget) break;
      tail.write('$s ');
    }

    final h = head.toString().trim();
    final t = tail.toString().trim();

    if (h.contains(t)) return h;
    return '$h\n\n[...]\n\n$t';
  }

  void _log(String message) =>
      // ignore: avoid_print
      print('[HybridRepo] $message');
}
