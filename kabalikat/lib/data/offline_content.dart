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

/// Offline practice bank, grouped by difficulty. Topics are general so the
/// app works for "any subject". When online the AI generates fresh items.
const List<PracticeQuestion> kOfflineQuestions = [
  // ---- Difficulty 1 ----
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
    topic: 'English',
    difficulty: 1,
    prompt: 'Which word is a verb? "The cat sleeps."',
    promptFil: 'Aling salita ang pandiwa? "The cat sleeps."',
    choices: ['The', 'cat', 'sleeps', 'none'],
    answerIndex: 2,
    explanation: '"Sleeps" is the action word (verb).',
    explanationFil: 'Ang "sleeps" ang salitang kilos (pandiwa).',
  ),
  // ---- Difficulty 2 ----
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
    topic: 'Science',
    difficulty: 2,
    prompt: 'A jeepney stops suddenly and you lurch forward. This is due to?',
    promptFil:
        'Biglang huminto ang jeep at napasubsob ka. Dahil ito sa?',
    choices: ['Gravity', 'Inertia', 'Friction', 'Magnetism'],
    answerIndex: 1,
    explanation: "Inertia (Newton's First Law) keeps you moving forward.",
    explanationFil:
        'Ang inertia (Unang Batas ni Newton) ang dahilan ng pagpapatuloy mo sa paggalaw.',
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
  // ---- Difficulty 3 ----
  PracticeQuestion(
    topic: 'Math',
    difficulty: 3,
    prompt: 'If x = 3, what is 2x^2 - 5x + 1?',
    promptFil: 'Kung x = 3, ano ang 2x^2 - 5x + 1?',
    choices: ['4', '7', '10', '13'],
    answerIndex: 0,
    explanation: '2(9) - 15 + 1 = 18 - 15 + 1 = 4.',
    explanationFil: '2(9) - 15 + 1 = 18 - 15 + 1 = 4.',
  ),
  PracticeQuestion(
    topic: 'Science',
    difficulty: 3,
    prompt:
        'In the water cycle, what process turns vapor back into liquid clouds?',
    promptFil:
        'Sa siklo ng tubig, anong proseso ang nagpapabalik ng singaw sa likidong ulap?',
    choices: ['Evaporation', 'Condensation', 'Precipitation', 'Collection'],
    answerIndex: 1,
    explanation: 'Condensation cools vapor into cloud droplets.',
    explanationFil:
        'Pinapalamig ng condensation ang singaw paging maliliit na patak ng ulap.',
  ),
];
