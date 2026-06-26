enum AppLanguage { filipino, english, taglish }

extension AppLanguageX on AppLanguage {
  String get label {
    switch (this) {
      case AppLanguage.filipino:
        return 'Filipino';
      case AppLanguage.english:
        return 'English';
      case AppLanguage.taglish:
        return 'Taglish';
    }
  }

  // Instruction injected into the AI prompt so replies match the learner.
  String get promptHint {
    switch (this) {
      case AppLanguage.filipino:
        return 'Reply in clear, simple Filipino (Tagalog).';
      case AppLanguage.english:
        return 'Reply in clear, simple English.';
      case AppLanguage.taglish:
        return 'Reply in friendly Taglish (mixed Filipino and English), the way a Filipino tutor speaks.';
    }
  }

  // ── CONTENT GENERATION LANGUAGE DIRECTIVES ─────────────────────────
  // These provide strict guardrails for AI-generated study content
  // (flashcards, quizzes, reviewers). Much stronger than promptHint.

  /// Full system-level language instruction block for content generation.
  /// Includes strict guardrails to prevent language leaking.
  String get contentLanguageDirective => switch (this) {
    AppLanguage.english => '''LANGUAGE RULE: Write ALL content in PURE ENGLISH.
Every word must be English. Do NOT use any Filipino/Tagalog words, phrases, or sentence structures.
If a concept has a Filipino-specific cultural context, explain it entirely in English.
FORBIDDEN: Any Tagalog words like "ang", "ng", "sa", "mga", "at", "ito", "para", "siya", "naman", "po", etc.
SELF-CHECK: Before outputting, verify every single word is English.''',

    AppLanguage.filipino => '''LANGUAGE RULE: Isulat ang LAHAT ng content sa PURONG FILIPINO.
Gamitin ang Filipino/Tagalog sa bawat salita. HUWAG gumamit ng English.
Kung may technical term, gamitin ang Filipino na katumbas kung mayroon:
  - "photosynthesis" → "potosintesis"
  - "cell" → "selula"
  - "equation" → "ekwasyon"
  - "fraction" → "praksyon"
  - "example" → "halimbawa"
  - "process" → "proseso"
Kung WALANG Filipino equivalent (hal. DNA, pH, WiFi), saka lang pahintulutang gamitin ang English term.
IPINAGBABAWAL: English sentence structures, English conjunctions (and, but, or, because, etc.).
Gamitin: "at", "pero", "o", "dahil", "kaya", "kung", "habang", etc.
SURIIN: Bago mag-output, tiyakin na bawat salita ay Filipino maliban sa technical terms na walang katumbas.''',

    AppLanguage.taglish => '''LANGUAGE RULE: Write ALL content in TAGLISH.
Taglish = Filipino sentence structure + English technical terms.
HINDI pure English. HINDI pure Filipino.
Mag-Taglish ka PALAGI sa bawat item — huwag kalimutan!''',
  };

  /// Mid-prompt reminder in the target language (fights attention decay
  /// in small models where early instructions get diluted by document text).
  String get midPromptReminder => switch (this) {
    AppLanguage.english =>
      'REMINDER: ALL content must be in PURE ENGLISH — no Filipino words.',
    AppLanguage.filipino =>
      'PAALALA: LAHAT ng content ay dapat PURONG FILIPINO — walang English maliban sa technical terms na walang katumbas.',
    AppLanguage.taglish =>
      'REMINDER: Ang bawat item ay dapat TAGLISH — huwag kalimutan!',
  };

  // ── CHAT SYSTEM PROMPTS ────────────────────────────────────────────
  // Used by ChatController. Much more aggressive than promptHint because
  // chat history frequently contains Filipino student text that causes
  // small models to anchor to the wrong language.

  /// Authoritative system prompt for the chat controller. Names the
  /// forbidden language explicitly and survives contaminated history.
  String get chatSystemPrompt => switch (this) {
    AppLanguage.english =>
      'You are Kabalikat, a native English academic tutor. '
      'Your thoughts, reasoning, and ALL outputs are strictly constrained to the English language. '
      'CRITICAL DIRECTIVE: Your active language setting is PURE ENGLISH. '
      'You MUST respond 100% in grammatically correct English. '
      'ABSOLUTELY DO NOT use Tagalog, Filipino, or Taglish words or expressions '
      '(such as "ano", "ba", "na", "mga", "po", "naman", "kaya", "pero", "siya", "ito", '
      '"ang", "ng", "sa", "at", "hindi", "pwede", etc.) '
      'even if the chat history or student question is written in Filipino. '
      'If the student writes in Filipino, UNDERSTAND their message but reply ENTIRELY in English.',

    AppLanguage.filipino =>
      'Ikaw si Kabalikat, isang akademikong guro na Filipino. '
      'Ang iyong mga kaisipan, pag-iisip, at LAHAT ng output ay strictly PURONG FILIPINO. '
      'MAHALAGANG DIREKTIBA: Ang iyong aktibong setting ng wika ay PURONG FILIPINO. '
      'DAPAT kang sumagot ng 100% sa wastong Filipino. '
      'HUWAG KAILANMAN gumamit ng English na salita, parirala, o istruktura ng pangungusap '
      'kahit na ang kasaysayan ng chat o tanong ng estudyante ay nasa English. '
      'Kung ang estudyante ay sumusulat sa English, INTINDIHIN ang mensahe '
      'ngunit sumagot ng GANAP sa Filipino.',

    AppLanguage.taglish =>
      'You are Kabalikat, a friendly Filipino academic tutor who naturally speaks Taglish. '
      'Respond in friendly Taglish (mixed Filipino and English), the way a Filipino tutor speaks naturally. '
      'Use Filipino sentence structure with English technical terms. '
      'This is NOT pure English and NOT pure Filipino — it is natural Filipino code-switching.',
  };

  /// Short inline language lock tag appended to the last user message to
  /// exploit recency bias in both Gemini and Ollama attention.
  String get languageLockTag => switch (this) {
    AppLanguage.english => 'RESPOND IN PURE ENGLISH ONLY.',
    AppLanguage.filipino => 'SUMAGOT SA PURONG FILIPINO LAMANG.',
    AppLanguage.taglish => 'SUMAGOT SA TAGLISH.',
  };

  /// System instruction for Gemini SDK's authoritative system role when
  /// generating structured study content (flashcards, quizzes, reviewer).
  String get contentGenerationSystemPrompt => switch (this) {
    AppLanguage.english =>
      'You are an expert study content generator for Filipino students. '
      'Your active language setting is PURE ENGLISH. '
      'ALL content you produce — every word, every phrase, every sentence — '
      'MUST be in grammatically correct English. '
      'DO NOT use Tagalog, Filipino, or Taglish words under any circumstances, '
      'even if the source document is written in Filipino. '
      'When the source is in Filipino, TRANSLATE all concepts to English in your output.',

    AppLanguage.filipino =>
      'Ikaw ay isang dalubhasang tagagawa ng pang-aaral na nilalaman para sa mga estudyanteng Pilipino. '
      'Ang iyong aktibong setting ng wika ay PURONG FILIPINO. '
      'LAHAT ng nilalaman na iyong ginagawa — bawat salita, bawat parirala, bawat pangungusap — '
      'DAPAT ay sa wastong Filipino/Tagalog. '
      'HUWAG gumamit ng English maliban sa mga teknikal na termino na walang Filipino na katumbas.',

    AppLanguage.taglish =>
      'You are an expert study content generator for Filipino students. '
      'Your active language setting is TAGLISH. '
      'Generate all content in natural Taglish: Filipino sentence structure with English technical terms. '
      'This is NOT pure English and NOT pure Filipino.',
  };

  /// End-of-prompt anchor in the target language. Placed right before
  /// generation starts to prime the model's first output tokens.
  String get generateNowAnchor => switch (this) {
    AppLanguage.english =>
      'Generate the JSON now. ALL content must be in PURE ENGLISH:',
    AppLanguage.filipino =>
      'I-generate ang JSON ngayon. LAHAT ng content ay PURONG FILIPINO:',
    AppLanguage.taglish =>
      'Generate the JSON now. LAHAT ng content ay TAGLISH:',
  };

  /// Cross-language transformation instruction. Injected when the source
  /// document may be in a different language than the target output.
  String get crossLanguageInstruction => switch (this) {
    AppLanguage.english => '''SOURCE-TO-TARGET RULE: The source document may be in Filipino, Taglish, or another language.
You MUST: (1) UNDERSTAND the content regardless of its language.
(2) GENERATE all output in PURE ENGLISH only.
(3) TRANSLATE and ADAPT — do NOT copy Filipino phrases from the source.''',

    AppLanguage.filipino => '''PATAKARAN SA PAGSASALIN: Ang source document ay maaaring nasa English, Taglish, o ibang wika.
DAPAT MONG: (1) INTINDIHIN ang content anuman ang wika nito.
(2) I-GENERATE ang lahat ng output sa PURONG FILIPINO lamang.
(3) ISALIN at I-ADAPT — HUWAG kopyahin ang English phrases mula sa source.''',

    AppLanguage.taglish => '''SOURCE-TO-TARGET RULE: Ang source document ay pwedeng nasa kahit anong language.
You MUST: (1) UNDERSTAND the content regardless of its language.
(2) GENERATE all output in TAGLISH.
(3) Adapt the content — use Filipino sentence framing with English technical terms.''',
  };
}

class StudentProfile {
  bool onboarded;
  String name;
  int grade; // 1-12
  AppLanguage language;

  StudentProfile({
    this.onboarded = false,
    this.name = '',
    this.grade = 7,
    this.language = AppLanguage.taglish,
  });

  Map<String, dynamic> toJson() => {
        'onboarded': onboarded,
        'name': name,
        'grade': grade,
        'language': language.index,
      };

  factory StudentProfile.fromJson(Map<String, dynamic> j) => StudentProfile(
        onboarded: j['onboarded'] ?? false,
        name: j['name'] ?? '',
        grade: j['grade'] ?? 7,
        language: AppLanguage.values[j['language'] ?? AppLanguage.taglish.index],
      );
}
