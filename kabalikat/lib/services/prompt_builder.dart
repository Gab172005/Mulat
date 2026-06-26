/// ─── OLLAMA FEW-SHOT PROMPT BUILDER ─────────────────────────────────
/// Constructs strict System + User prompts for Ollama local models.
///
/// DESIGN DECISIONS:
/// • Few-shot examples are embedded directly to guide small models (3B/2B)
///   into producing valid JSON — critical because these models hallucinate
///   structure more than large ones.
/// • System prompt enforces JSON-only output; the Ollama API call also
///   sets {"format": "json"} to double-enforce.
/// • All examples are bilingual (Taglish/English) since that's the target
///   audience.
/// • Prompts are kept under ~2k tokens to leave room for input text in
///   the 8k context window of small models.

/// Content generation modes.
enum ContentMode { reviewer, flashcards, quiz }

/// Returns a (systemPrompt, userPrompt) pair for Ollama.
({String system, String user}) buildOllamaPrompt({
  required String extractedText,
  required ContentMode mode,
}) {
  // ── Shared system instruction ──────────────────────────────────────
  const systemBase = '''You are a study content generator for Filipino students.
You MUST respond with ONLY valid JSON. No markdown, no explanation, no extra text.
All content should be in Taglish (mix of Filipino and English) to help Filipino learners.
Extract information ONLY from the provided document text.''';

  switch (mode) {
    case ContentMode.reviewer:
      return (
        system: systemBase,
        user: _buildReviewerPrompt(extractedText),
      );
    case ContentMode.flashcards:
      return (
        system: systemBase,
        user: _buildFlashcardsPrompt(extractedText),
      );
    case ContentMode.quiz:
      return (
        system: systemBase,
        user: _buildQuizPrompt(extractedText),
      );
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  REVIEWER PROMPT — Key Concepts Summary
// ═══════════════════════════════════════════════════════════════════════
String _buildReviewerPrompt(String text) => '''
Generate a reviewer (key concepts summary) from the document below.
Return ONLY valid JSON. Generate AT LEAST 5 items.

FORMAT (follow EXACTLY):
{
  "reviewers": [
    {
      "concept": "Concept title in Taglish",
      "explanation": "Clear explanation in Taglish",
      "example": "A concrete example"
    }
  ]
}

FEW-SHOT EXAMPLE (for a biology document about cells):
{
  "reviewers": [
    {
      "concept": "Cell Theory (Teorya ng Selula)",
      "explanation": "Lahat ng living things ay gawa sa cells. Ang cell ang basic unit of life. All cells come from pre-existing cells.",
      "example": "Halimbawa, ang human body ay may trillions of cells na may iba-ibang function."
    },
    {
      "concept": "Prokaryotic vs Eukaryotic Cells",
      "explanation": "Ang prokaryotic cells (like bacteria) ay walang nucleus, while eukaryotic cells (like human cells) ay may membrane-bound nucleus.",
      "example": "Ang E. coli ay prokaryote, habang ang muscle cells natin ay eukaryote."
    },
    {
      "concept": "Cell Membrane (Lamad ng Selula)",
      "explanation": "Ito ang outer layer ng cell na nagco-control kung ano ang pumapasok at lumalabas. Semi-permeable siya.",
      "example": "Parang security guard ng cell — pinapapasok lang ang mga kailangan."
    }
  ]
}

──────────────────────────────────
DOCUMENT TEXT:
$text
──────────────────────────────────
Generate the reviewer JSON now:''';

// ═══════════════════════════════════════════════════════════════════════
//  FLASHCARDS PROMPT — Front/Back in Taglish/English
// ═══════════════════════════════════════════════════════════════════════
String _buildFlashcardsPrompt(String text) => '''
Generate flashcards from the document below.
Return ONLY valid JSON. Generate AT LEAST 10 flashcards.
Front = question in Taglish. Back = answer in Taglish.

FORMAT (follow EXACTLY):
{
  "flashcards": [
    {"front": "Question in Taglish", "back": "Answer in Taglish"}
  ]
}

FEW-SHOT EXAMPLE (for a Philippine history document):
{
  "flashcards": [
    {"front": "Kailan na-establish ang First Philippine Republic?", "back": "January 23, 1899, sa Malolos, Bulacan. Si Emilio Aguinaldo ang naging first president."},
    {"front": "Ano ang Cry of Pugad Lawin?", "back": "Ito ang event noong August 1896 kung saan pinunit ng mga Katipunero ang kanilang cedula bilang sign of revolt laban sa Spain."},
    {"front": "Sino si Andres Bonifacio at bakit siya important?", "back": "Siya ang founder ng Katipunan, ang secret revolutionary society na nag-lead ng uprising laban sa mga Espanyol."},
    {"front": "Ano ang significance ng Treaty of Paris (1898)?", "back": "Dito ibinenta ng Spain ang Philippines sa United States for \$20 million, ending Spanish colonial rule pero beginning American occupation."},
    {"front": "Ano ang Propaganda Movement?", "back": "Reform movement ng mga educated Filipinos (ilustrados) like Rizal at Del Pilar na nag-campaign for equal rights through peaceful means, hindi revolution."}
  ]
}

──────────────────────────────────
DOCUMENT TEXT:
$text
──────────────────────────────────
Generate the flashcards JSON now:''';

// ═══════════════════════════════════════════════════════════════════════
//  MICRO-QUIZ PROMPT — MCQ with options and correct answer
// ═══════════════════════════════════════════════════════════════════════
String _buildQuizPrompt(String text) => '''
Generate multiple-choice quiz questions from the document below.
Return ONLY valid JSON. Generate AT LEAST 10 questions.
Each question has 4 options. correctIndex is 0-based.

FORMAT (follow EXACTLY):
{
  "quizzes": [
    {
      "question": "Question in Taglish",
      "options": ["Option A", "Option B", "Option C", "Option D"],
      "correctIndex": 0
    }
  ]
}

FEW-SHOT EXAMPLE (for a science document about ecosystems):
{
  "quizzes": [
    {
      "question": "Ano ang tawag sa organism na gumagawa ng sariling pagkain through photosynthesis?",
      "options": ["Consumer", "Producer", "Decomposer", "Predator"],
      "correctIndex": 1
    },
    {
      "question": "Alin sa mga ito ang example ng abiotic factor sa isang ecosystem?",
      "options": ["Damo (grass)", "Sunlight", "Bacteria", "Insekto"],
      "correctIndex": 1
    },
    {
      "question": "Sa food chain, ano ang role ng mga decomposers?",
      "options": ["Kumakain ng ibang animals", "Gumagawa ng pagkain from sunlight", "Bine-break down ang dead organisms at ni-return ang nutrients sa soil", "Kumokontrol ng population ng prey"],
      "correctIndex": 2
    },
    {
      "question": "Ano ang tawag sa relationship kung saan parehong nag-benefit ang dalawang organisms?",
      "options": ["Parasitism", "Commensalism", "Mutualism", "Competition"],
      "correctIndex": 2
    }
  ]
}

──────────────────────────────────
DOCUMENT TEXT:
$text
──────────────────────────────────
Generate the quiz JSON now:''';
