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
