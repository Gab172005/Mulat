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
