// ============================================================================
// READY-TO-ACTIVATE: on-device Gemma tutor via flutter_gemma (Tier 2).
//
// This file is .txt on purpose so it is NOT compiled by default — that keeps
// the hackathon build green even if the package version drifts. To enable:
//
//   1. Add to pubspec.yaml:   flutter_gemma: ^0.14.1   (check pub.dev for latest)
//   2. Rename this file to    gemma_local_model_service.dart
//   3. In app_state.dart, swap:
//          final LocalModelService localModel = StubLocalModelService();
//      for:
//          final LocalModelService localModel = GemmaLocalModelService();
//   4. Do the platform setup (see ON_DEVICE_MODEL.md) and run.
//
// API verified against flutter_gemma's modern API (FlutterGemma.installModel /
// getActiveModel / createChat). If you bump the package and the API changed,
// adjust the three calls marked  // API.
// ============================================================================

import 'package:flutter_gemma/flutter_gemma.dart';
import 'local_model_service.dart';

class GemmaLocalModelService extends LocalModelService {
  GemmaLocalModelService({
    // Gemma 3 1B is a good size/quality balance for mid-range phones.
    this.modelUrl =
        'https://huggingface.co/litert-community/Gemma3-1B-IT/resolve/main/Gemma3-1B-IT_multi-prefill-seq_q8_ekv1280.task',
    this.huggingFaceToken, // some models require a HF token
  });

  final String modelUrl;
  final String? huggingFaceToken;

  LocalModelStatus _status = LocalModelStatus.notInstalled;
  double _progress = 0;
  dynamic _model; // the active InferenceModel

  @override
  bool get isEnabled => true;

  @override
  LocalModelStatus get status => _status;

  @override
  double get downloadProgress => _progress;

  @override
  String get modelName => 'Gemma 3 1B (on-device)';

  @override
  String get downloadSize => '~550 MB, one-time';

  void _set(LocalModelStatus s) {
    _status = s;
    notifyListeners();
  }

  @override
  Future<void> downloadAndLoad() async {
    try {
      _set(LocalModelStatus.downloading);
      // API: install the model file from the network with progress.
      await FlutterGemma.installModel(modelType: ModelType.gemmaIt)
          .fromNetwork(modelUrl, token: huggingFaceToken)
          .withProgress((p) {
        // flutter_gemma 1.1.x passes an int percentage (0–100).
        _progress = (p / 100.0).clamp(0.0, 1.0);
        notifyListeners();
      }).install();

      // API: load the installed model into memory.
      _model = await FlutterGemma.getActiveModel(
        maxTokens: 1024,
        preferredBackend: PreferredBackend.gpu, // falls back to CPU if no GPU
      );
      _set(LocalModelStatus.ready);
    } catch (_) {
      // Most failures here are device capability (RAM/GPU) — mark unsupported
      // so the app cleanly falls back to cached content.
      _set(LocalModelStatus.unsupported);
    }
  }

  @override
  Future<void> remove() async {
    try {
      await _model?.close();
    } catch (_) {}
    _model = null;
    _progress = 0;
    _set(LocalModelStatus.notInstalled);
  }

  @override
  Future<String?> generate(String prompt) async {
    if (_model == null) return null;
    try {
      // API: one-shot chat turn. (Return type is String in current versions;
      // if your version returns a response object, read its `.text`/`.token`.)
      final chat = await _model.createChat(
        systemInstruction:
            'You are Kabalikat, a patient bilingual (Filipino/English) study '
            'tutor. Keep answers short and simple.',
      );
      await chat.addQueryChunk(Message.text(text: prompt, isUser: true));
      final response = await chat.generateChatResponse();
      return response is String ? response : response.toString();
    } catch (_) {
      return null;
    }
  }
}
