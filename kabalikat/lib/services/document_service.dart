import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'dart:io';

class DocumentService {
  /// Prompts the user to pick a PDF document and extracts its text.
  /// Returns null if the user canceled or an error occurred.
  Future<String?> pickAndExtractPdf() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final path = result.files.single.path!;
        return _extractTextFromPdf(path);
      }
    } catch (e) {
      print('Error picking or extracting PDF: $e');
    }
    return null;
  }

  String _extractTextFromPdf(String path) {
    final bytes = File(path).readAsBytesSync();
    final document = PdfDocument(inputBytes: bytes);
    final extractor = PdfTextExtractor(document);
    String text = extractor.extractText();
    document.dispose();
    return text.trim();
  }
}
