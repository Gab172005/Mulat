import 'dart:convert';

import '../models/study_content.dart';

/// ─── SECURE JSON PARSER ──────────────────────────────────────────────
/// Multi-layer parser designed to handle the unpredictable output of
/// small local LLMs (Llama 3.2 3B / Gemma 2 2B).
///
/// STRATEGY (in order of attempt):
///   1. Direct parse — try the raw string as-is.
///   2. Strip markdown — remove ```json fences that models love to add.
///   3. Repair truncated — try appending common closing brackets.
///   4. Regex extraction — find individual JSON objects and assemble.
///
/// GUARANTEE: Never throws. Returns empty lists on total failure so the
/// UI always gets a valid StudyContent, even if the model hallucinated.

class SecureJsonParser {
  /// Parse reviewer items from raw LLM output.
  static List<ReviewerItem> parseReviewers(String raw) {
    final map = _safeParse(raw);
    if (map == null) return _extractReviewersByRegex(raw);

    // Try common key variants the model might use.
    final list = (map['reviewers'] ?? map['reviewer'] ?? map['items']) as List?;
    if (list == null || list.isEmpty) return _extractReviewersByRegex(raw);

    return list
        .whereType<Map<String, dynamic>>()
        .map((e) => ReviewerItem.fromJson(e))
        .where((r) => r.concept.isNotEmpty && r.explanation.isNotEmpty)
        .toList();
  }

  /// Parse flashcard items from raw LLM output.
  static List<FlashcardItem> parseFlashcards(String raw) {
    final map = _safeParse(raw);
    if (map == null) return _extractFlashcardsByRegex(raw);

    final list = (map['flashcards'] ?? map['cards'] ?? map['items']) as List?;
    if (list == null || list.isEmpty) return _extractFlashcardsByRegex(raw);

    return list
        .whereType<Map<String, dynamic>>()
        .map((e) => FlashcardItem.fromJson(e))
        .where((f) => f.front.isNotEmpty && f.back.isNotEmpty)
        .toList();
  }

  /// Parse quiz items from raw LLM output.
  static List<QuizItem> parseQuizzes(String raw) {
    final map = _safeParse(raw);
    if (map == null) return _extractQuizzesByRegex(raw);

    final list =
        (map['quizzes'] ?? map['quiz'] ?? map['questions'] ?? map['items'])
            as List?;
    if (list == null || list.isEmpty) return _extractQuizzesByRegex(raw);

    return list
        .whereType<Map<String, dynamic>>()
        .map((e) => QuizItem.fromJson(e))
        .where((q) => q.question.isNotEmpty && q.options.length >= 2)
        .toList();
  }

  // ════════════════════════════════════════════════════════════════════
  //  LAYER 1 & 2: Direct parse + markdown stripping
  // ════════════════════════════════════════════════════════════════════
  static Map<String, dynamic>? _safeParse(String raw) {
    // Layer 1: Try direct parse.
    try {
      final decoded = jsonDecode(raw.trim());
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}

    // Layer 2: Strip markdown fences.
    var cleaned = _stripMarkdown(raw);
    try {
      final decoded = jsonDecode(cleaned);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}

    // Layer 3: Try repairing truncated JSON.
    return _repairAndParse(cleaned);
  }

  /// Remove ```json ... ``` fences and leading/trailing whitespace.
  static String _stripMarkdown(String text) {
    var s = text.trim();
    // Remove opening fence.
    if (s.startsWith('```json')) {
      s = s.substring(7);
    } else if (s.startsWith('```')) {
      s = s.substring(3);
    }
    // Remove closing fence.
    if (s.endsWith('```')) {
      s = s.substring(0, s.length - 3);
    }
    // Some models prefix with explanatory text before the JSON.
    final jsonStart = s.indexOf('{');
    if (jsonStart > 0) {
      s = s.substring(jsonStart);
    }
    return s.trim();
  }

  // ════════════════════════════════════════════════════════════════════
  //  LAYER 3: Repair truncated JSON
  // ════════════════════════════════════════════════════════════════════
  static Map<String, dynamic>? _repairAndParse(String text) {
    // Fix unclosed quotes.
    String fixed = text;
    int openQuotes = 0;
    bool escaped = false;
    for (int i = 0; i < fixed.length; i++) {
      if (fixed[i] == '\\') {
        escaped = !escaped;
      } else if (fixed[i] == '"' && !escaped) {
        openQuotes++;
      } else {
        escaped = false;
      }
    }
    if (openQuotes % 2 != 0) {
      fixed += '"';
    }

    // Try common closing sequences for truncated output.
    // Model might cut off mid-array, mid-object, etc.
    const closings = [
      '',
      '}',
      ']}',
      '}]}',
      '"]}',
      '"}]}',
      '""]}',
      '""}]}',
      ']]}',
    ];

    for (final close in closings) {
      try {
        final candidate = jsonDecode(fixed + close);
        if (candidate is Map<String, dynamic>) return candidate;
      } catch (_) {}
    }
    return null;
  }

  // ════════════════════════════════════════════════════════════════════
  //  LAYER 4: Regex-based object extraction (last resort)
  // ════════════════════════════════════════════════════════════════════

  /// Extracts individual {...} blocks and tries to parse each as a
  /// reviewer item. This works when the model outputs mostly-valid JSON
  /// but the outer wrapper is broken.
  static List<ReviewerItem> _extractReviewersByRegex(String raw) {
    final items = <ReviewerItem>[];
    for (final obj in _extractJsonObjects(raw)) {
      try {
        final map = jsonDecode(obj);
        if (map is Map<String, dynamic> &&
            (map.containsKey('concept') || map.containsKey('title'))) {
          final item = ReviewerItem.fromJson(map);
          if (item.concept.isNotEmpty) items.add(item);
        }
      } catch (_) {}
    }
    return items;
  }

  static List<FlashcardItem> _extractFlashcardsByRegex(String raw) {
    final items = <FlashcardItem>[];
    for (final obj in _extractJsonObjects(raw)) {
      try {
        final map = jsonDecode(obj);
        if (map is Map<String, dynamic> &&
            (map.containsKey('front') || map.containsKey('question'))) {
          final item = FlashcardItem.fromJson(map);
          if (item.front.isNotEmpty) items.add(item);
        }
      } catch (_) {}
    }
    return items;
  }

  static List<QuizItem> _extractQuizzesByRegex(String raw) {
    final items = <QuizItem>[];
    // Quiz objects contain nested arrays, so simple {…} regex won't
    // capture them. Use a bracket-matching approach instead.
    for (final obj in _extractBalancedObjects(raw)) {
      try {
        final map = jsonDecode(obj);
        if (map is Map<String, dynamic> &&
            map.containsKey('question') &&
            map.containsKey('options')) {
          final item = QuizItem.fromJson(map);
          if (item.question.isNotEmpty && item.options.length >= 2) {
            items.add(item);
          }
        }
      } catch (_) {}
    }
    return items;
  }

  /// Simple regex for flat JSON objects (no nested braces).
  static Iterable<String> _extractJsonObjects(String raw) {
    final re = RegExp(r'\{[^{}]*\}');
    return re.allMatches(raw).map((m) => m.group(0)!);
  }

  /// Bracket-balanced extraction for objects that may contain arrays.
  static List<String> _extractBalancedObjects(String raw) {
    final results = <String>[];
    int i = 0;
    while (i < raw.length) {
      if (raw[i] == '{') {
        int depth = 0;
        int start = i;
        bool inString = false;
        bool escaped = false;
        while (i < raw.length) {
          final c = raw[i];
          if (escaped) {
            escaped = false;
          } else if (c == '\\') {
            escaped = true;
          } else if (c == '"') {
            inString = !inString;
          } else if (!inString) {
            if (c == '{') depth++;
            if (c == '}') depth--;
            if (depth == 0) {
              results.add(raw.substring(start, i + 1));
              break;
            }
          }
          i++;
        }
      }
      i++;
    }
    return results;
  }
}
