import 'package:flutter/foundation.dart';

import '../data/offline_content.dart';
import '../models/student_profile.dart';
import '../services/ai_service.dart';
import '../services/connectivity_service.dart';
import '../services/gemma_local_model_service.dart';
import '../services/local_model_service.dart';
import '../services/storage_service.dart';

/// Central app state. Holds the profile, per-topic mastery, connectivity,
/// and the adaptive-difficulty logic used by the Practice screen.
class AppState extends ChangeNotifier {
  final StorageService storage;
  final ConnectivityService connectivity = ConnectivityService();

  // Tier-2 on-device model. Swap StubLocalModelService for the real
  // flutter_gemma implementation to enable a true offline AI tutor
  // (see ON_DEVICE_MODEL.md).
  final LocalModelService localModel = GemmaLocalModelService();

  late final AiService ai;

  StudentProfile profile = StudentProfile();
  Map<String, double> mastery = {}; // topic -> 0..1

  // Spaced-repetition cooldown: most-recently-asked prompts (newest first).
  // A question can't reappear until it falls out of the cooldown window.
  List<String> _recentAsked = [];
  static const int _cooldownWindow = 6; // questions to wait before a repeat
  static const int _recentMax = 40; // history cap kept on disk

  AppState(this.storage) {
    ai = AiService(connectivity, storage, localModel);
  }

  Future<void> load() async {
    profile = storage.loadProfile();
    mastery = storage.loadMastery();
    _recentAsked = storage.loadRecentAsked();
    await connectivity.init();
    connectivity.onChange.listen((_) => notifyListeners());
    localModel.addListener(notifyListeners);
    notifyListeners();
  }

  /// Prompts currently "on cooldown" — Practice should skip these.
  Set<String> get cooldownExclude =>
      _recentAsked.take(_cooldownWindow).toSet();

  /// Record that a question was just shown (moves it to the front of history).
  Future<void> markAsked(String prompt) async {
    _recentAsked.remove(prompt);
    _recentAsked.insert(0, prompt);
    if (_recentAsked.length > _recentMax) {
      _recentAsked = _recentAsked.sublist(0, _recentMax);
    }
    await storage.saveRecentAsked(_recentAsked);
  }

  bool get isOnline => connectivity.isOnline;

  /// True when UI text should render in Filipino (Filipino or Taglish picked).
  bool get isFilipino =>
      profile.language == AppLanguage.filipino ||
      profile.language == AppLanguage.taglish;

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
    // Changing grade means new-level content — reset progress so mastery
    // reflects the new grade, not the old one.
    if (grade != null && grade != profile.grade) {
      profile.grade = grade;
      await resetProgress();
    }
    await storage.saveProfile(profile);
    notifyListeners();
  }

  /// Wipe mastery + question cooldown (e.g. on grade change or a manual reset).
  Future<void> resetProgress() async {
    mastery = {};
    _recentAsked = [];
    await storage.saveMastery(mastery);
    await storage.saveRecentAsked(_recentAsked);
    notifyListeners();
  }

  Future<void> setApiKey(String? key) async {
    await storage.setApiKey(key);
    notifyListeners();
  }

  bool get hasApiKey => storage.apiKey != null && storage.apiKey!.isNotEmpty;

  // ---- Mastery / adaptivity ----
  // Untouched topics start at 0 — mastery is earned from answers, not given.
  double masteryFor(String topic) => mastery[topic] ?? 0.0;

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

  /// The topic the student is weakest at — what Practice should drill next.
  /// Ties (e.g. a fresh start where all are equal) resolve to list order.
  String weakestTopic() {
    var weakest = kPracticeTopics.first;
    var lowest = 2.0;
    for (final t in kPracticeTopics) {
      final m = masteryFor(t); // untouched topics default to 0.3
      if (m < lowest) {
        lowest = m;
        weakest = t;
      }
    }
    return weakest;
  }

  /// Update mastery after an answer, weighted by question difficulty (1..3).
  /// Harder questions are worth more when correct; missing an EASY question
  /// costs more (it signals a real gap), missing a hard one costs little.
  Future<void> recordAnswer(String topic, bool correct, int difficulty) async {
    const gain = {1: 0.06, 2: 0.12, 3: 0.20}; // reward scales up with difficulty
    const penalty = {1: 0.12, 2: 0.08, 3: 0.05}; // penalty scales down
    final d = difficulty.clamp(1, 3);
    final cur = masteryFor(topic);
    final delta = correct ? gain[d]! : -penalty[d]!;
    mastery[topic] = (cur + delta).clamp(0.0, 1.0);
    await storage.saveMastery(mastery);
    notifyListeners();
  }
}
