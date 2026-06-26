import 'package:flutter/foundation.dart';

/// Lifecycle of the optional on-device model (Tier 2 in our fallback chain).
enum LocalModelStatus {
  notInstalled, // no model on the device yet
  downloading, // download in progress
  ready, // loaded and usable offline
  unsupported, // device can't run it (too little RAM, etc.)
}

/// A selectable on-device model option (engine-agnostic, for the picker UI).
class LocalModelChoice {
  final String id;
  final String label; // e.g. "Qwen2.5 1.5B"
  final String size; // e.g. "~1.6 GB"
  final String note; // e.g. "balanced" / "best, needs a strong phone"
  const LocalModelChoice({
    required this.id,
    required this.label,
    required this.size,
    required this.note,
  });
}

/// Abstraction for an on-device LLM (e.g. Gemma via flutter_gemma / MediaPipe).
///
/// This interface is what the rest of the app talks to. The default
/// [StubLocalModelService] does nothing, so the app compiles and the demo runs
/// with ZERO extra dependencies. To enable a real model, drop in the
/// flutter_gemma implementation from `local_model_gemma_reference.txt`
/// (see ON_DEVICE_MODEL.md) and swap it in `AppState`.
abstract class LocalModelService extends ChangeNotifier {
  /// True only when a real engine (e.g. flutter_gemma) is wired in. The stub
  /// returns false so the Settings UI can show an "enable me" hint instead of
  /// a dead download button.
  bool get isEnabled;

  LocalModelStatus get status;
  double get downloadProgress; // 0..1
  bool get isReady => status == LocalModelStatus.ready;

  /// Last failure detail (for the Settings UI). Null when there's no error.
  String? get errorMessage => null;

  /// Models the user can pick from (all non-gated). Empty in the stub.
  List<LocalModelChoice> get availableModels => const [];

  /// Currently-selected model id.
  String get selectedModelId => '';

  /// Switch the active model (resets download state). No-op in stub.
  void selectModel(String id) {}

  /// Human-readable model name (for the Settings UI).
  String get modelName;

  /// Approx download size, shown to the user before they commit.
  String get downloadSize;

  /// Begin downloading + loading the model. No-op in the stub.
  Future<void> downloadAndLoad();

  /// Remove the downloaded model to free space.
  Future<void> remove();

  /// Generate a tutor answer fully on-device. Returns null if unavailable.
  Future<String?> generate(String prompt);
}

/// Default no-op implementation. Always reports "not installed" and never
/// generates — so Tier 2 is simply skipped and the app falls back to cached
/// content. Keeps the build dependency-free and the demo bulletproof.
class StubLocalModelService extends LocalModelService {
  @override
  bool get isEnabled => false;

  @override
  LocalModelStatus get status => LocalModelStatus.notInstalled;

  @override
  double get downloadProgress => 0;

  @override
  String get modelName => 'Gemma 3 1B (on-device)';

  @override
  String get downloadSize => '~550 MB, one-time';

  @override
  Future<void> downloadAndLoad() async {
    // Intentionally a no-op. Real download lives in the flutter_gemma impl.
  }

  @override
  Future<void> remove() async {}

  @override
  Future<String?> generate(String prompt) async => null;
}
