import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// Result of picking and extracting a document.
class PickedDocument {
  /// Cleaned, extracted plain text (ready to feed the LLM).
  final String text;

  /// A human title derived from the file name (used as the deck title).
  final String title;

  /// Number of pages in the source PDF.
  final int pageCount;

  /// True when the PDF contained selectable text. False usually means a
  /// scanned/photo PDF — the UI can then suggest the OCR (photo) path.
  bool get hasText => text.trim().isNotEmpty;

  const PickedDocument({
    required this.text,
    required this.title,
    required this.pageCount,
  });
}

/// ─── DOCUMENT SERVICE ────────────────────────────────────────────────
/// Picks a PDF and extracts clean, LLM-ready text.
///
/// Improvements over a naive extractText() call:
///   • Page-by-page extraction so a failure on one page doesn't lose the
///     whole document, and so we can report an accurate page count.
///   • Whitespace normalisation — collapses the ragged spacing/newlines
///     PDF extractors emit, which otherwise waste tokens and confuse the
///     model's sentence splitting.
///   • Scanned-PDF detection — returns hasText == false so the caller can
///     guide the user to the offline OCR path instead of silently failing.
///   • Deck title derived from the file name, not a timestamp.
class DocumentService {
  /// Prompts the user to pick a PDF and returns the extracted document.
  /// Returns null if the user cancelled or the file could not be read.
  Future<PickedDocument?> pickPdf() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: false,
        withData: false,
      );
      if (result == null || result.files.isEmpty) return null;

      final picked = result.files.single;
      final path = picked.path;
      if (path == null) return null;

      final bytes = await File(path).readAsBytes();
      return _extract(bytes, picked.name);
    } catch (e) {
      // ignore: avoid_print
      print('[DocumentService] PDF pick/extract failed: $e');
      return null;
    }
  }

  /// Backwards-compatible helper: just the text (or null).
  Future<String?> pickAndExtractPdf() async => (await pickPdf())?.text;

  PickedDocument _extract(List<int> bytes, String fileName) {
    final document = PdfDocument(inputBytes: bytes);
    final pageCount = document.pages.count;
    final extractor = PdfTextExtractor(document);

    final buffer = StringBuffer();
    for (var i = 0; i < pageCount; i++) {
      try {
        final pageText =
            extractor.extractText(startPageIndex: i, endPageIndex: i);
        final trimmed = pageText.trim();
        if (trimmed.isNotEmpty) buffer.writeln(trimmed);
      } catch (_) {
        // Skip an unreadable page rather than failing the whole document.
      }
    }
    document.dispose();

    return PickedDocument(
      text: _clean(buffer.toString()),
      title: _titleFromFileName(fileName),
      pageCount: pageCount,
    );
  }

  /// Collapse the noisy whitespace PDF extraction produces.
  static String _clean(String raw) {
    return raw
        // Windows/Mac line endings → \n
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        // Strip trailing spaces on each line.
        .replaceAll(RegExp(r'[ \t]+\n'), '\n')
        // Collapse runs of blank lines into a single paragraph break.
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        // Collapse runs of spaces.
        .replaceAll(RegExp(r'[ \t]{2,}'), ' ')
        .trim();
  }

  /// "BIO Chapter 3 - Cells.pdf" → "BIO Chapter 3 - Cells".
  static String _titleFromFileName(String fileName) {
    var name = fileName.split(Platform.pathSeparator).last;
    name = name.replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '');
    name = name.replaceAll(RegExp(r'[_]+'), ' ').trim();
    return name.isEmpty ? 'PDF Deck' : name;
  }
}
