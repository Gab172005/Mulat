import 'package:flutter/foundation.dart';

import '../models/student_profile.dart';
import '../models/study_deck.dart';
import '../models/chat_message.dart';
import '../models/review_state.dart';
import '../repositories/hybrid_study_content_repository.dart';
import '../services/storage_service.dart';
import '../services/connectivity_service.dart';
import '../services/spaced_repetition.dart';
import '../services/ai_service.dart';

/// Central app state. Holds the profile, per-topic mastery, connectivity,
/// the conversational tutor memory, and the spaced-repetition schedule that
/// drives adaptive review.
class AppState extends ChangeNotifier {
  final StorageService storage;
  final ConnectivityManager connectivity = ConnectivityManager();
  late final AiService ai;

  /// Hybrid repository: routes study-content generation to Gemini (online)
  /// or Ollama (offline / timeout cascade). Used for deck generation;
  /// [ai] handles the conversational Tutor.
  late final HybridStudyContentRepository repo;

  StudentProfile profile = StudentProfile();
  Map<String, double> mastery = {}; // deck/topic -> 0..1
  Map<String, ReviewState> reviews = {}; // deck title -> spaced-rep state
  List<StudyDeck> _decks = [];
  List<StudyDeck> get decks => List.unmodifiable(_decks);

  // ---- Tutor conversation memory ----
  List<ChatMessage> chat = [];
  bool tutorThinking = false;

  AppState(this.storage) {
    ai = AiService(connectivity, storage);
    repo = HybridStudyContentRepository(connectivity, storage);
  }

  Future<void> load() async {
    profile = storage.loadProfile();
    mastery = storage.loadMastery();
    reviews = storage.loadReviews();
    _decks = storage.loadDecks();
    chat = storage.loadChat();
    await connectivity.init();
    connectivity.onChange.listen((_) => notifyListeners());
    notifyListeners();
  }

  // ---- Decks ----
  Future<void> addDeck(StudyDeck deck) async {
    await storage.saveDeck(deck);
    _decks = storage.loadDecks();
    notifyListeners();
  }

  Future<void> removeDeck(String id) async {
    await storage.deleteDeck(id);
    _decks = storage.loadDecks();
    notifyListeners();
  }

  bool get isOnline => connectivity.isOnline;

  void toggleDemoOffline(bool offline) {
    connectivity.forceOffline(offline);
    notifyListeners();
  }

  // ---- Profile ----
  Future<void> completeOnboarding(
      String name, int grade, AppLanguage lang) async {
    profile
      ..onboarded = true
      ..name = name
      ..grade = grade
      ..language = lang;
    await storage.saveProfile(profile);
    notifyListeners();
  }

  Future<void> updateSettings(
      {AppLanguage? lang, int? grade, String? name}) async {
    if (lang != null) profile.language = lang;
    if (grade != null) profile.grade = grade;
    if (name != null && name.trim().isNotEmpty) profile.name = name.trim();
    await storage.saveProfile(profile);
    notifyListeners();
  }

  Future<void> setApiKey(String? key) async {
    await storage.setApiKey(key);
    notifyListeners();
  }

  bool get hasApiKey => storage.apiKey != null && storage.apiKey!.isNotEmpty;

  // ---- Tutor ----
  /// Send a question to the tutor. Adds the turn to memory, persists it,
  /// and feeds the prior conversation + a profile summary back to the model.
  Future<void> askTutor(String question) async {
    final q = question.trim();
    if (q.isEmpty || tutorThinking) return;

    final history = List<ChatMessage>.from(chat);
    chat.add(ChatMessage(text: q, fromUser: true));
    tutorThinking = true;
    notifyListeners();
    await storage.saveChat(chat);

    final reply = await ai.tutor(
      q,
      profile,
      history: history,
      memoryNote: _memoryNote(),
    );

    chat.add(ChatMessage(
        text: reply.text, fromUser: false, offline: reply.offline));
    tutorThinking = false;
    notifyListeners();
    await storage.saveChat(chat);
  }

  Future<void> clearChat() async {
    chat = [];
    await storage.clearChat();
    notifyListeners();
  }

  /// A short natural-language summary of the learner's progress, handed to
  /// the tutor so it can personalise difficulty and examples.
  String _memoryNote() {
    if (mastery.isEmpty) return '';
    final parts =
        mastery.entries.map((e) => '${e.key} (${(e.value * 100).round()}%)');
    final weak = mastery.entries
        .where((e) => e.value < 0.5)
        .map((e) => e.key)
        .toList();
    final buf = StringBuffer('Decks practiced so far: ${parts.join(', ')}.');
    if (weak.isNotEmpty) {
      buf.write(' Still weak on: ${weak.join(', ')} — explain those extra '
          'simply and patiently.');
    }
    return buf.toString();
  }

  // ---- Mastery / adaptivity ----
  double masteryFor(String topic) => mastery[topic] ?? 0.3;

  double get overallMastery {
    if (mastery.isEmpty) return 0;
    return mastery.values.reduce((a, b) => a + b) / mastery.length;
  }

  /// Map mastery (0..1) to difficulty 1..3.
  int difficultyFor(String topic) {
    final m = masteryFor(topic);
    if (m < 0.4) return 1;
    if (m < 0.75) return 2;
    return 3;
  }

  /// Difficulty for the mixed-topic flow, driven by overall mastery.
  int adaptiveDifficulty() {
    final m = mastery.isEmpty ? 0.3 : overallMastery;
    if (m < 0.4) return 1;
    if (m < 0.75) return 2;
    return 3;
  }

  /// Update mastery after a single answer (live feedback during a quiz).
  Future<void> recordAnswer(String topic, bool correct) async {
    final cur = masteryFor(topic);
    final next = correct
        ? (cur + 0.15).clamp(0.0, 1.0)
        : (cur - 0.1).clamp(0.0, 1.0);
    mastery[topic] = next;
    await storage.saveMastery(mastery);
    notifyListeners();
  }

  // ---- Spaced repetition (adaptive review schedule) ----
  ReviewState? reviewFor(String deckTitle) => reviews[deckTitle];

  bool isDue(String deckTitle) => reviews[deckTitle]?.isDue ?? false;

  /// Decks the schedule says are due for review right now.
  List<String> get dueDeckTitles =>
      reviews.entries.where((e) => e.value.isDue).map((e) => e.key).toList();

  /// Call once when a quiz SESSION finishes. Records the score, updates
  /// mastery, and schedules the next review using the forgetting curve.
  Future<void> recordReviewSession(String deckTitle, int scorePct) async {
    final state =
        reviews[deckTitle] ?? ReviewState(mastery: masteryFor(deckTitle));
    SpacedRepetition.recordSession(state, scorePct);
    reviews[deckTitle] = state;
    mastery[deckTitle] = state.mastery; // keep the simple map in sync
    await storage.saveReviews(reviews);
    await storage.saveMastery(mastery);
    notifyListeners();
  }

  /// Demo helper: wipe practice history, schedule, and chat.
  Future<void> resetProgress() async {
    mastery = {};
    reviews = {};
    chat = [];
    await storage.clearProgress();
    notifyListeners();
  }
}
