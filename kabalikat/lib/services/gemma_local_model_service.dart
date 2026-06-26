// ============================================================================
// On-device tutor (Tier 2) via flutter_gemma. Offers a picker of NON-GATED
// models (no HuggingFace token needed):
//   - Qwen2.5 0.5B  (~550 MB)  Apache-2.0   — lightest, lowest bandwidth
//   - Qwen2.5 1.5B  (~1.6 GB)  Apache-2.0   — balanced (default)
//   - Phi-4 mini 3.8B (~3.9 GB) MIT          — best quality, needs a strong phone
// All download with no authentication.
// ============================================================================

import 'package:flutter_gemma/flutter_gemma.dart';
import 'local_model_service.dart';

/// Internal config for one downloadable model.
class _GemmaModel {
  final String id;
  final String label;
  final String size;
  final String note;
  final String url;
  final ModelType type;
  const _GemmaModel(
      this.id, this.label, this.size, this.note, this.url, this.type);
}

class GemmaLocalModelService extends LocalModelService {
  GemmaLocalModelService({String initialModelId = 'qwen15'})
      : _selectedId = initialModelId;

  // All non-gated — download without a token.
  static const List<_GemmaModel> _catalog = [
    _GemmaModel(
      'qwen05',
      'Qwen2.5 0.5B',
      '~550 MB',
      'lightest · lowest bandwidth',
      'https://huggingface.co/litert-community/Qwen2.5-0.5B-Instruct/resolve/main/Qwen2.5-0.5B-Instruct_multi-prefill-seq_q8_ekv1280.task',
      ModelType.qwen,
    ),
    _GemmaModel(
      'qwen15',
      'Qwen2.5 1.5B',
      '~1.6 GB',
      'balanced (recommended)',
      'https://huggingface.co/litert-community/Qwen2.5-1.5B-Instruct/resolve/main/Qwen2.5-1.5B-Instruct_multi-prefill-seq_q8_ekv1280.task',
      ModelType.qwen,
    ),
    _GemmaModel(
      'phi4',
      'Phi-4 mini (3.8B)',
      '~3.9 GB',
      'best quality · needs a strong phone',
      'https://huggingface.co/litert-community/Phi-4-mini-instruct/resolve/main/Phi-4-mini-instruct_multi-prefill-seq_q8_ekv1280.task',
      ModelType.phi,
    ),
  ];

  String _selectedId;
  LocalModelStatus _status = LocalModelStatus.notInstalled;
  double _progress = 0;
  dynamic _model; // the active InferenceModel
  String? _error;

  _GemmaModel get _selected =>
      _catalog.firstWhere((m) => m.id == _selectedId, orElse: () => _catalog[1]);

  @override
  bool get isEnabled => true;

  @override
  String? get errorMessage => _error;

  @override
  LocalModelStatus get status => _status;

  @override
  double get downloadProgress => _progress;

  @override
  String get modelName => '${_selected.label} (on-device)';

  @override
  String get downloadSize => '${_selected.size} · no token needed';

  @override
  List<LocalModelChoice> get availableModels => _catalog
      .map((m) => LocalModelChoice(
          id: m.id, label: m.label, size: m.size, note: m.note))
      .toList();

  @override
  String get selectedModelId => _selectedId;

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
  void selectModel(String id) {
    if (id == _selectedId || !_catalog.any((m) => m.id == id)) return;
    _selectedId = id;
    _error = null;
    _progress = 0;
    // Different model → it isn't downloaded/loaded anymore.
    remove();
  }

  void _set(LocalModelStatus s) {
    _status = s;
    notifyListeners();
  }

  // flutter_gemma must be initialized once (and awaited) before any use.
  static bool _initialized = false;
  Future<void> _ensureInit() async {
    if (_initialized) return;
    await FlutterGemma.initialize(maxDownloadRetries: 5);
    _initialized = true;
  }

  @override
  Future<void> downloadAndLoad() async {
    _error = null;
    final m = _selected;
    // --- Step 1: download the model file (no token; all models non-gated) ---
    try {
      _set(LocalModelStatus.downloading);
      await _ensureInit();
      await FlutterGemma.installModel(modelType: m.type)
          .fromNetwork(m.url)
          .withProgress((p) {
        // flutter_gemma 1.1.x passes an int percentage (0–100).
        _progress = (p / 100.0).clamp(0.0, 1.0);
        notifyListeners();
      }).install();
    } catch (e) {
      _error = 'Download failed: $e';
      _set(LocalModelStatus.notInstalled);
      return;
    }
    // --- Step 2: load it into memory (this is where weak devices fail) ---
    try {
      _model = await FlutterGemma.getActiveModel(
        maxTokens: 1024,
        preferredBackend: PreferredBackend.gpu, // falls back to CPU if no GPU
      );
      _set(LocalModelStatus.ready);
    } catch (e) {
      _error = 'Load failed (device may lack GPU/RAM, e.g. an emulator): $e';
      _set(LocalModelStatus.unsupported);
    }
  }

  @override
  Future<String?> generate(String prompt) async {
    if (_model == null) return null;
    try {
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
