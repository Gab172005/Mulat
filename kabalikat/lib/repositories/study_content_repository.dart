// ─── STUDY CONTENT REPOSITORY CONTRACT ──────────────────────────────────────
// Defines the abstract interface that every AI backend must satisfy.
//
// DESIGN INTENT:
//   • Callers (screens, state providers) never know which backend ran.
//   • Switching from Gemini → Claude → local GPT is a one-class swap.
//   • String-typed params (targetLanguage, contentFormat) decouple the
//     UI layer from internal enums — screens deal in user-visible strings.
//
// DEPENDENCY GRAPH:
//   HybridStudyContentRepository (concrete)
//     implements StudyContentRepository (this file)
//     depends on ConnectivityManager, StorageService
//     uses AppLanguage, ContentMode (internal enums)
//     delegates parsing to SecureJsonParser
// ─────────────────────────────────────────────────────────────────────────────

import '../models/student_profile.dart';
import '../models/study_content.dart';
import '../services/prompt_builder.dart';

// ═══════════════════════════════════════════════════════════════════════════════
//  TYPE MAPPERS
//  Convert UI-facing strings → internal enums used by prompt builder & parser.
//  Centralised here so every repository implementation gets the same mapping.
// ═══════════════════════════════════════════════════════════════════════════════

/// Maps user-facing language strings to [AppLanguage].
///
/// Recognised values (case-insensitive):
///   'Pure English' | 'English'   → [AppLanguage.english]
///   'Pure Filipino' | 'Filipino' → [AppLanguage.filipino]
///   'Taglish' | anything else    → [AppLanguage.taglish]  (safe default)
AppLanguage languageFromString(String targetLanguage) {
  return switch (targetLanguage.toLowerCase().trim()) {
    'pure english' || 'english' => AppLanguage.english,
    'pure filipino' || 'filipino' => AppLanguage.filipino,
    _ => AppLanguage.taglish,
  };
}

/// Maps content format strings to [ContentMode].
///
/// Recognised values (case-insensitive):
///   'reviewer' | 'review'          → [ContentMode.reviewer]
///   'quiz' | 'quizzes' | 'microquiz' → [ContentMode.quiz]
///   'flashcards' | anything else   → [ContentMode.flashcards]  (safe default)
ContentMode contentModeFromString(String contentFormat) {
  return switch (contentFormat.toLowerCase().trim()) {
    'reviewer' || 'review' => ContentMode.reviewer,
    'quiz' || 'quizzes' || 'microquiz' => ContentMode.quiz,
    _ => ContentMode.flashcards,
  };
}

// ═══════════════════════════════════════════════════════════════════════════════
//  ABSTRACT REPOSITORY
// ═══════════════════════════════════════════════════════════════════════════════

/// Contract for all AI study-content backends.
///
/// Implementations are free to route to any inference backend (Gemini,
/// Ollama, OpenAI, etc.) as long as they return a valid [StudyContent].
/// Callers always receive a non-null result — errors are swallowed
/// internally and surfaced as [StudyContent.generatedOffline] = true.
abstract class StudyContentRepository {
  /// Generates structured study material from raw document text.
  ///
  /// Parameters:
  ///   [extractedText]  — OCR / PDF-extracted plain text from the document.
  ///   [targetLanguage] — Output language: 'Pure English', 'Pure Filipino',
  ///                      or 'Taglish'.
  ///   [contentFormat]  — Output type: 'reviewer', 'flashcards', or 'quiz'.
  ///
  /// Returns a JSON formatted [String] with the requested content.
  Future<String> generateContent({
    required String extractedText,
    required String targetLanguage,
    required String contentFormat,
  });
}
