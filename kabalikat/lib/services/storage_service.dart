import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/student_profile.dart';
import '../models/study_deck.dart';
import '../models/chat_message.dart';
import '../models/review_state.dart';

/// Thin wrapper around SharedPreferences for profile, mastery, settings.
class StorageService {
  late SharedPreferences _prefs;

  static const _kProfile = 'profile';
  static const _kMastery = 'mastery'; // Map<topic, double 0..1>
  static const _kApiKey = 'api_key';
  static const _kDecks = 'decks';
  static const _kChat = 'chat_history'; // List<ChatMessage>
  static const _kReviews = 'reviews'; // Map<deckTitle, ReviewState>

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

  // ---- Decks ----
  List<StudyDeck> loadDecks() {
    final raw = _prefs.getStringList(_kDecks);
    if (raw == null) return [];
    return raw.map((e) => StudyDeck.fromJson(jsonDecode(e))).toList();
  }

  Future<void> saveDeck(StudyDeck deck) async {
    final decks = loadDecks();
    final index = decks.indexWhere((d) => d.id == deck.id);
    if (index >= 0) {
      decks[index] = deck;
    } else {
      decks.add(deck);
    }
    await _prefs.setStringList(_kDecks, decks.map((d) => jsonEncode(d.toJson())).toList());
  }

  Future<void> deleteDeck(String id) async {
    final decks = loadDecks();
    decks.removeWhere((d) => d.id == id);
    await _prefs.setStringList(_kDecks, decks.map((d) => jsonEncode(d.toJson())).toList());
  }

  // ---- Chat history (lets the tutor remember the conversation) ----
  List<ChatMessage> loadChat() {
    final raw = _prefs.getStringList(_kChat);
    if (raw == null) return [];
    return raw.map((e) => ChatMessage.fromJson(jsonDecode(e))).toList();
  }

  Future<void> saveChat(List<ChatMessage> messages) {
    // Keep storage bounded — only persist the most recent 60 turns.
    final trimmed =
        messages.length > 60 ? messages.sublist(messages.length - 60) : messages;
    return _prefs.setStringList(
      _kChat,
      trimmed.map((m) => jsonEncode(m.toJson())).toList(),
    );
  }

  Future<void> clearChat() => _prefs.remove(_kChat);

  // ---- Spaced-repetition review schedule (per deck) ----
  Map<String, ReviewState> loadReviews() {
    final raw = _prefs.getString(_kReviews);
    if (raw == null) return {};
    final m = jsonDecode(raw) as Map<String, dynamic>;
    return m.map((k, v) => MapEntry(k, ReviewState.fromJson(v)));
  }

  Future<void> saveReviews(Map<String, ReviewState> reviews) =>
      _prefs.setString(
        _kReviews,
        jsonEncode(reviews.map((k, v) => MapEntry(k, v.toJson()))),
      );

  // ---- Demo / progress reset helpers ----
  Future<void> clearProgress() async {
    await _prefs.remove(_kMastery);
    await _prefs.remove(_kReviews);
    await _prefs.remove(_kChat);
  }
}
