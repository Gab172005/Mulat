import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/l10n_service.dart';
import '../services/ocr_service.dart';

import '../models/student_profile.dart';
import '../models/study_deck.dart';
import '../services/document_service.dart';
import '../services/json_parser.dart';
import '../state/app_state.dart';
import 'deck_view_screen.dart';

class DecksScreen extends StatefulWidget {
  const DecksScreen({super.key});

  @override
  State<DecksScreen> createState() => _DecksScreenState();
}

class _DecksScreenState extends State<DecksScreen> {
  bool _isLoading = false;
  bool _showUploadView = false;

  /// Generates a [StudyDeck] via [HybridStudyContentRepository].
  ///
  /// Fires flashcard and quiz generation in parallel so total wall-clock
  /// time equals the slower of the two (not their sum). Both calls share
  /// the same routing logic: Gemini if online, Ollama cascade if not.
  Future<StudyDeck> _generateDeck(String text, String title) async {
    final appState = context.read<AppState>();
    // Convert AppLanguage enum to the string the repository contract expects.
    final targetLanguage = appState.profile.language.label;

    final results = await Future.wait([
      appState.repo.generateContent(
        extractedText: text,
        targetLanguage: targetLanguage,
        contentFormat: 'flashcards',
      ),
      appState.repo.generateContent(
        extractedText: text,
        targetLanguage: targetLanguage,
        contentFormat: 'quiz',
      ),
    ]);

    // Parse the JSON strings using SecureJsonParser.
    final parsedFlashcards = SecureJsonParser.parseFlashcards(results[0]);
    final parsedQuizzes = SecureJsonParser.parseQuizzes(results[1]);

    // Convert StudyContent items → StudyDeck items.
    final flashcards = parsedFlashcards
        .map((f) => Flashcard(front: f.front, back: f.back))
        .toList();

    final quizzes = parsedQuizzes
        .map((q) => Microquiz(
              question: q.question,
              options: q.options,
              answerIndex: q.correctIndex,
            ))
        .toList();

    return StudyDeck(title: title, flashcards: flashcards, quizzes: quizzes);
  }

  Future<void> _uploadAndGenerateDeck() async {
    final docService = DocumentService();
    final appState = context.read<AppState>();

    final doc = await docService.pickPdf();
    if (doc == null) return; // user cancelled

    if (!doc.hasText) {
      // Scanned/image-only PDF — guide the user to the on-device OCR path.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'No selectable text in this PDF — try "Photograph your notes" to use on-device OCR.'),
          ),
        );
      }
      return;
    }

    setState(() {
      _isLoading = true;
      _showUploadView = false;
    });

    try {
      final deck = await _generateDeck(doc.text, doc.title);
      await appState.addDeck(deck);
      if (mounted) setState(() => _showUploadView = false);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating deck: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature upload is coming soon!')),
    );
  }

  /// ── OCR Path: Photograph notes → ML Kit → LLM ──
  /// Uses on-device OCR (works offline!) to extract text from a photo.
  Future<void> _uploadFromImage({bool fromCamera = false}) async {
    final ocr = OcrService();
    final appState = context.read<AppState>();

    try {
      final text = fromCamera
          ? await ocr.captureAndExtract()
          : await ocr.pickImageAndExtract();

      if (text == null || text.trim().isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not extract text from image.')),
          );
        }
        return;
      }

      setState(() {
        _isLoading = true;
        _showUploadView = false;
      });

      final deck = await _generateDeck(
        text,
        'Photo Notes ${DateTime.now().toLocal().toString().split('.')[0]}',
      );
      await appState.addDeck(deck);
      if (mounted) setState(() => _showUploadView = false);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      ocr.dispose();
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildOptionTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white54, size: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadView(List decks) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: decks.isNotEmpty
          ? AppBar(
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() => _showUploadView = false),
              ),
              backgroundColor: Colors.transparent,
              elevation: 0,
            )
          : null,
      body: SafeArea(
        child: Column(
          children: [
            if (decks.isEmpty) ...[
              // Top blue line
              Container(
                height: 4,
                alignment: Alignment.centerLeft,
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.3,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
            const SizedBox(height: 48),
            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Text(
                "Upload some learning material and we'll learn it together",
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontSize: 22, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 32),
            // Options Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  children: [
                    _buildOptionTile(
                      icon: Icons.description,
                      iconColor: Colors.redAccent,
                      title: 'PDF',
                      onTap: _uploadAndGenerateDeck,
                    ),
                    const Divider(height: 1, color: Colors.white12),
                    _buildOptionTile(
                      icon: Icons.edit_note,
                      iconColor: Colors.blueAccent,
                      title: 'Paste notes',
                      onTap: () => _showComingSoon('Paste notes'),
                    ),
                    const Divider(height: 1, color: Colors.white12),
                    _buildOptionTile(
                      icon: Icons.slideshow,
                      iconColor: Colors.orangeAccent,
                      title: 'PowerPoint',
                      onTap: () => _showComingSoon('PowerPoint'),
                    ),
                    const Divider(height: 1, color: Colors.white12),
                    _buildOptionTile(
                      icon: Icons.play_circle_fill,
                      iconColor: Colors.red,
                      title: 'YouTube',
                      onTap: () => _showComingSoon('YouTube'),
                    ),
                    const Divider(height: 1, color: Colors.white12),
                    _buildOptionTile(
                      icon: Icons.camera_alt,
                      iconColor: Colors.greenAccent,
                      title: 'Photograph your notes',
                      onTap: () => _uploadFromImage(fromCamera: true),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            TextButton(
              onPressed: () {},
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Show more', style: TextStyle(color: Colors.white70, fontSize: 16)),
                  SizedBox(width: 4),
                  Icon(Icons.keyboard_arrow_down, color: Colors.white70, size: 20),
                ],
              ),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final decks = context.watch<AppState>().decks;

    if (_showUploadView || decks.isEmpty && !_isLoading) {
      return _buildUploadView(decks);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Study Decks'.tr(context)),
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text('Reading document & generating flashcards...'.tr(context)),
                  Text('This may take a moment on local AI.'.tr(context)),
                ],
              ),
            )
          : ListView.builder(
              itemCount: decks.length,
              itemBuilder: (context, index) {
                final deck = decks[index];
                return ListTile(
                  leading: const Icon(Icons.style),
                  title: Text(deck.title),
                  subtitle: Text('${deck.flashcards.length} cards'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () async {
                      await context.read<AppState>().removeDeck(deck.id);
                    },
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DeckViewScreen(deck: deck),
                      ),
                    );
                  },
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isLoading ? null : () => setState(() => _showUploadView = true),
        icon: const Icon(Icons.add),
        label: Text('New Deck'.tr(context)),
      ),
    );
  }
}
