import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

/// ─── OFFLINE OCR SERVICE ─────────────────────────────────────────────
/// Uses Google ML Kit Text Recognition to extract text from images
/// entirely on-device — NO internet required.
///
/// ARCHITECTURE:
///   Camera/Gallery → Image file → ML Kit on-device OCR → Clean text string
///   → Feed to LLM (Gemini or Ollama) for study content generation.
///
/// WHY THIS MATTERS:
///   • Filipino learners often photograph handwritten notes or textbook pages.
///   • Sending raw images to an LLM is expensive (tokens) and impossible offline.
///   • ML Kit runs on-device, so OCR works even in zero-connectivity barangays.
///   • We pass the extracted TEXT to the LLM, which is 100x cheaper and works
///     with both the online (Gemini) and offline (Ollama) pipelines.

class OcrService {
  final TextRecognizer _recognizer = TextRecognizer(
    script: TextRecognitionScript.latin, // Works for English + Filipino (Latin script)
  );
  final ImagePicker _picker = ImagePicker();

  /// Pick an image from gallery and extract text.
  Future<String?> pickImageAndExtract() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 2048, // Keep resolution reasonable for OCR accuracy
      maxHeight: 2048,
      imageQuality: 90,
    );
    if (image == null) return null;
    return extractTextFromFile(File(image.path));
  }

  /// Capture a photo and extract text.
  Future<String?> captureAndExtract() async {
    final XFile? photo = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 2048,
      maxHeight: 2048,
      imageQuality: 90,
    );
    if (photo == null) return null;
    return extractTextFromFile(File(photo.path));
  }

  /// Core OCR: extract text from an image file path.
  /// Returns cleaned, concatenated text ready for LLM input.
  Future<String?> extractTextFromFile(File imageFile) async {
    try {
      final inputImage = InputImage.fromFile(imageFile);
      final RecognizedText result = await _recognizer.processImage(inputImage);

      if (result.text.isEmpty) return null;

      // ── Post-processing ──────────────────────────────────────────
      // ML Kit returns blocks → lines → elements. We reconstruct
      // readable paragraphs by joining with appropriate spacing.
      final buffer = StringBuffer();
      for (final block in result.blocks) {
        for (final line in block.lines) {
          buffer.writeln(line.text);
        }
        buffer.writeln(); // Paragraph break between blocks.
      }

      final cleaned = buffer.toString().trim();
      return cleaned.isEmpty ? null : cleaned;
    } catch (e) {
      print('OCR extraction error: $e');
      return null;
    }
  }

  /// Extract from a file path string (convenience wrapper).
  Future<String?> extractFromPath(String path) async {
    return extractTextFromFile(File(path));
  }

  /// Call this when the service is no longer needed to free resources.
  void dispose() {
    _recognizer.close();
  }
}
