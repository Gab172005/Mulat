/// ─── DYNAMIC LANGUAGE-AWARE PROMPT BUILDER ──────────────────────────
/// Constructs strict System + User prompts for Ollama local models,
/// dynamically adapted to the user's chosen language preference.
///
/// OPTIMIZATION TECHNIQUES APPLIED:
/// • Language-Anchored System Prompts — language instructions are written
///   IN THE TARGET LANGUAGE to bias the model's attention context.
/// • Conditional Few-Shot Examples — each language gets its own good/bad
///   examples to ground small models (Llama 3.2 3B, Gemma 2 2B).
/// • Silent Chain-of-Thought — a `_reasoning` field gives the model
///   scratch space to plan each item. Stripped by SecureJsonParser.
/// • Negative Few-Shot — "BAD EXAMPLE" blocks teach what NOT to do.
/// • Mid-Prompt Reminders — language reinforcement placed between
///   instructions and document text to survive attention dilution.
/// • Cross-Language Transformation — explicit instructions for when
///   source document language ≠ target output language.
///
/// PROMPT TOKEN BUDGET (~2k–2.3k tokens depending on language):
///   System prompt:          ~200 tokens
///   Few-shot (1 language):  ~350 tokens
///   Scaffolding/reminder:   ~100 tokens
///   Input text (6k char):   ~1500 tokens
///   ─────────────────────────────────
///   TOTAL INPUT:            ~2150 tokens  (fits 4096 ctx with ~1900 for output)

import '../models/student_profile.dart';

/// Content generation modes.
enum ContentMode { reviewer, flashcards, quiz }

/// Returns a (systemPrompt, userPrompt) pair for Ollama.
/// [language] controls the output language of all generated content.
({String system, String user}) buildOllamaPrompt({
  required String extractedText,
  required ContentMode mode,
  required AppLanguage language,
}) {
  // ── Dynamic system instruction built from language directives ───────
  final systemPrompt = '''You are Kabalikat, a study content generator for Filipino students.
You MUST respond with ONLY valid JSON. No markdown fences. No explanations before or after the JSON.

${language.contentLanguageDirective}

${language.crossLanguageInstruction}

QUALITY RULES:
- Extract information ONLY from the provided document text. NEVER invent facts.
- NEVER use topics, concepts, or facts from the few-shot examples — those are format demonstrations only.
- Each item must cover a DIFFERENT concept. No rephrasing the same idea.
- Keep answers concise: 1-3 sentences per item.''';

  switch (mode) {
    case ContentMode.reviewer:
      return (
        system: systemPrompt,
        user: _buildReviewerPrompt(extractedText, language),
      );
    case ContentMode.flashcards:
      return (
        system: systemPrompt,
        user: _buildFlashcardsPrompt(extractedText, language),
      );
    case ContentMode.quiz:
      return (
        system: systemPrompt,
        user: _buildQuizPrompt(extractedText, language),
      );
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  CONDITIONALLY-ADAPTIVE FEW-SHOT EXAMPLES
// ═══════════════════════════════════════════════════════════════════════
// Small models (Llama 3.2 3B, Gemma 2 2B) fail language constraints
// without concrete examples. Each language gets its own good + bad
// examples so the model sees the exact style it must produce.

// ── REVIEWER FEW-SHOT EXAMPLES ───────────────────────────────────────

String _reviewerGoodExample(AppLanguage language) => switch (language) {
  AppLanguage.english => '''
{
  "reviewers": [
    {
      "_reasoning": "Starting with Cell Theory — the foundational concept. Writing in pure English.",
      "concept": "Cell Theory",
      "explanation": "All living things are made of cells. The cell is the basic unit of life. All cells come from pre-existing cells.",
      "example": "The human body contains trillions of cells, each with a specialized function."
    },
    {
      "_reasoning": "Next: Prokaryotic vs Eukaryotic — different structural concept. Pure English throughout.",
      "concept": "Prokaryotic vs Eukaryotic Cells",
      "explanation": "Prokaryotic cells, such as bacteria, lack a nucleus. Eukaryotic cells, like human cells, have a membrane-bound nucleus.",
      "example": "E. coli is a prokaryote, while our muscle cells are eukaryotes."
    }
  ]
}''',

  AppLanguage.filipino => '''
{
  "reviewers": [
    {
      "_reasoning": "Magsisimula sa Teorya ng Selula — ang pangunahing konsepto. Purong Filipino.",
      "concept": "Teorya ng Selula",
      "explanation": "Lahat ng nabubuhay ay gawa sa mga selula. Ang selula ang pangunahing yunit ng buhay. Lahat ng selula ay nagmula sa mga dating selula.",
      "example": "Ang katawan ng tao ay may trilyong mga selula na may kanya-kanyang tungkulin."
    },
    {
      "_reasoning": "Susunod: Prokaryotiko laban sa Eukaryotiko — ibang konsepto ng istruktura. Purong Filipino.",
      "concept": "Prokaryotiko laban sa Eukaryotikong Selula",
      "explanation": "Ang mga prokaryotikong selula, tulad ng bakterya, ay walang nukleo. Ang mga eukaryotikong selula, tulad ng mga selula ng tao, ay may nukleo.",
      "example": "Ang E. coli ay prokaryote, habang ang mga selula ng kalamnan natin ay eukaryote."
    }
  ]
}''',

  AppLanguage.taglish => '''
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
    }
  ]
}''',
};

String _reviewerBadExample(AppLanguage language) => switch (language) {
  AppLanguage.english => '''
{
  "reviewers": [
    {"concept": "Teorya ng Selula", "explanation": "Lahat ng nabubuhay ay gawa sa cells. Ang cell ang basic unit of life.", "example": "Ang human body ay may trillions of cells."},
    {"concept": "Cell Theory Principles", "explanation": "Cells are the fundamental unit of structure and function.", "example": "Every organism is composed of cells."}
  ]
}
WHY THIS IS BAD: First item uses Filipino words (violates Pure English rule). Two items about the same concept. No "_reasoning" field.''',

  AppLanguage.filipino => '''
{
  "reviewers": [
    {"concept": "Cell Theory", "explanation": "All living things are made of cells. The cell is the basic unit of life.", "example": "The human body has trillions of cells."},
    {"concept": "Cell Theory Principles", "explanation": "Cells are the fundamental unit.", "example": "Every organism is composed of cells."}
  ]
}
BAKIT ITO MALI: Pure English ang ginamit (labag sa Purong Filipino). Dalawang item tungkol sa iisang konsepto. Walang "_reasoning" field.''',

  AppLanguage.taglish => '''
{
  "reviewers": [
    {"concept": "Cell Theory", "explanation": "All living things are made of cells. The cell is the basic unit of life.", "example": "The human body has trillions of cells."},
    {"concept": "Cell Theory Principles", "explanation": "Cells are the fundamental unit of structure and function.", "example": "Every organism is composed of cells."}
  ]
}
WHY THIS IS BAD: Pure English (not Taglish). Two items about the same concept (Cell Theory). No "_reasoning" field.''',
};

// ── FLASHCARD FEW-SHOT EXAMPLES ──────────────────────────────────────

String _flashcardGoodExample(AppLanguage language) => switch (language) {
  AppLanguage.english => '''
{
  "flashcards": [
    {
      "_reasoning": "Covering the First Philippine Republic establishment. Pure English.",
      "front": "When was the First Philippine Republic established?",
      "back": "It was established on January 23, 1899, in Malolos, Bulacan. Emilio Aguinaldo became the first president."
    },
    {
      "_reasoning": "Moving to Cry of Pugad Lawin — different event.",
      "front": "What was the Cry of Pugad Lawin?",
      "back": "It was the event in August 1896 when Katipuneros tore their cedulas as a sign of revolt against Spain."
    },
    {
      "_reasoning": "Covering Andres Bonifacio — a person, different category.",
      "front": "Who was Andres Bonifacio and why is he important?",
      "back": "He was the founder of the Katipunan, the secret revolutionary society that led the uprising against the Spaniards."
    }
  ]
}''',

  AppLanguage.filipino => '''
{
  "flashcards": [
    {
      "_reasoning": "Tatalakayin ang pagtatatag ng Unang Republika ng Pilipinas. Purong Filipino.",
      "front": "Kailan itinatag ang Unang Republika ng Pilipinas?",
      "back": "Itinatag ito noong Enero 23, 1899, sa Malolos, Bulacan. Si Emilio Aguinaldo ang naging unang pangulo."
    },
    {
      "_reasoning": "Susunod: Sigaw ng Pugad Lawin — ibang pangyayari.",
      "front": "Ano ang Sigaw ng Pugad Lawin?",
      "back": "Ito ang pangyayari noong Agosto 1896 kung saan pinunit ng mga Katipunero ang kanilang mga sedula bilang tanda ng paghihimagsik laban sa Espanya."
    },
    {
      "_reasoning": "Tatalakayin si Andres Bonifacio — isang tao, ibang kategorya.",
      "front": "Sino si Andres Bonifacio at bakit siya mahalaga?",
      "back": "Siya ang tagapagtatag ng Katipunan, ang lihim na samahang rebolusyonaryo na namuno sa pag-aalsa laban sa mga Espanyol."
    }
  ]
}''',

  AppLanguage.taglish => '''
{
  "flashcards": [
    {
      "_reasoning": "Covering the First Philippine Republic establishment date. Using 'Kailan' question word.",
      "front": "Kailan na-establish ang First Philippine Republic?",
      "back": "January 23, 1899, sa Malolos, Bulacan. Si Emilio Aguinaldo ang naging first president."
    },
    {
      "_reasoning": "Moving to Cry of Pugad Lawin - different event. Using 'Ano ang' pattern.",
      "front": "Ano ang Cry of Pugad Lawin?",
      "back": "Ito ang event noong August 1896 kung saan pinunit ng mga Katipunero ang kanilang cedula bilang sign of revolt laban sa Spain."
    },
    {
      "_reasoning": "Covering Andres Bonifacio - a person, not an event. Using 'Sino' question word for variety.",
      "front": "Sino si Andres Bonifacio at bakit siya important?",
      "back": "Siya ang founder ng Katipunan, ang secret revolutionary society na nag-lead ng uprising laban sa mga Espanyol."
    }
  ]
}''',
};

String _flashcardBadExample(AppLanguage language) => switch (language) {
  AppLanguage.english => '''
{
  "flashcards": [
    {"front": "Kailan na-establish ang First Philippine Republic?", "back": "Ito ay itinatag noong January 23, 1899."},
    {"front": "When was the First Philippine Republic established?", "back": "It was established on January 23, 1899."}
  ]
}
WHY THIS IS BAD: First item uses Filipino (violates Pure English). Two cards about the same concept. No "_reasoning" field.''',

  AppLanguage.filipino => '''
{
  "flashcards": [
    {"front": "What is the First Philippine Republic?", "back": "It was the first republic in Asia, established in 1899."},
    {"front": "When was the First Philippine Republic established?", "back": "It was established on January 23, 1899."}
  ]
}
BAKIT ITO MALI: Pure English ang ginamit (labag sa Purong Filipino). Dalawang card tungkol sa iisang konsepto. Walang "_reasoning" field.''',

  AppLanguage.taglish => '''
{
  "flashcards": [
    {"front": "What is the First Philippine Republic?", "back": "It was the first republic in Asia, established in 1899."},
    {"front": "When was the First Philippine Republic established?", "back": "It was established on January 23, 1899."}
  ]
}
WHY THIS IS BAD: Pure English (not Taglish). Two cards about the same concept. No "_reasoning" field. Answers too vague.''',
};

// ── QUIZ FEW-SHOT EXAMPLES ───────────────────────────────────────────

String _quizGoodExample(AppLanguage language) => switch (language) {
  AppLanguage.english => '''
{
  "quizzes": [
    {
      "_reasoning": "Testing producer concept. Correct answer is Producer (index 1). All options in English.",
      "question": "What do you call an organism that produces its own food through photosynthesis?",
      "options": ["Consumer", "Producer", "Decomposer", "Predator"],
      "correctIndex": 1
    },
    {
      "_reasoning": "Testing abiotic factors — different category. Correct answer is Sunlight (index 1).",
      "question": "Which of the following is an example of an abiotic factor in an ecosystem?",
      "options": ["Grass", "Sunlight", "Bacteria", "Insects"],
      "correctIndex": 1
    },
    {
      "_reasoning": "Testing decomposer role — ecosystem concept. Varying correctIndex to 2.",
      "question": "In a food chain, what is the role of decomposers?",
      "options": ["They eat other animals", "They produce food from sunlight", "They break down dead organisms and return nutrients to the soil", "They control the population of prey"],
      "correctIndex": 2
    }
  ]
}''',

  AppLanguage.filipino => '''
{
  "quizzes": [
    {
      "_reasoning": "Sinusubok ang konsepto ng producer. Tamang sagot ay Prodyuser (index 1). Lahat ng opsyon ay Filipino.",
      "question": "Ano ang tawag sa organismo na gumagawa ng sarili niyang pagkain sa pamamagitan ng potosintesis?",
      "options": ["Konsyumer", "Prodyuser", "Decomposer", "Mandaragit"],
      "correctIndex": 1
    },
    {
      "_reasoning": "Sinusubok ang abiotic factors — ibang kategorya. Tamang sagot ay Sikat ng araw (index 1).",
      "question": "Alin sa mga sumusunod ang halimbawa ng abiotic factor sa isang ekosistema?",
      "options": ["Damo", "Sikat ng araw", "Bakterya", "Mga insekto"],
      "correctIndex": 1
    },
    {
      "_reasoning": "Sinusubok ang tungkulin ng decomposer — konsepto sa ekosistema. Iba-iba ang correctIndex, ngayon ay 2.",
      "question": "Sa food chain, ano ang tungkulin ng mga decomposer?",
      "options": ["Kumakain sila ng ibang hayop", "Gumagawa sila ng pagkain mula sa sikat ng araw", "Binubulok nila ang mga patay na organismo at ibinabalik ang sustansya sa lupa", "Kinokontrol nila ang populasyon ng mga nahahabol"],
      "correctIndex": 2
    }
  ]
}''',

  AppLanguage.taglish => '''
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
    }
  ]
}''',
};

String _quizBadExample(AppLanguage language) => switch (language) {
  AppLanguage.english => '''
{
  "quizzes": [
    {"question": "Ano ang tawag sa organism na gumagawa ng sariling pagkain?", "options": ["Consumer", "Producer", "Decomposer", "Scavenger"], "correctIndex": 0},
    {"question": "Which organism produces its own food?", "options": ["Consumer", "Producer", "Decomposer", "Scavenger"], "correctIndex": 1}
  ]
}
WHY THIS IS BAD: First question uses Filipino (violates Pure English). Two questions same concept. correctIndex always 0 or 1. No "_reasoning" field.''',

  AppLanguage.filipino => '''
{
  "quizzes": [
    {"question": "What is a producer?", "options": ["An organism that makes food", "An organism that eats food", "An organism that breaks down food", "None of the above"], "correctIndex": 0},
    {"question": "Which organism produces its own food?", "options": ["Consumer", "Producer", "Decomposer", "Scavenger"], "correctIndex": 1}
  ]
}
BAKIT ITO MALI: Pure English ang ginamit (labag sa Purong Filipino). Dalawang tanong tungkol sa iisang konsepto. Walang "_reasoning" field.''',

  AppLanguage.taglish => '''
{
  "quizzes": [
    {"question": "What is a producer?", "options": ["An organism that makes food", "An organism that eats food", "An organism that breaks down food", "None of the above"], "correctIndex": 0},
    {"question": "Which organism produces its own food?", "options": ["Consumer", "Producer", "Decomposer", "Scavenger"], "correctIndex": 1}
  ]
}
WHY THIS IS BAD: Pure English (not Taglish). Two questions about the same concept. correctIndex always 0 or 1 (vary it!). No "_reasoning" field.''',
};

// ═══════════════════════════════════════════════════════════════════════
//  REVIEWER PROMPT — Key Concepts Summary + Silent CoT
// ═══════════════════════════════════════════════════════════════════════
String _buildReviewerPrompt(String text, AppLanguage language) => '''
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
      "concept": "Concept title",
      "explanation": "Clear explanation",
      "example": "A concrete example"
    }
  ]
}

GOOD EXAMPLE (FORMAT ONLY — the topic above is NOT your topic):
${_reviewerGoodExample(language)}

BAD EXAMPLE (DO NOT generate like this):
${_reviewerBadExample(language)}

⚠️ CRITICAL: The examples above only demonstrate the JSON format. Do NOT generate content about Cell Theory, cells, prokaryotes, or any topic from the examples. Every concept you write MUST come ONLY from the DOCUMENT TEXT below.

${language.midPromptReminder}

──────────────────────────────────
DOCUMENT TEXT (your ONLY source — do NOT invent or use example topics):
$text
──────────────────────────────────
${language.generateNowAnchor}''';

// ═══════════════════════════════════════════════════════════════════════
//  FLASHCARDS PROMPT — Front/Back + Silent CoT
// ═══════════════════════════════════════════════════════════════════════
String _buildFlashcardsPrompt(String text, AppLanguage language) => '''
Generate flashcards from the document below.
Return ONLY valid JSON. Generate AT LEAST 10 flashcards.
Front = question. Back = answer.

Before writing each flashcard, use the "_reasoning" field to plan what
concept you will cover and confirm it is DIFFERENT from previous cards.
The "_reasoning" field is for your internal planning only and will be discarded.

FORMAT (follow EXACTLY):
{
  "flashcards": [
    {
      "_reasoning": "Planning note about which concept to cover",
      "front": "Question",
      "back": "Answer"
    }
  ]
}

GOOD EXAMPLE (FORMAT ONLY — the topic above is NOT your topic):
${_flashcardGoodExample(language)}

BAD EXAMPLE (DO NOT generate like this):
${_flashcardBadExample(language)}

⚠️ CRITICAL: The examples above only demonstrate the JSON format. Do NOT generate flashcards about the First Philippine Republic, Aguinaldo, Bonifacio, or any topic from the examples. Every flashcard MUST be based ONLY on the DOCUMENT TEXT below.

${language.midPromptReminder}

──────────────────────────────────
DOCUMENT TEXT (your ONLY source — do NOT invent or use example topics):
$text
──────────────────────────────────
${language.generateNowAnchor}''';

// ═══════════════════════════════════════════════════════════════════════
//  MICRO-QUIZ PROMPT — MCQ with Silent CoT
// ═══════════════════════════════════════════════════════════════════════
String _buildQuizPrompt(String text, AppLanguage language) => '''
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
      "question": "Question text",
      "options": ["Option A", "Option B", "Option C", "Option D"],
      "correctIndex": 0
    }
  ]
}

GOOD EXAMPLE (FORMAT ONLY — the topic above is NOT your topic):
${_quizGoodExample(language)}

BAD EXAMPLE (DO NOT generate like this):
${_quizBadExample(language)}

⚠️ CRITICAL: The examples above only demonstrate the JSON format. Do NOT generate questions about producers, consumers, decomposers, photosynthesis, food chains, ecosystems, or any topic from the examples. Every question MUST be based ONLY on the DOCUMENT TEXT below.

${language.midPromptReminder}

──────────────────────────────────
DOCUMENT TEXT (your ONLY source — do NOT invent or use example topics):
$text
──────────────────────────────────
${language.generateNowAnchor}''';
