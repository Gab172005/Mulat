/// ─── OLLAMA FEW-SHOT PROMPT BUILDER ─────────────────────────────────
/// Constructs strict System + User prompts for Ollama local models.
///
/// OPTIMIZATION TECHNIQUES APPLIED:
/// • Taglish Anchoring — language instructions are repeated IN Filipino
///   to inject Filipino tokens into the attention context, preventing
///   the model from decaying to pure English mid-generation.
/// • Silent Chain-of-Thought — a `_reasoning` field gives the model
///   scratch space to plan each item before writing it. The field is
///   stripped by SecureJsonParser after parsing.
/// • Negative Few-Shot — "BAD EXAMPLE" blocks teach the model what NOT
///   to do, which small models learn from faster than positive-only.
/// • Mid-Prompt Reminders — Taglish reinforcement placed between the
///   instructions and the document text to survive attention dilution.
///
/// PROMPT TOKEN BUDGET (~2k tokens):
///   System prompt:        ~150 tokens
///   Few-shot + negative:  ~400 tokens
///   Scaffolding/reminder: ~100 tokens
///   Input text (6k char): ~1500 tokens
///   ─────────────────────────────────
///   TOTAL INPUT:          ~2150 tokens  (fits in 4096 ctx with ~1900 for output)

/// Content generation modes.
enum ContentMode { reviewer, flashcards, quiz }

/// Returns a (systemPrompt, userPrompt) pair for Ollama.
({String system, String user}) buildOllamaPrompt({
  required String extractedText,
  required ContentMode mode,
}) {
  // ── Taglish-anchored system instruction ────────────────────────────
  // Key change: the Taglish rule is REPEATED IN FILIPINO to bias the
  // model's attention toward Filipino token generation. Negative
  // constraints ("HINDI pure English") are more effective than
  // positive-only instructions for small models.
  const systemBase = '''You are Kabalikat, a study content generator for Filipino students.
You MUST respond with ONLY valid JSON. No markdown fences. No explanations before or after the JSON.

LANGUAGE RULE: Write ALL content in TAGLISH.
Taglish = Filipino sentence structure + English technical terms.
HINDI pure English. HINDI pure Filipino.
Mag-Taglish ka PALAGI sa bawat item — huwag kalimutan!

QUALITY RULES:
- Extract information ONLY from the provided document text. NEVER invent facts.
- Each item must cover a DIFFERENT concept. No rephrasing the same idea.
- Keep answers concise: 1-3 sentences per item.''';

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
//  REVIEWER PROMPT — Key Concepts Summary + Silent CoT
// ═══════════════════════════════════════════════════════════════════════
String _buildReviewerPrompt(String text) => '''
Generate a reviewer (key concepts summary) from the document below.
Return ONLY valid JSON. Generate AT LEAST 5 items.

Before writing each item, use the "_reasoning" field to plan what concept
you will cover and confirm it is DIFFERENT from previous items.
The "_reasoning" field is for your internal planning only and will be discarded.

FORMAT (follow EXACTLY):
{
  "reviewers": [
    {
      "_reasoning": "Planning note about which concept to cover next",
      "concept": "Concept title in Taglish",
      "explanation": "Clear explanation in Taglish",
      "example": "A concrete example"
    }
  ]
}

GOOD EXAMPLE (for a biology document about cells):
{
  "reviewers": [
    {
      "_reasoning": "Starting with Cell Theory - the foundational concept. Will use Taglish with Filipino framing.",
      "concept": "Cell Theory (Teorya ng Selula)",
      "explanation": "Lahat ng living things ay gawa sa cells. Ang cell ang basic unit of life. All cells come from pre-existing cells.",
      "example": "Halimbawa, ang human body ay may trillions of cells na may iba-ibang function."
    },
    {
      "_reasoning": "Next: Prokaryotic vs Eukaryotic - different from Cell Theory. Comparison-style explanation.",
      "concept": "Prokaryotic vs Eukaryotic Cells",
      "explanation": "Ang prokaryotic cells (like bacteria) ay walang nucleus, while eukaryotic cells (like human cells) ay may membrane-bound nucleus.",
      "example": "Ang E. coli ay prokaryote, habang ang muscle cells natin ay eukaryote."
    },
    {
      "_reasoning": "Cell Membrane - different structural concept. Using analogy for the example.",
      "concept": "Cell Membrane (Lamad ng Selula)",
      "explanation": "Ito ang outer layer ng cell na nagco-control kung ano ang pumapasok at lumalabas. Semi-permeable siya.",
      "example": "Parang security guard ng cell — pinapapasok lang ang mga kailangan."
    }
  ]
}

BAD EXAMPLE (DO NOT generate like this):
{
  "reviewers": [
    {"concept": "Cell Theory", "explanation": "All living things are made of cells. The cell is the basic unit of life.", "example": "The human body has trillions of cells."},
    {"concept": "Cell Theory Principles", "explanation": "Cells are the fundamental unit of structure and function.", "example": "Every organism is composed of cells."}
  ]
}
WHY THIS IS BAD: Pure English (not Taglish). Two items about the same concept (Cell Theory). No "_reasoning" field.

REMINDER: Ang bawat reviewer item ay dapat TAGLISH — huwag kalimutan!

──────────────────────────────────
DOCUMENT TEXT:
$text
──────────────────────────────────
Generate the reviewer JSON now. LAHAT ng content ay TAGLISH:''';

// ═══════════════════════════════════════════════════════════════════════
//  FLASHCARDS PROMPT — Front/Back in Taglish + Silent CoT
// ═══════════════════════════════════════════════════════════════════════
String _buildFlashcardsPrompt(String text) => '''
Generate flashcards from the document below.
Return ONLY valid JSON. Generate AT LEAST 10 flashcards.
Front = question in Taglish. Back = answer in Taglish.

Before writing each flashcard, use the "_reasoning" field to plan what
concept you will cover and confirm it is DIFFERENT from previous cards.
The "_reasoning" field is for your internal planning only and will be discarded.

FORMAT (follow EXACTLY):
{
  "flashcards": [
    {
      "_reasoning": "Planning note about which concept to cover",
      "front": "Question in Taglish",
      "back": "Answer in Taglish"
    }
  ]
}

GOOD EXAMPLE (for a Philippine history document):
{
  "flashcards": [
    {
      "_reasoning": "Covering the First Philippine Republic establishment date. Using 'Kailan' question word.",
      "front": "Kailan na-establish ang First Philippine Republic?",
      "back": "January 23, 1899, sa Malolos, Bulacan. Si Emilio Aguinaldo ang naging first president."
    },
    {
      "_reasoning": "Moving to Cry of Pugad Lawin - different event from #1. Using 'Ano ang' pattern.",
      "front": "Ano ang Cry of Pugad Lawin?",
      "back": "Ito ang event noong August 1896 kung saan pinunit ng mga Katipunero ang kanilang cedula bilang sign of revolt laban sa Spain."
    },
    {
      "_reasoning": "Covering Andres Bonifacio - a person, not an event. Using 'Sino' question word for variety.",
      "front": "Sino si Andres Bonifacio at bakit siya important?",
      "back": "Siya ang founder ng Katipunan, ang secret revolutionary society na nag-lead ng uprising laban sa mga Espanyol."
    },
    {
      "_reasoning": "Treaty of Paris - international agreement, different category. Using 'Ano ang significance' pattern.",
      "front": "Ano ang significance ng Treaty of Paris (1898)?",
      "back": "Dito ibinenta ng Spain ang Philippines sa United States for \$20 million, ending Spanish colonial rule pero beginning American occupation."
    },
    {
      "_reasoning": "Propaganda Movement - a movement, not a single event. Different from all above.",
      "front": "Ano ang Propaganda Movement?",
      "back": "Reform movement ng mga educated Filipinos (ilustrados) like Rizal at Del Pilar na nag-campaign for equal rights through peaceful means, hindi revolution."
    }
  ]
}

BAD EXAMPLE (DO NOT generate like this):
{
  "flashcards": [
    {"front": "What is the First Philippine Republic?", "back": "It was the first republic in Asia, established in 1899."},
    {"front": "When was the First Philippine Republic established?", "back": "It was established on January 23, 1899."}
  ]
}
WHY THIS IS BAD: Pure English (not Taglish). Two cards about the same concept. No "_reasoning" field. Answers too vague.

REMINDER: Ang bawat flashcard ay dapat TAGLISH — huwag kalimutan!

──────────────────────────────────
DOCUMENT TEXT:
$text
──────────────────────────────────
Generate the flashcards JSON now. LAHAT ng content ay TAGLISH:''';

// ═══════════════════════════════════════════════════════════════════════
//  MICRO-QUIZ PROMPT — MCQ with Silent CoT + Taglish Anchoring
// ═══════════════════════════════════════════════════════════════════════
String _buildQuizPrompt(String text) => '''
Generate multiple-choice quiz questions from the document below.
Return ONLY valid JSON. Generate AT LEAST 10 questions.
Each question has 4 options. correctIndex is 0-based.

Before writing each question, use the "_reasoning" field to plan what
concept you will test and confirm it is DIFFERENT from previous questions.
The "_reasoning" field is for your internal planning only and will be discarded.

FORMAT (follow EXACTLY):
{
  "quizzes": [
    {
      "_reasoning": "Planning note about which concept to test",
      "question": "Question in Taglish",
      "options": ["Option A", "Option B", "Option C", "Option D"],
      "correctIndex": 0
    }
  ]
}

GOOD EXAMPLE (for a science document about ecosystems):
{
  "quizzes": [
    {
      "_reasoning": "Testing producer concept. Correct answer is Producer (index 1). Distractors are other trophic levels.",
      "question": "Ano ang tawag sa organism na gumagawa ng sariling pagkain through photosynthesis?",
      "options": ["Consumer", "Producer", "Decomposer", "Predator"],
      "correctIndex": 1
    },
    {
      "_reasoning": "Testing abiotic factors - different category from trophic levels. Correct answer is Sunlight (index 1).",
      "question": "Alin sa mga ito ang example ng abiotic factor sa isang ecosystem?",
      "options": ["Damo (grass)", "Sunlight", "Bacteria", "Insekto"],
      "correctIndex": 1
    },
    {
      "_reasoning": "Testing decomposer role - related to ecosystem but different concept. Varying correctIndex to 2.",
      "question": "Sa food chain, ano ang role ng mga decomposers?",
      "options": ["Kumakain ng ibang animals", "Gumagawa ng pagkain from sunlight", "Bine-break down ang dead organisms at ni-return ang nutrients sa soil", "Kumokontrol ng population ng prey"],
      "correctIndex": 2
    },
    {
      "_reasoning": "Testing symbiotic relationships - new category. Mutualism at index 2.",
      "question": "Ano ang tawag sa relationship kung saan parehong nag-benefit ang dalawang organisms?",
      "options": ["Parasitism", "Commensalism", "Mutualism", "Competition"],
      "correctIndex": 2
    }
  ]
}

BAD EXAMPLE (DO NOT generate like this):
{
  "quizzes": [
    {"question": "What is a producer?", "options": ["An organism that makes food", "An organism that eats food", "An organism that breaks down food", "None of the above"], "correctIndex": 0},
    {"question": "Which organism produces its own food?", "options": ["Consumer", "Producer", "Decomposer", "Scavenger"], "correctIndex": 1}
  ]
}
WHY THIS IS BAD: Pure English (not Taglish). Two questions about the same concept. correctIndex always 0 or 1 (vary it!). No "_reasoning" field.

REMINDER: Ang bawat question at options ay dapat TAGLISH — huwag kalimutan!

──────────────────────────────────
DOCUMENT TEXT:
$text
──────────────────────────────────
Generate the quiz JSON now. LAHAT ng content ay TAGLISH:''';
