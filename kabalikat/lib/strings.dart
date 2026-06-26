/// Lightweight UI localization. Two variants: English, and Filipino (also used
/// for Taglish). Build with `S(state.isFilipino)` inside a widget and read the
/// getters. Learning content is localized separately in the data model.
class S {
  final bool fil;
  const S(this.fil);

  String _p(String en, String fl) => fil ? fl : en;

  // ---- Onboarding ----
  String get tagline =>
      _p('Your AI study buddy — even with no signal.',
          'Iyong AI study buddy — kahit walang signal.');
  String get yourName => _p('Your name', 'Ano ang pangalan mo?');
  String get start => _p('Start', 'Simulan');
  String get defaultName => _p('Student', 'Estudyante');

  // ---- Navigation ----
  String get tabTutor => _p('Tutor', 'Tutor');
  String get tabPractice => _p('Practice', 'Praktis');
  String get tabProgress => _p('Progress', 'Progreso');
  String get tabSettings => _p('Settings', 'Setting');

  // ---- Connection banner ----
  String get bannerLive => _p('Online · Live AI tutor', 'Online · Buhay na AI tutor');
  String get bannerAddKey =>
      _p('Online · add API key for live AI', 'Online · magdagdag ng API key');
  String get bannerOffline =>
      _p('Offline · using cached lessons', 'Offline · gumagamit ng cached');

  // ---- Practice ----
  String get adaptivePractice => _p('Adaptive Practice', 'Adaptive na Praktis');
  String get practiceIntro => _p(
      'Questions get easier or harder based on how you answer. Works offline with cached items.',
      'Nagbabago ang hirap base sa iyong mga sagot. Gumagana offline gamit ang cached na tanong.');
  String get startPractice => _p('Start practice', 'Magsimula');
  String get nextQuestion => _p('Next question', 'Susunod na tanong');
  String get score => _p('Score', 'Iskor');
  String get level => _p('Level', 'Antas');
  String focus(String topic) => _p(
      'Focus: $topic — your lowest-mastery topic right now.',
      'Focus: $topic — ang pinakamababa mong mastery ngayon.');
  String correct() => _p('Correct! ✅', 'Tama! ✅');
  String wrong() => _p('Not quite — that’s okay!', 'Mali — okay lang!');
  String difficultyNote(String topic, int pct) => _p(
      'Difficulty adapts to your $topic mastery ($pct%).',
      'Umaangkop ang hirap base sa $topic mastery mo ($pct%).');

  // ---- Progress ----
  String hi(String name) => _p('Hi, $name 👋', 'Kumusta, $name 👋');
  String gradeLang(int grade, String lang) =>
      _p('Grade $grade · $lang', 'Baitang $grade · $lang');
  String get overallMastery => _p('Overall mastery', 'Kabuuang mastery');
  String get byTopic => _p('By topic', 'Ayon sa paksa');
  String get noPractice => _p(
      'No practice yet. Go to the Practice tab to start.',
      'Wala pang praktis. Pumunta sa Practice tab para magsimula.');

  // ---- Settings ----
  String get settings => _p('Settings', 'Mga Setting');
  String get language => _p('Language', 'Wika');
  String get gradeLevel => _p('Grade level', 'Baitang');
  String grade(int g) => _p('Grade $g', 'Baitang $g');
  String get demoOffline => _p('Demo: simulate offline', 'Demo: gayahin ang offline');
  String get demoOfflineSub => _p('Force cached mode without airplane mode',
      'Puwersahing cached mode nang walang airplane mode');
  String get onDeviceAI => _p('On-device AI (offline)', 'On-device AI (offline)');
  String get onDeviceNotWired => _p(
      'Real offline AI tutor (no signal needed). Not wired into this build yet — follow ON_DEVICE_MODEL.md to drop in the flutter_gemma engine, then download the model here.',
      'Tunay na offline AI tutor (walang signal kailangan). Hindi pa naka-aktibo sa build na ito — sundin ang ON_DEVICE_MODEL.md para ilagay ang flutter_gemma engine, tapos i-download ang modelo dito.');
  String get modelUnsupported => _p('This device can’t run the on-device model.',
      'Hindi kayang patakbuhin ng device ang on-device model.');
  String downloading(int pct) =>
      _p('Downloading… $pct%', 'Dina-download… $pct%');
  String get modelReady =>
      _p('Ready — works fully offline.', 'Handa na — gumagana nang offline.');
  String get remove => _p('Remove', 'Alisin');
  String get downloadModel => _p('Download model', 'I-download ang modelo');
  String get liveAiOptional => _p('Live AI (optional)', 'Live AI (opsyonal)');
  String get apiKeySaved => _p('API key saved — live AI active when online.',
      'Naka-save ang API key — aktibo ang live AI kapag online.');
  String get apiKeyNone => _p('No key set — app uses cached content only.',
      'Walang key — cached na nilalaman lang ang gamit.');
  String get pasteKey => _p('Paste API key', 'I-paste ang API key');
  String get saveKey => _p('Save key', 'I-save ang key');
  String get clear => _p('Clear', 'Burahin');
  String get keySavedSnack => _p('API key saved', 'Na-save ang API key');
}
