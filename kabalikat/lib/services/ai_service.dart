import 'dart:convert';
import 'dart:io' show Platform;
import 'package:http/http.dart' as http;

import '../models/student_profile.dart';
import '../models/chat_message.dart';
import '../data/offline_content.dart';
import '../services/connectivity_service.dart';
import '../services/storage_service.dart';

/// Result of a tutor turn: the text plus whether it came from cache.
class TutorReply {
  final String text;
  final bool offline;
  TutorReply(this.text, {this.offline = false});
}

/// ─── CONVERSATIONAL TUTOR SERVICE ────────────────────────────────────
/// The chat "study buddy" brain. Routes a multi-turn conversation through
/// the same graceful-degradation ladder as the rest of the app:
///
///   online + API key → Gemini  (cloud)
///   else             → Ollama  (on-device, offline)
///   both fail        → bundled offline lesson snippets
///
/// MEMORY: every call receives the recent conversation [history] plus a
/// [memoryNote] summarising the learner's profile and weak topics, so the
/// tutor stays consistent and personal instead of treating each question
/// as a cold start. (Document → flashcard/quiz generation lives in
/// HybridStudyContentRepository; this service is chat-only.)
class AiService {
  final ConnectivityManager connectivity;
  final StorageService storage;

  AiService(this.connectivity, this.storage);

  // ── Gemini (cloud) ──────────────────────────────────────────────────
  static const _geminiModel = 'gemini-2.0-flash-lite';
  String get _geminiUrl =>
      'https://generativelanguage.googleapis.com/v1beta/models/$_geminiModel:generateContent?key=${storage.apiKey ?? ''}';

  // ── Ollama (on-device) ──────────────────────────────────────────────
  // CHAT models only. We deliberately skip the custom `kabalikat` model
  // here: it is tuned for strict JSON study-content generation (low temp,
  // JSON stop-sequences) and makes a poor conversational tutor.
  static const _ollamaChatModels = [
    'llama3.2:3b',
    'gemma2:2b',
    'llama3.2:1b',
    'qwen2.5:0.5b',
  ];

  // How many past turns we feed the model — keeps prompts small and fast
  // on low-end phones while preserving short-term memory.
  static const _historyWindow = 8;

  bool get _canUseGemini =>
      connectivity.isOnline &&
      (storage.apiKey != null && storage.apiKey!.isNotEmpty);

  /// Ask the tutor a question with full conversational + profile memory.
  Future<TutorReply> tutor(
    String question,
    StudentProfile p, {
    List<ChatMessage> history = const [],
    String memoryNote = '',
  }) async {
    final recent = history.length > _historyWindow
        ? history.sublist(history.length - _historyWindow)
        : history;
    final system = _persona(p, memoryNote);

    if (_canUseGemini) {
      try {
        return TutorReply(await _callGeminiChat(system, recent, question));
      } catch (_) {
        // Fall through to on-device.
      }
    }

    try {
      return TutorReply(await _callOllamaChat(system, recent, question));
    } catch (_) {
      // Fall through to bundled content.
    }

    return TutorReply(_offlineTutor(question, p), offline: true);
  }

  // ── System persona (carries the profile memory) ─────────────────────
  String _persona(StudentProfile p, String memoryNote) {
    final name = p.name.trim().isEmpty ? 'the student' : p.name.trim();
    final buf = StringBuffer()
      ..write('You are Kabalikat, a warm and patient AI study companion for '
          'Filipino students. You are tutoring $name, who is in Grade '
          '${p.grade}. ')
      ..write('${p.language.promptHint} ')
      ..write('Keep answers short and clear, use a simple real-life Filipino '
          'example, and end with ONE quick check-question. ');
    if (memoryNote.trim().isNotEmpty) {
      buf.write('Here is what you remember about this learner: '
          '${memoryNote.trim()} Use it to tailor difficulty and examples. ');
    }
    buf.write('Refer back to earlier messages so the conversation feels '
        'continuous. Never invent facts; if unsure, say so simply.');
    return buf.toString();
  }

  // ── Gemini multi-turn chat ──────────────────────────────────────────
  Future<String> _callGeminiChat(
    String system,
    List<ChatMessage> history,
    String question,
  ) async {
    final contents = <Map<String, dynamic>>[];
    for (final m in history) {
      contents.add({
        'role': m.fromUser ? 'user' : 'model',
        'parts': [
          {'text': m.text}
        ],
      });
    }
    contents.add({
      'role': 'user',
      'parts': [
        {'text': question}
      ],
    });

    final res = await http
        .post(
          Uri.parse(_geminiUrl),
          headers: {'content-type': 'application/json'},
          body: jsonEncode({
            'system_instruction': {
              'parts': [
                {'text': system}
              ]
            },
            'contents': contents,
            'generationConfig': {
              'maxOutputTokens': 800,
              'temperature': 0.4,
            },
          }),
        )
        .timeout(const Duration(seconds: 30));

    if (res.statusCode != 200) {
      throw Exception('Gemini error ${res.statusCode}: ${res.body}');
    }
    final data = jsonDecode(res.body);
    return (data['candidates'][0]['content']['parts'][0]['text'] as String)
        .trim();
  }

  // ── Ollama multi-turn chat (offline) ────────────────────────────────
  Future<String> _callOllamaChat(
    String system,
    List<ChatMessage> history,
    String question,
  ) async {
    final hosts = Platform.isAndroid
        ? ['10.0.2.2', '127.0.0.1']
        : ['localhost', '127.0.0.1'];

    final messages = <Map<String, String>>[
      {'role': 'system', 'content': system},
    ];
    for (final m in history) {
      messages.add({
        'role': m.fromUser ? 'user' : 'assistant',
        'content': m.text,
      });
    }
    messages.add({'role': 'user', 'content': question});

    Object? lastError;
    for (final host in hosts) {
      for (final model in _ollamaChatModels) {
        try {
          final res = await http
              .post(
                Uri.parse('http://$host:11434/api/chat'),
                headers: {'content-type': 'application/json'},
                body: jsonEncode({
                  'model': model,
                  'messages': messages,
                  'stream': false,
                  'options': {
                    'temperature': 0.4,
                    'num_predict': 600,
                    'num_ctx': 4096,
                  },
                }),
              )
              .timeout(const Duration(seconds: 90));

          if (res.statusCode == 200) {
            final data = jsonDecode(res.body);
            final text =
                (data['message']?['content'] as String? ?? '').trim();
            if (text.isNotEmpty) return text;
          }
          lastError = Exception('Ollama $model@$host: HTTP ${res.statusCode}');
        } catch (e) {
          lastError = e;
        }
      }
    }
    throw lastError ?? Exception('Ollama chat failed on all hosts/models');
  }

  // ── Bundled offline fallback (zero connectivity) ────────────────────
  String _offlineTutor(String question, StudentProfile p) {
    final q = question.toLowerCase();
    for (final entry in kOfflineLessons.entries) {
      if (q.contains(entry.key)) {
        return p.language == AppLanguage.filipino
            ? entry.value['fil']!
            : p.language == AppLanguage.taglish
                ? '${entry.value['fil']}\n\n(In English: ${entry.value['en']})'
                : entry.value['en']!;
      }
    }
    return p.language == AppLanguage.english
        ? "I'm offline right now, so I can't generate a full answer — but here's a tip: break the problem into smaller steps and try a worked example. Reconnect for a detailed explanation, or open Practice for cached exercises."
        : "Offline muna ako kaya hindi pa ako makagawa ng buong sagot — pero subukan mong hatiin sa maliliit na hakbang ang problema. Kumonekta ulit para sa detalyadong paliwanag, o pumunta sa Practice para sa naka-cache na ehersisyo.";
  }
}
