import 'package:flutter/foundation.dart';

import '../models/student_profile.dart';
import '../models/study_deck.dart';
import '../repositories/hybrid_study_content_repository.dart';
import '../services/storage_service.dart';
import '../services/connectivity_service.dart';
import '../services/ai_service.dart';
import '../services/chat_controller.dart';

/// Central app state. Holds the profile, per-topic mastery, connectivity,
/// and the adaptive-difficulty logic used by the Practice screen.
class AppState extends ChangeNotifier {
  final StorageService storage;
  final ConnectivityManager connectivity = ConnectivityManager();
  late final AiService ai;

  /// Persistent chat service. Lives here so it survives screen navigation.
  late final ChatController chat;

  /// Hybrid repository: routes study-content generation to Gemini (online)
  /// or Ollama (offline / timeout cascade). Use this for all new deck
  /// generation; [ai] is kept for the Tutor and Practice screens.
  late final HybridStudyContentRepository repo;

  StudentProfile profile = StudentProfile();
  Map<String, double> mastery = {}; // topic -> 0..1
  List<StudyDeck> _decks = [];
  List<StudyDeck> get decks => List.unmodifiable(_decks);

  AppState(this.storage) {
    ai = AiService(connectivity, storage);
    chat = ChatController(connectivity, storage);
    repo = HybridStudyContentRepository(connectivity, storage);
  }

  Future<void> load() async {
    profile = storage.loadProfile();
    mastery = storage.loadMastery();
    _decks = storage.loadDecks();
    await connectivity.init();
    await chat.init();
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

  Future<void> updateSettings({AppLanguage? lang, int? grade}) async {
    if (lang != null) profile.language = lang;
    if (grade != null) profile.grade = grade;
    await storage.saveProfile(profile);
    notifyListeners();
  }

  Future<void> setApiKey(String? key) async {
    await storage.setApiKey(key);
    notifyListeners();
  }

  bool get hasApiKey =>
      storage.apiKey != null && storage.apiKey!.isNotEmpty;

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

  /// Difficulty for the mixed-topic Practice flow, driven by overall mastery
  /// so it adapts as the student answers across subjects.
  int adaptiveDifficulty() {
    final m = mastery.isEmpty ? 0.3 : overallMastery;
    if (m < 0.4) return 1;
    if (m < 0.75) return 2;
    return 3;
  }

  /// Update mastery after an answer. Correct nudges up, wrong nudges down.
  Future<void> recordAnswer(String topic, bool correct) async {
    final cur = masteryFor(topic);
    final next = correct
        ? (cur + 0.15).clamp(0.0, 1.0)
        : (cur - 0.1).clamp(0.0, 1.0);
    mastery[topic] = next;
    await storage.saveMastery(mastery);
    notifyListeners();
  }
}
