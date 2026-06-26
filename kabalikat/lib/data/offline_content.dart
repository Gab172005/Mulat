import '../models/practice_question.dart';

/// Bundled, offline-first content. Ships inside the app so the tutor and
/// practice work with ZERO connectivity. When online, the AI service can
/// extend this on the fly; offline, these are the fallback.

/// Keyword -> bilingual explanation. Used by the offline tutor fallback.
const Map<String, Map<String, String>> kOfflineLessons = {
  'photosynthesis': {
    'en':
        'Photosynthesis is how plants make their own food. Using sunlight, water, and carbon dioxide, leaves produce glucose (sugar) and release oxygen. Formula: 6CO2 + 6H2O + light -> C6H12O6 + 6O2.',
    'fil':
        'Ang potosintesis ay ang paraan ng paggawa ng pagkain ng halaman. Gamit ang sikat ng araw, tubig, at carbon dioxide, gumagawa ang dahon ng glucose (asukal) at naglalabas ng oxygen.',
  },
  'fraction': {
    'en':
        'A fraction shows part of a whole, written as numerator/denominator. To add fractions, make the denominators equal first, then add the numerators. Example: 1/4 + 1/4 = 2/4 = 1/2.',
    'fil':
        'Ang praksyon ay bahagi ng kabuuan, isinusulat bilang numerator/denominator. Para magdagdag, gawing pareho muna ang denominator, tapos idagdag ang numerator. Halimbawa: 1/4 + 1/4 = 2/4 = 1/2.',
  },
  'verb': {
    'en':
        'A verb is an action or state-of-being word (run, think, is). Tense tells WHEN it happens: past, present, or future.',
    'fil':
        'Ang pandiwa (verb) ay salitang kilos o pamayagpag (tumakbo, mag-isip, ay). Ipinapakita ng panahunan kung KAILAN nangyari: nakaraan, kasalukuyan, o hinaharap.',
  },
  'newton': {
    'en':
        "Newton's First Law (inertia): an object stays at rest or in motion unless a force acts on it. That is why you lurch forward when a jeepney suddenly stops.",
    'fil':
        'Unang Batas ni Newton (inertia): nananatiling nakatigil o gumagalaw ang isang bagay hangga\'t walang puwersang kumikilos dito. Kaya ka napapasubsob kapag biglang huminto ang jeep.',
  },
  'water cycle': {
    'en':
        'The water cycle: evaporation (water rises as vapor), condensation (clouds form), precipitation (rain/snow falls), and collection (back to rivers and seas).',
    'fil':
        'Ang siklo ng tubig: pagsingaw (umaakyat ang tubig), pagbuo ng ulap, pag-ulan, at pagbalik sa ilog at dagat.',
  },
};

/// Subjects the adaptive practice rotates through.
const List<String> kPracticeTopics = ['Math', 'Science', 'English'];

/// Offline practice bank. Every topic has items at difficulty 1, 2, and 3,
/// so the adaptive engine can always find a question at the right level for
/// the student's weakest topic. When online, the AI generates fresh items.
const List<PracticeQuestion> kOfflineQuestions = [
  // ============================ MATH ============================
  PracticeQuestion(
    topic: 'Math',
    difficulty: 1,
    prompt: 'What is 1/2 + 1/2?',
    promptFil: 'Ano ang 1/2 + 1/2?',
    choices: ['1/4', '1', '2/4', '0'],
    answerIndex: 1,
    explanation: 'Equal denominators: 1/2 + 1/2 = 2/2 = 1.',
    explanationFil: 'Magkapareho ang denominator: 1/2 + 1/2 = 2/2 = 1.',
  ),
  PracticeQuestion(
    topic: 'Math',
    difficulty: 1,
    prompt: 'What is 6 × 7?',
    promptFil: 'Ano ang 6 × 7?',
    choices: ['42', '36', '48', '13'],
    answerIndex: 0,
    explanation: '6 groups of 7 = 42.',
    explanationFil: '6 na grupo ng 7 = 42.',
  ),
  PracticeQuestion(
    topic: 'Math',
    difficulty: 2,
    prompt: 'What is 3/4 + 1/8?',
    promptFil: 'Ano ang 3/4 + 1/8?',
    choices: ['4/12', '7/8', '4/8', '1/2'],
    answerIndex: 1,
    explanation: '3/4 = 6/8, so 6/8 + 1/8 = 7/8.',
    explanationFil: '3/4 = 6/8, kaya 6/8 + 1/8 = 7/8.',
  ),
  PracticeQuestion(
    topic: 'Math',
    difficulty: 2,
    prompt: 'Solve for x: 2x + 4 = 10',
    promptFil: 'Hanapin ang x: 2x + 4 = 10',
    choices: ['2', '3', '4', '7'],
    answerIndex: 1,
    explanation: '2x = 6, so x = 3.',
    explanationFil: '2x = 6, kaya x = 3.',
  ),
  PracticeQuestion(
    topic: 'Math',
    difficulty: 3,
    prompt: 'If x = 3, what is 2x² - 5x + 1?',
    promptFil: 'Kung x = 3, ano ang 2x² - 5x + 1?',
    choices: ['4', '7', '10', '13'],
    answerIndex: 0,
    explanation: '2(9) - 15 + 1 = 18 - 15 + 1 = 4.',
    explanationFil: '2(9) - 15 + 1 = 18 - 15 + 1 = 4.',
  ),
  PracticeQuestion(
    topic: 'Math',
    difficulty: 3,
    prompt: 'What is 15% of 200?',
    promptFil: 'Ano ang 15% ng 200?',
    choices: ['15', '30', '45', '20'],
    answerIndex: 1,
    explanation: '15% = 0.15; 0.15 × 200 = 30.',
    explanationFil: '15% = 0.15; 0.15 × 200 = 30.',
  ),

  // ============================ SCIENCE ============================
  PracticeQuestion(
    topic: 'Science',
    difficulty: 1,
    prompt: 'Which gas do plants release during photosynthesis?',
    promptFil: 'Anong gas ang inilalabas ng halaman sa potosintesis?',
    choices: ['Carbon dioxide', 'Oxygen', 'Nitrogen', 'Hydrogen'],
    answerIndex: 1,
    explanation: 'Plants take in CO2 and release oxygen.',
    explanationFil: 'Sumisipsip ng CO2 ang halaman at naglalabas ng oxygen.',
  ),
  PracticeQuestion(
    topic: 'Science',
    difficulty: 1,
    prompt: 'What is H₂O commonly known as?',
    promptFil: 'Ano ang karaniwang tawag sa H₂O?',
    choices: ['Salt', 'Water', 'Air', 'Sugar'],
    choicesFil: ['Asin', 'Tubig', 'Hangin', 'Asukal'],
    answerIndex: 1,
    explanation: 'H₂O is the chemical formula for water.',
    explanationFil: 'Ang H₂O ay ang pormula ng tubig.',
  ),
  PracticeQuestion(
    topic: 'Science',
    difficulty: 2,
    prompt: 'A jeepney stops suddenly and you lurch forward. This is due to?',
    promptFil: 'Biglang huminto ang jeep at napasubsob ka. Dahil ito sa?',
    choices: ['Gravity', 'Inertia', 'Friction', 'Magnetism'],
    choicesFil: ['Grabidad', 'Inertia', 'Friksyon', 'Magnetismo'],
    answerIndex: 1,
    explanation: "Inertia (Newton's First Law) keeps you moving forward.",
    explanationFil:
        'Ang inertia (Unang Batas ni Newton) ang dahilan ng pagpapatuloy mo sa paggalaw.',
  ),
  PracticeQuestion(
    topic: 'Science',
    difficulty: 2,
    prompt: 'Which part of a plant absorbs water from the soil?',
    promptFil: 'Aling bahagi ng halaman ang sumisipsip ng tubig mula sa lupa?',
    choices: ['Leaves', 'Roots', 'Flower', 'Stem'],
    choicesFil: ['Dahon', 'Ugat', 'Bulaklak', 'Tangkay'],
    answerIndex: 1,
    explanation: 'Roots absorb water and nutrients from the soil.',
    explanationFil: 'Ang ugat ang sumisipsip ng tubig at sustansya sa lupa.',
  ),
  PracticeQuestion(
    topic: 'Science',
    difficulty: 3,
    prompt:
        'In the water cycle, what process turns vapor back into liquid clouds?',
    promptFil:
        'Sa siklo ng tubig, anong proseso ang nagpapabalik ng singaw sa likidong ulap?',
    choices: ['Evaporation', 'Condensation', 'Precipitation', 'Collection'],
    choicesFil: ['Pagsingaw', 'Pagbuo ng ulap', 'Pag-ulan', 'Pag-ipon'],
    answerIndex: 1,
    explanation: 'Condensation cools vapor into cloud droplets.',
    explanationFil:
        'Pinapalamig ng condensation ang singaw paging maliliit na patak ng ulap.',
  ),
  PracticeQuestion(
    topic: 'Science',
    difficulty: 3,
    prompt: 'Which part of the cell produces most of its energy?',
    promptFil: 'Aling bahagi ng selula ang gumagawa ng halos lahat ng enerhiya nito?',
    choices: ['Nucleus', 'Mitochondria', 'Cell wall', 'Vacuole'],
    answerIndex: 1,
    explanation: 'The mitochondria are the powerhouse of the cell.',
    explanationFil: 'Ang mitochondria ang "powerhouse" o pinagkukunan ng enerhiya ng selula.',
  ),

  // ============================ ENGLISH ============================
  PracticeQuestion(
    topic: 'English',
    difficulty: 1,
    prompt: 'Which word is a verb? "The cat sleeps."',
    promptFil: 'Aling salita ang pandiwa? "The cat sleeps."',
    choices: ['The', 'cat', 'sleeps', 'none'],
    answerIndex: 2,
    explanation: '"Sleeps" is the action word (verb).',
    explanationFil: 'Ang "sleeps" ang salitang kilos (pandiwa).',
  ),
  PracticeQuestion(
    topic: 'English',
    difficulty: 1,
    prompt: 'Which of these is a noun?',
    promptFil: 'Alin sa mga ito ang pangngalan (noun)?',
    choices: ['run', 'dog', 'quickly', 'blue'],
    answerIndex: 1,
    explanation: 'A noun names a person, place, or thing — "dog".',
    explanationFil: 'Ang pangngalan ay tao, lugar, o bagay — "dog".',
  ),
  PracticeQuestion(
    topic: 'English',
    difficulty: 2,
    prompt: 'What is the past tense of "go"?',
    promptFil: 'Ano ang past tense ng "go"?',
    choices: ['goed', 'gone', 'went', 'going'],
    answerIndex: 2,
    explanation: '"Go" is irregular; its past tense is "went".',
    explanationFil: 'Iregular ang "go"; ang past tense nito ay "went".',
  ),
  PracticeQuestion(
    topic: 'English',
    difficulty: 2,
    prompt: 'Choose the correct word: "She ___ to school every day."',
    promptFil: 'Piliin ang tamang salita: "She ___ to school every day."',
    choices: ['go', 'goes', 'going', 'gone'],
    answerIndex: 1,
    explanation: 'Third-person singular takes "goes".',
    explanationFil: 'Sa third-person singular, ginagamit ang "goes".',
  ),
  PracticeQuestion(
    topic: 'English',
    difficulty: 3,
    prompt: 'Which word is a synonym of "happy"?',
    promptFil: 'Aling salita ang kasingkahulugan ng "happy"?',
    choices: ['sad', 'glad', 'angry', 'tired'],
    answerIndex: 1,
    explanation: '"Glad" means the same as "happy".',
    explanationFil: 'Ang "glad" ay kapareho ng kahulugan ng "happy".',
  ),
  PracticeQuestion(
    topic: 'English',
    difficulty: 3,
    prompt: 'Identify the adjective: "The tall building is new."',
    promptFil: 'Tukuyin ang pang-uri (adjective): "The tall building is new."',
    choices: ['building', 'tall', 'is', 'the'],
    answerIndex: 1,
    explanation: '"Tall" describes the noun "building", so it is an adjective.',
    explanationFil:
        'Inilalarawan ng "tall" ang pangngalang "building", kaya ito ay pang-uri.',
  ),
];
