import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/student_profile.dart';

/// Thin wrapper around SharedPreferences for profile, mastery, settings.
class StorageService {
  late SharedPreferences _prefs;

  static const _kProfile = 'profile';
  static const _kMastery = 'mastery'; // Map<topic, double 0..1>
  static const _kApiKey = 'api_key';
  static const _kModelId = 'on_device_model_id'; // chosen on-device model
  static const _kRecent = 'recent_asked'; // List<String> recent question prompts

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // ---- Profile ----
  StudentProfile loadProfile() {
    final raw = _prefs.getString(_kProfile);
    if (raw == null) return StudentProfile();
    return StudentProfile.fromJson(jsonDecode(raw));
  }

  Future<void> saveProfile(StudentProfile p) =>
      _prefs.setString(_kProfile, jsonEncode(p.toJson()));

  // ---- Mastery ----
  Map<String, double> loadMastery() {
    final raw = _prefs.getString(_kMastery);
    if (raw == null) return {};
    final m = jsonDecode(raw) as Map<String, dynamic>;
    return m.map((k, v) => MapEntry(k, (v as num).toDouble()));
  }

  Future<void> saveMastery(Map<String, double> m) =>
      _prefs.setString(_kMastery, jsonEncode(m));

  // ---- API key (optional, for live AI) ----
  String? get apiKey => _prefs.getString(_kApiKey);
  Future<void> setApiKey(String? key) async {
    if (key == null || key.isEmpty) {
      await _prefs.remove(_kApiKey);
    } else {
      await _prefs.setString(_kApiKey, key);
    }
  }

  // ---- Selected on-device model id ----
  String? get modelId => _prefs.getString(_kModelId);
  Future<void> setModelId(String id) => _prefs.setString(_kModelId, id);

  // ---- Recently-asked questions (spaced-repetition cooldown) ----
  List<String> loadRecentAsked() {
    final raw = _prefs.getString(_kRecent);
    if (raw == null) return [];
    return List<String>.from(jsonDecode(raw));
  }

  Future<void> saveRecentAsked(List<String> items) =>
      _prefs.setString(_kRecent, jsonEncode(items));
}
