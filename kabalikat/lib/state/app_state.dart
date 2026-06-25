import 'package:flutter/foundation.dart';

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

  AppState(this.storage) {
    ai = AiService(connectivity, storage, localModel);
  }

  Future<void> load() async {
    profile = storage.loadProfile();
    mastery = storage.loadMastery();
    await connectivity.init();
    connectivity.onChange.listen((_) => notifyListeners());
    localModel.addListener(notifyListeners);
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

  bool get hasApiKey => storage.apiKey != null && storage.apiKey!.isNotEmpty;

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
    final next =
        correct ? (cur + 0.15).clamp(0.0, 1.0) : (cur - 0.1).clamp(0.0, 1.0);
    mastery[topic] = next;
    await storage.saveMastery(mastery);
    notifyListeners();
  }
}
