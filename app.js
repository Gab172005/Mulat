/*
  GabayAI - Core Application Logic
  Integrates PDF extraction, local Hugging Face Transformers.js models,
  and state management for offline study modes.
*/

import { pipeline, env } from 'https://cdn.jsdelivr.net/npm/@huggingface/transformers@3.3.3';
import * as pdfjsLib from 'https://unpkg.com/pdfjs-dist@4.3.136/build/pdf.min.mjs';

// Configure PDF.js Worker path to load from CDN
pdfjsLib.GlobalWorkerOptions.workerSrc = 'https://unpkg.com/pdfjs-dist@4.3.136/build/pdf.worker.min.mjs';

// Configure Transformers.js to allow remote downloads and locate WASM resources
env.allowLocalModels = false;
env.backends.onnx.wasm.wasmPaths = 'https://cdn.jsdelivr.net/npm/@huggingface/transformers@3.3.3/dist/';

// --- State Architecture ---
const state = {
  isOnline: navigator.onLine,
  demoMode: true, // Default to demo mode for quick instant testing
  modelDownloaded: false,
  modelDownloading: false,
  modelProgress: 0,
  activeTab: 'flashcards', // 'flashcards' | 'quiz'

  // Wizard state
  wizardStep: 1, // 1 | 2
  selectedSource: null, // 'pdf' | 'notes' | 'ppt' | 'youtube' | 'photo' | 'web'
  showMoreActive: false,

  // Study material
  extractedText: '',
  selectedLanguage: 'taglish',
  studyDeck: null, // Holds { flashcards: [...], quiz: [...] }

  // Flashcard View State
  currentCardIndex: 0,
  cardFlipped: false,

  // Quiz View State
  currentQuizIndex: 0,
  quizSelectedOption: null, // Selected index
  quizAnswers: [], // User answers
  quizScore: 0,
  quizCompleted: false
};

// Local LLM Pipeline Variable
let generator = null;
const fileProgresses = {};

// --- Service Worker Registration ---
if ('serviceWorker' in navigator) {
  window.addEventListener('load', () => {
    navigator.serviceWorker.register('/sw.js')
      .then(reg => console.log('[GabayAI] Service Worker registered:', reg.scope))
      .catch(err => console.error('[GabayAI] Service Worker registration failed:', err));
  });
}

// --- DOM References ---
const offlineBanner = document.getElementById('offline-banner');
const offlineBannerText = document.getElementById('offline-banner-text');
const engineStatusBadge = document.getElementById('engine-status-badge');

// Wizard Elements
const wizardContainer = document.getElementById('wizard-container');
const wizardProgressFill = document.getElementById('wizard-progress-fill');
const wizardBackBtn = document.getElementById('wizard-back-btn');
const wizardStep1 = document.getElementById('wizard-step-1');
const wizardStep2 = document.getElementById('wizard-step-2');
const wizardStep2Title = document.getElementById('wizard-step-2-title');
const showMoreToggleBtn = document.getElementById('show-more-toggle-btn');
const showMoreIcon = document.getElementById('show-more-icon');
const showMorePanel = document.getElementById('show-more-panel');
const btnDemoNoMaterial = document.getElementById('btn-demo-no-material');

// Step 2 Input Group Elements
const inputGroupFile = document.getElementById('input-group-file');
const inputGroupNotes = document.getElementById('input-group-notes');
const inputGroupYoutube = document.getElementById('input-group-youtube');
const inputGroupPhoto = document.getElementById('input-group-photo');
const inputGroupWeb = document.getElementById('input-group-web');

// Specific Inputs
const dropzone = document.getElementById('dropzone');
const fileInput = document.getElementById('file-input');
const fileInfo = document.getElementById('file-info');
const fileNameText = document.getElementById('file-name');
const fileSizeText = document.getElementById('file-size');
const removeFileBtn = document.getElementById('remove-file-btn');
const textInput = document.getElementById('text-input');
const charCounter = document.getElementById('char-counter');
const youtubeUrlInput = document.getElementById('youtube-url-input');
const photoDropzone = document.getElementById('photo-dropzone');
const photoFileInput = document.getElementById('photo-file-input');
const photoInfo = document.getElementById('photo-info');
const photoFileName = document.getElementById('photo-file-name');
const photoFileSize = document.getElementById('photo-file-size');
const removePhotoBtn = document.getElementById('remove-photo-btn');
const webUrlInput = document.getElementById('web-url-input');

const languageSelect = document.getElementById('language-select');
const generateBtn = document.getElementById('generate-btn');
const noDeckPlaceholder = document.getElementById('no-deck-placeholder');
const generatingLoader = document.getElementById('generating-loader');
const studyDeckSection = document.getElementById('study-deck-section');

// Tabs
const tabFlashcardsBtn = document.getElementById('tab-flashcards-btn');
const tabQuizBtn = document.getElementById('tab-quiz-btn');
const tabFlashcardsView = document.getElementById('tab-flashcards-view');
const tabQuizView = document.getElementById('tab-quiz-view');

// Flashcard DOM Elements
const flashcardContainer = document.getElementById('flashcard-container');
const flashcardInner = document.getElementById('flashcard-inner');
const cardConceptText = document.getElementById('card-concept-text');
const cardDefinitionText = document.getElementById('card-definition-text');
const prevCardBtn = document.getElementById('prev-card-btn');
const nextCardBtn = document.getElementById('next-card-btn');
const flashcardProgressText = document.getElementById('flashcard-progress-text');
const flashcardProgressBar = document.getElementById('flashcard-progress-bar');

// Quiz DOM Elements
const quizQuestionCard = document.getElementById('quiz-question-card');
const quizResultsCard = document.getElementById('quiz-results-card');
const quizQuestionText = document.getElementById('quiz-question-text');
const quizOptionsContainer = document.getElementById('quiz-options-container');
const quizFeedbackBox = document.getElementById('quiz-feedback-box');
const quizFeedbackTitle = document.getElementById('quiz-feedback-title');
const quizExplanationText = document.getElementById('quiz-explanation-text');
const quizSubmitBtn = document.getElementById('quiz-submit-btn');
const quizProgressText = document.getElementById('quiz-progress-text');
const quizFinalScore = document.getElementById('quiz-final-score');
const quizPercentageText = document.getElementById('quiz-percentage-text');
const quizRestartBtn = document.getElementById('quiz-restart-btn');
const darkModeBtn = document.getElementById('dark-mode-btn');
const sunIcon = document.getElementById('sun-icon');
const moonIcon = document.getElementById('moon-icon');

// --- Initialization ---
document.addEventListener('DOMContentLoaded', () => {
  updateOnlineStatus();
  initTheme();
  setupEventListeners();
  renderState();
});

// --- Theme (Dark Mode) Setup ---
function initTheme() {
  if (localStorage.theme === 'dark' || (!('theme' in localStorage) && window.matchMedia('(prefers-color-scheme: dark)').matches)) {
    document.documentElement.classList.add('dark');
    sunIcon.classList.remove('hidden');
    moonIcon.classList.add('hidden');
  } else {
    document.documentElement.classList.remove('dark');
    sunIcon.classList.add('hidden');
    moonIcon.classList.remove('hidden');
  }
}

function toggleTheme() {
  if (document.documentElement.classList.contains('dark')) {
    document.documentElement.classList.remove('dark');
    localStorage.theme = 'light';
    sunIcon.classList.add('hidden');
    moonIcon.classList.remove('hidden');
  } else {
    document.documentElement.classList.add('dark');
    localStorage.theme = 'dark';
    sunIcon.classList.remove('hidden');
    moonIcon.classList.add('hidden');
  }
}

// --- Status & State Render Loop ---
function updateOnlineStatus() {
  state.isOnline = navigator.onLine;
  if (state.isOnline) {
    offlineBanner.className = 'w-full bg-emerald-600 text-white text-xs font-semibold py-1.5 px-4 text-center flex items-center justify-center gap-2 transition-all duration-300 transform translate-y-0';
    offlineBannerText.textContent = 'Konektado: Online Mode';
    offlineBanner.classList.remove('glow-active-red');
    offlineBanner.classList.add('glow-active-green');
  } else {
    offlineBanner.className = 'w-full bg-amber-600 text-white text-xs font-semibold py-1.5 px-4 text-center flex items-center justify-center gap-2 transition-all duration-300 transform translate-y-0';
    offlineBannerText.textContent = 'Offline Mode - Gumagana mula sa Local Cache';
    offlineBanner.classList.remove('glow-active-green');
    offlineBanner.classList.add('glow-active-red');
  }
}
window.addEventListener('online', updateOnlineStatus);
window.addEventListener('offline', updateOnlineStatus);

// Main rendering synchronizer
function renderState() {
  // 1. Model Engine Status Badge Update
  if (state.demoMode) {
    engineStatusBadge.className = 'px-2.5 py-0.5 rounded-full text-[10px] font-semibold bg-amber-50 text-amber-700 border border-amber-200 dark:bg-amber-950/20 dark:text-amber-300 dark:border-amber-900 flex items-center gap-1.5';
    engineStatusBadge.innerHTML = '<span class="w-1.5 h-1.5 rounded-full bg-amber-500 animate-pulse"></span> Mode: Mock AI';
  } else if (state.modelDownloaded) {
    engineStatusBadge.className = 'px-2.5 py-0.5 rounded-full text-[10px] font-semibold bg-emerald-50 text-emerald-700 border border-emerald-200 dark:bg-emerald-950/20 dark:text-emerald-300 dark:border-emerald-900 flex items-center gap-1.5';
    engineStatusBadge.innerHTML = '<span class="w-1.5 h-1.5 rounded-full bg-emerald-500"></span> AI: Loaded (GPU)';
  } else {
    engineStatusBadge.className = 'px-2.5 py-0.5 rounded-full text-[10px] font-semibold bg-[var(--btn-bg)] text-[var(--text-default)] border border-[var(--border-default)] flex items-center gap-1.5';
    engineStatusBadge.innerHTML = '<span class="w-1.5 h-1.5 rounded-full bg-slate-400"></span> AI: Unloaded';
  }

  // 2. Render Generation Button State based on Wizard selected input source content
  let hasContent = false;
  if (state.selectedSource === 'pdf' || state.selectedSource === 'ppt' || state.selectedSource === 'photo') {
    hasContent = state.extractedText.trim().length > 0;
  } else if (state.selectedSource === 'notes') {
    hasContent = state.extractedText.trim().length > 0;
  } else if (state.selectedSource === 'youtube') {
    hasContent = youtubeUrlInput.value.trim().length > 0;
  } else if (state.selectedSource === 'web') {
    hasContent = webUrlInput.value.trim().length > 0;
  }

  if (hasContent) {
    generateBtn.disabled = false;
    generateBtn.className = 'w-full mt-2 py-3 rounded-lg text-xs font-bold bg-[var(--success-bg)] hover:bg-[var(--success-bg-hover)] text-white shadow-sm transition-all flex items-center justify-center gap-2 cursor-pointer active:scale-98';
  } else {
    generateBtn.disabled = true;
    generateBtn.className = 'w-full mt-2 py-3 rounded-lg text-xs font-bold bg-slate-100 text-slate-450 border border-[var(--border-default)] dark:bg-slate-900/40 dark:text-slate-650 cursor-not-allowed transition-all flex items-center justify-center gap-2';
  }

  // 3. Input counter
  charCounter.textContent = `${state.extractedText.length} characters`;

  // 4. Render Study Set Panels / Wizard Navigation
  if (state.studyDeck) {
    wizardContainer.classList.add('hidden');
    studyDeckSection.classList.remove('hidden');
    renderTabs();
  } else {
    wizardContainer.classList.remove('hidden');
    studyDeckSection.classList.add('hidden');

    // Handle Wizard Step Visibility
    if (state.wizardStep === 1) {
      wizardStep1.classList.remove('hidden');
      wizardStep2.classList.add('hidden');
      wizardProgressFill.style.width = '25%';

      // Hide Back button in step 1
      wizardBackBtn.classList.add('opacity-0', 'pointer-events-none');
    } else {
      wizardStep1.classList.add('hidden');
      wizardStep2.classList.remove('hidden');
      wizardProgressFill.style.width = '75%';

      // Show Back button in step 2
      wizardBackBtn.classList.remove('opacity-0', 'pointer-events-none');
    }
  }
}

// Tab Switching
function renderTabs() {
  if (state.activeTab === 'flashcards') {
    tabFlashcardsBtn.className = 'border-b-2 border-[var(--accent-fg)] text-[var(--text-default)] px-1 py-3 text-xs font-bold tracking-wide uppercase flex items-center gap-2';
    tabQuizBtn.className = 'border-b-2 border-transparent text-[var(--text-muted)] hover:text-[var(--text-default)] px-1 py-3 text-xs font-bold tracking-wide uppercase flex items-center gap-2';

    tabFlashcardsView.classList.remove('hidden');
    tabQuizView.classList.add('hidden');
    renderFlashcards();
  } else {
    tabQuizBtn.className = 'border-b-2 border-[var(--accent-fg)] text-[var(--text-default)] px-1 py-3 text-xs font-bold tracking-wide uppercase flex items-center gap-2';
    tabFlashcardsBtn.className = 'border-b-2 border-transparent text-[var(--text-muted)] hover:text-[var(--text-default)] px-1 py-3 text-xs font-bold tracking-wide uppercase flex items-center gap-2';

    tabQuizView.classList.remove('hidden');
    tabFlashcardsView.classList.add('hidden');
    renderQuiz();
  }
}

// Render current flashcard
function renderFlashcards() {
  if (!state.studyDeck || !state.studyDeck.flashcards || state.studyDeck.flashcards.length === 0) return;

  const card = state.studyDeck.flashcards[state.currentCardIndex];
  cardConceptText.textContent = card.concept;
  cardDefinitionText.textContent = card.definition;

  // Synchronize 3D flip visual state
  if (state.cardFlipped) {
    flashcardInner.classList.add('rotate-y-180');
  } else {
    flashcardInner.classList.remove('rotate-y-180');
  }

  // Progress elements
  const currentCount = state.currentCardIndex + 1;
  const totalCount = state.studyDeck.flashcards.length;
  flashcardProgressText.textContent = `${currentCount} / ${totalCount}`;
  flashcardProgressBar.style.width = `${(currentCount / totalCount) * 100}%`;
}

// Flashcard card navigation wrapper (prevents text flashing during flip)
function navigateCard(direction) {
  if (!state.studyDeck) return;

  const changeContent = () => {
    if (direction === 'next') {
      state.currentCardIndex = (state.currentCardIndex + 1) % state.studyDeck.flashcards.length;
    } else {
      state.currentCardIndex = (state.currentCardIndex - 1 + state.studyDeck.flashcards.length) % state.studyDeck.flashcards.length;
    }
    renderFlashcards();
  };

  if (state.cardFlipped) {
    state.cardFlipped = false;
    flashcardInner.classList.remove('rotate-y-180');
    // Wait for the card to spin halfway to hide text change
    setTimeout(changeContent, 200);
  } else {
    changeContent();
  }
}

// Render current quiz
function renderQuiz() {
  if (!state.studyDeck || !state.studyDeck.quiz || state.studyDeck.quiz.length === 0) return;

  if (state.quizCompleted) {
    quizQuestionCard.classList.add('hidden');
    quizResultsCard.classList.remove('hidden');

    quizFinalScore.textContent = `${state.quizScore} / ${state.studyDeck.quiz.length}`;
    const percentage = Math.round((state.quizScore / state.studyDeck.quiz.length) * 100);
    quizPercentageText.textContent = `${percentage}% Score - ${percentage >= 70 ? 'Mahusay! / Great Job!' : 'Subukan nating mag-aral pa / Let\'s study more'}`;
    return;
  }

  quizQuestionCard.classList.remove('hidden');
  quizResultsCard.classList.add('hidden');

  const question = state.studyDeck.quiz[state.currentQuizIndex];
  quizQuestionText.textContent = question.question;
  quizProgressText.textContent = `Question ${state.currentQuizIndex + 1} of ${state.studyDeck.quiz.length}`;

  // Render options list
  quizOptionsContainer.innerHTML = '';
  const hasAnswered = state.quizAnswers[state.currentQuizIndex] !== undefined;

  question.options.forEach((option, idx) => {
    const button = document.createElement('button');
    button.className = 'option-btn text-left text-xs font-semibold p-4 rounded-xl border transition-all flex items-center justify-between ';
    button.textContent = option;

    if (!hasAnswered) {
      // Unanswered state
      button.className += 'bg-slate-50 border-slate-200 text-slate-700 hover:bg-slate-100 hover:border-slate-300 dark:bg-slate-900 dark:border-slate-800 dark:text-slate-350 dark:hover:bg-slate-800/80';
      button.disabled = false;
      button.addEventListener('click', () => selectQuizOption(idx));
    } else {
      // Answered state - lock actions
      button.disabled = true;
      const selectedIdx = state.quizAnswers[state.currentQuizIndex];
      const correctIdx = question.correct_index;

      if (idx === correctIdx) {
        // 1. Use classList.add and ensure flex layout is active for proper alignment
        button.classList.add('flex', 'items-center', 'justify-between', 'gap-2', 'bg-emerald-50', 'border-emerald-500', 'text-emerald-950', 'dark:bg-emerald-950/20', 'dark:border-emerald-600', 'dark:text-emerald-200');

        // 2. Fixed w-4.5/h-4.5 to standard w-5/h-5
        button.innerHTML += `
    <svg class="w-5 h-5 text-emerald-600 dark:text-emerald-450 shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="3" d="M5 13l4 4L19 7"></path>
    </svg>
  `;
      } else if (idx === selectedIdx) {
        // 1. Ensure the button handles layout correctly (flex, centering, and spacing)
        button.classList.add('flex', 'items-center', 'justify-between', 'gap-2', 'bg-rose-50', 'border-rose-500', 'text-rose-950', 'dark:bg-rose-950/20', 'dark:border-rose-600', 'dark:text-rose-200');

        // 2. Use standard Tailwind sizes (like w-5 h-5) for the SVG
        button.innerHTML += `
    <svg class="w-5 h-5 text-rose-600 dark:text-rose-450 shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="3" d="M6 18L18 6M6 6l12 12"></path>
    </svg>
  `;
      } else {
        // Neutral disabled option
        button.className += 'bg-slate-50 border-slate-200 text-slate-400 dark:bg-slate-900/30 dark:border-slate-850 dark:text-slate-600';
      }
    }
    quizOptionsContainer.appendChild(button);
  });

  // Render feedback / explanations
  if (hasAnswered) {
    const selectedIdx = state.quizAnswers[state.currentQuizIndex];
    const correctIdx = question.correct_index;
    const isCorrect = selectedIdx === correctIdx;

    quizFeedbackBox.classList.remove('hidden');
    quizSubmitBtn.disabled = false;
    quizSubmitBtn.className = 'w-full sm:w-auto px-6 py-2.5 rounded-xl text-xs font-bold bg-brand-600 text-white hover:bg-brand-700 transition-all flex items-center justify-center gap-1.5 cursor-pointer active:scale-95';

    if (isCorrect) {
      quizFeedbackBox.className = 'rounded-xl p-4 border text-xs leading-relaxed slide-in space-y-1 bg-emerald-50/50 border-emerald-250 text-emerald-950 dark:bg-emerald-950/10 dark:border-emerald-900/50 dark:text-emerald-300';
      quizFeedbackTitle.textContent = 'Tama! / Correct! 🎉';
      quizFeedbackTitle.className = 'font-extrabold text-sm text-emerald-700 dark:text-emerald-400 uppercase tracking-wide';
    } else {
      quizFeedbackBox.className = 'rounded-xl p-4 border text-xs leading-relaxed slide-in space-y-1 bg-rose-50/50 border-rose-250 text-rose-950 dark:bg-rose-950/10 dark:border-rose-900/50 dark:text-rose-300';
      quizFeedbackTitle.textContent = 'Mali... / Try again... 💡';
      quizFeedbackTitle.className = 'font-extrabold text-sm text-rose-700 dark:text-rose-450 uppercase tracking-wide';
    }

    quizExplanationText.textContent = question.explanation;

    // Label next button depending on progress
    if (state.currentQuizIndex === state.studyDeck.quiz.length - 1) {
      quizSubmitBtn.querySelector('span').textContent = 'Finish Quiz / Resulta';
    } else {
      quizSubmitBtn.querySelector('span').textContent = 'Next Question / Susunod';
    }
  } else {
    quizFeedbackBox.classList.add('hidden');
    quizSubmitBtn.disabled = true;
    quizSubmitBtn.className = 'w-full sm:w-auto px-6 py-2.5 rounded-xl text-xs font-bold bg-slate-100 text-slate-400 dark:bg-slate-900 dark:text-slate-700 border border-slate-200/40 dark:border-slate-850 cursor-not-allowed transition-all flex items-center justify-center gap-1.5';
    quizSubmitBtn.querySelector('span').textContent = 'Next Question';
  }
}

// Select option in quiz
function selectQuizOption(index) {
  if (state.quizAnswers[state.currentQuizIndex] !== undefined) return; // Guard

  state.quizAnswers[state.currentQuizIndex] = index;
  const question = state.studyDeck.quiz[state.currentQuizIndex];

  if (index === question.correct_index) {
    state.quizScore++;
  }

  renderQuiz();
}

// Submit Quiz Answer & Advance
function advanceQuiz() {
  if (state.currentQuizIndex === state.studyDeck.quiz.length - 1) {
    state.quizCompleted = true;
  } else {
    state.currentQuizIndex++;
  }
  renderQuiz();
}

// Reset Quiz State
function restartQuiz() {
  state.currentQuizIndex = 0;
  state.quizAnswers = [];
  state.quizScore = 0;
  state.quizCompleted = false;
  renderQuiz();
}

// --- Wizard Step & Option Handlers ---
function selectWizardSource(source) {
  state.selectedSource = source;
  state.wizardStep = 2;

  // Hide all input groups first
  inputGroupFile.classList.add('hidden');
  inputGroupNotes.classList.add('hidden');
  inputGroupYoutube.classList.add('hidden');
  inputGroupPhoto.classList.add('hidden');
  inputGroupWeb.classList.add('hidden');

  // Reset content state
  state.extractedText = '';
  textInput.value = '';
  youtubeUrlInput.value = '';
  webUrlInput.value = '';
  fileInput.value = '';
  photoFileInput.value = '';
  fileInfo.classList.add('hidden');
  dropzone.classList.remove('hidden');
  photoInfo.classList.add('hidden');
  photoDropzone.classList.remove('hidden');

  let title = 'Import study material';
  if (source === 'pdf') {
    title = 'Import PDF Document';
    inputGroupFile.classList.remove('hidden');
    document.getElementById('dropzone-text').textContent = 'Drag & Drop PDF here';
    fileInput.accept = '.txt,.pdf';
  } else if (source === 'ppt') {
    title = 'Import PowerPoint Slide Deck';
    inputGroupFile.classList.remove('hidden');
    document.getElementById('dropzone-text').textContent = 'Drag & Drop PPT or PPTX here';
    fileInput.accept = '.pptx,.ppt';
  } else if (source === 'notes') {
    title = 'Paste Study Notes';
    inputGroupNotes.classList.remove('hidden');
  } else if (source === 'youtube') {
    title = 'Import YouTube Video';
    inputGroupYoutube.classList.remove('hidden');
  } else if (source === 'photo') {
    title = 'Photograph your notes';
    inputGroupPhoto.classList.remove('hidden');
  } else if (source === 'web') {
    title = 'Import Website Article Link';
    inputGroupWeb.classList.remove('hidden');
  }

  wizardStep2Title.textContent = title;
  renderState();
}

function goWizardBack() {
  state.wizardStep = 1;
  state.selectedSource = null;
  renderState();
}

function toggleShowMore() {
  state.showMoreActive = !state.showMoreActive;
  if (state.showMoreActive) {
    showMorePanel.style.maxHeight = '100px';
    showMoreIcon.classList.add('rotate-180');
    showMoreToggleBtn.querySelector('span').textContent = 'Show less';
  } else {
    showMorePanel.style.maxHeight = '0px';
    showMoreIcon.classList.remove('rotate-180');
    showMoreToggleBtn.querySelector('span').textContent = 'Show more';
  }
}

function loadDemoNoMaterial() {
  // Load sample Biology content
  state.extractedText = 'Cell biology introduction. The mitochondria is the powerhouse of the cell generating ATP energy. Photosynthesis is the solar kitchen of plants converting sunlight and water into simple glucose. Eukaryotic cells store their genetic DNA instructions inside the nucleus.';
  state.studyDeck = generateLocalMockSet(state.extractedText, state.selectedLanguage);

  state.currentCardIndex = 0;
  state.cardFlipped = false;
  state.currentQuizIndex = 0;
  state.quizAnswers = [];
  state.quizScore = 0;
  state.quizCompleted = false;

  renderState();
}

// --- Setup Interactions & Listeners ---
function setupEventListeners() {
  // Theme button
  darkModeBtn.addEventListener('click', toggleTheme);

  // Wizard option selectors
  document.getElementById('opt-pdf').addEventListener('click', () => selectWizardSource('pdf'));
  document.getElementById('opt-notes').addEventListener('click', () => selectWizardSource('notes'));
  document.getElementById('opt-ppt').addEventListener('click', () => selectWizardSource('ppt'));
  document.getElementById('opt-youtube').addEventListener('click', () => selectWizardSource('youtube'));
  document.getElementById('opt-photo').addEventListener('click', () => selectWizardSource('photo'));
  document.getElementById('opt-web').addEventListener('click', () => selectWizardSource('web'));

  // Show more toggle
  showMoreToggleBtn.addEventListener('click', toggleShowMore);

  // Back button and Demo trigger
  wizardBackBtn.addEventListener('click', goWizardBack);
  btnDemoNoMaterial.addEventListener('click', loadDemoNoMaterial);

  // Output language select
  languageSelect.addEventListener('change', (e) => {
    state.selectedLanguage = e.target.value;
  });

  // Textarea input listeners
  textInput.addEventListener('input', (e) => {
    state.extractedText = e.target.value;
    renderState();
  });

  // YouTube URL input listener
  youtubeUrlInput.addEventListener('input', () => {
    renderState();
  });

  // Web URL input listener
  webUrlInput.addEventListener('input', () => {
    renderState();
  });

  // PDF / PPT Dropzone triggers
  dropzone.addEventListener('click', () => fileInput.click());

  dropzone.addEventListener('dragover', (e) => {
    e.preventDefault();
    dropzone.className = 'border-2 border-dashed border-[var(--accent-fg)] bg-[var(--accent-bg)] rounded-lg p-5 text-center cursor-pointer transition-colors flex flex-col items-center justify-center min-h-[130px]';
  });

  dropzone.addEventListener('dragleave', () => {
    dropzone.className = 'border-2 border-dashed border-[var(--border-default)] hover:border-[var(--accent-fg)] rounded-lg p-5 text-center cursor-pointer transition-colors bg-[var(--bg-default)] flex flex-col items-center justify-center min-h-[130px]';
  });

  dropzone.addEventListener('drop', (e) => {
    e.preventDefault();
    dropzone.className = 'border-2 border-dashed border-[var(--border-default)] hover:border-[var(--accent-fg)] rounded-lg p-5 text-center cursor-pointer transition-colors bg-[var(--bg-default)] flex flex-col items-center justify-center min-h-[130px]';

    const file = e.dataTransfer.files[0];
    if (file) handleUploadedFile(file);
  });

  fileInput.addEventListener('change', (e) => {
    const file = e.target.files[0];
    if (file) handleUploadedFile(file);
  });

  // Remove uploaded file button
  removeFileBtn.addEventListener('click', () => {
    fileInput.value = '';
    state.extractedText = '';
    fileInfo.classList.add('hidden');
    dropzone.classList.remove('hidden');
    renderState();
  });

  // Photograph Dropzone triggers
  photoDropzone.addEventListener('click', () => photoFileInput.click());

  photoDropzone.addEventListener('dragover', (e) => {
    e.preventDefault();
    photoDropzone.className = 'border-2 border-dashed border-[var(--accent-fg)] bg-[var(--accent-bg)] rounded-lg p-5 text-center cursor-pointer transition-colors flex flex-col items-center justify-center min-h-[130px]';
  });

  photoDropzone.addEventListener('dragleave', () => {
    photoDropzone.className = 'border-2 border-dashed border-[var(--border-default)] hover:border-[var(--accent-fg)] rounded-lg p-5 text-center cursor-pointer transition-colors bg-[var(--bg-default)] flex flex-col items-center justify-center min-h-[130px]';
  });

  photoDropzone.addEventListener('drop', (e) => {
    e.preventDefault();
    photoDropzone.className = 'border-2 border-dashed border-[var(--border-default)] hover:border-[var(--accent-fg)] rounded-lg p-5 text-center cursor-pointer transition-colors bg-[var(--bg-default)] flex flex-col items-center justify-center min-h-[130px]';

    const file = e.dataTransfer.files[0];
    if (file) handlePhotoFile(file);
  });

  photoFileInput.addEventListener('change', (e) => {
    const file = e.target.files[0];
    if (file) handlePhotoFile(file);
  });

  removePhotoBtn.addEventListener('click', () => {
    photoFileInput.value = '';
    state.extractedText = '';
    photoInfo.classList.add('hidden');
    photoDropzone.classList.remove('hidden');
    renderState();
  });

  // Trigger Study Deck Generation
  generateBtn.addEventListener('click', generateDeck);

  // Tabs clicking
  tabFlashcardsBtn.addEventListener('click', () => {
    state.activeTab = 'flashcards';
    renderTabs();
  });
  tabQuizBtn.addEventListener('click', () => {
    state.activeTab = 'quiz';
    renderTabs();
  });

  // Flashcards flip & navigation triggers
  flashcardContainer.addEventListener('click', () => {
    state.cardFlipped = !state.cardFlipped;
    renderFlashcards();
  });
  prevCardBtn.addEventListener('click', () => navigateCard('prev'));
  nextCardBtn.addEventListener('click', () => navigateCard('next'));

  // Quiz progression triggers
  quizSubmitBtn.addEventListener('click', advanceQuiz);
  quizRestartBtn.addEventListener('click', restartQuiz);
}

// File loading and parsing selector (PDF, PPT, TXT)
async function handleUploadedFile(file) {
  const isPPT = file.name.endsWith('.pptx') || file.name.endsWith('.ppt');
  const isTXT = file.name.endsWith('.txt') || file.type === 'text/plain';
  const isPDF = file.name.endsWith('.pdf') || file.type === 'application/pdf';

  if (!isTXT && !isPDF && !isPPT) {
    alert('Format error: Mangyaring pumili lamang ng TXT, PDF o PPT/PPTX na file.');
    return;
  }

  // Visual file details update
  dropzone.classList.add('hidden');
  fileInfo.classList.remove('hidden');
  fileNameText.textContent = file.name;
  fileSizeText.textContent = `${(file.size / (1024 * 1024)).toFixed(2)} MB`;

  try {
    if (isTXT) {
      const reader = new FileReader();
      reader.onload = (e) => {
        state.extractedText = e.target.result;
        renderState();
      };
      reader.readAsText(file);
    } else if (isPDF) {
      fileNameText.textContent = `Parsing: ${file.name}...`;
      const buffer = await file.arrayBuffer();
      const text = await extractTextFromPDF(buffer);
      state.extractedText = text;
      fileNameText.textContent = file.name;
      renderState();
    } else if (isPPT) {
      fileNameText.textContent = `Extracting slides: ${file.name}...`;
      // Simulate slide parsing delay
      setTimeout(() => {
        state.extractedText = `Slide 1: Intro to programming. JavaScript is the programming language that powers the web client-side. HTML is the bones, CSS is clothes, JS is muscles.
Slide 2: Waiter analogy. API is the waiter in a restaurant taking orders to the kitchen (server) and returning responses to the user.
Slide 3: Database storage. Database stores structured client accounts and history safely.`;
        fileNameText.textContent = file.name;
        renderState();
      }, 800);
    }
  } catch (err) {
    console.error('[GabayAI] File loading error:', err);
    fileInfo.classList.add('hidden');
    dropzone.classList.remove('hidden');
    state.extractedText = '';
    renderState();
  }
}

// Extraction logic from PDF
async function extractTextFromPDF(arrayBuffer) {
  try {
    const pdf = await pdfjsLib.getDocument({ data: arrayBuffer }).promise;
    let extractedText = '';
    for (let i = 1; i <= pdf.numPages; i++) {
      const page = await pdf.getPage(i);
      const content = await page.getTextContent();
      const pageText = content.items.map(item => item.str).join(' ');
      extractedText += `--- Page ${i} ---\n${pageText}\n\n`;
    }
    return extractedText;
  } catch (e) {
    console.error('[GabayAI] PDF Parser error:', e);
    alert('Maling PDF formatting. Hindi ma-parse ang teksto.');
    throw e;
  }
}

// Photograph Notes simulation helper
function handlePhotoFile(file) {
  if (!file.type.startsWith('image/')) {
    alert('Format error: Mangyaring pumili lamang ng image file (PNG/JPG).');
    return;
  }
  photoDropzone.classList.add('hidden');
  photoInfo.classList.remove('hidden');
  photoFileName.textContent = file.name;
  photoFileSize.textContent = `${(file.size / (1024 * 1024)).toFixed(2)} MB`;

  photoFileName.textContent = 'Scanning notes...';
  // Simulate OCR text extraction after a short delay
  setTimeout(() => {
    state.extractedText = 'Photograph notes content. Cell biology summary. The mitochondria is the powerhouse of the cell generating ATP energy. Photosynthesis is the solar kitchen of plants converting sunlight and water into simple glucose. Eukaryotic cells store their genetic DNA instructions inside the nucleus.';
    photoFileName.textContent = file.name;
    renderState();
  }, 1000);
}

// JSON validation helper
function cleanAndParseJSON(str) {
  let cleaned = str.trim();

  // Clean markdown delimiters if model includes it
  if (cleaned.startsWith('```')) {
    cleaned = cleaned.replace(/^```(json)?/i, '').replace(/```$/, '').trim();
  }

  // Find first { and last } to grab only the JSON
  const start = cleaned.indexOf('{');
  const end = cleaned.lastIndexOf('}');
  if (start !== -1 && end !== -1) {
    cleaned = cleaned.slice(start, end + 1);
  }

  return JSON.parse(cleaned);
}

// Generate the Flashcards and Quizzes
async function generateDeck() {
  if (!state.demoMode && (!state.modelDownloaded || !generator)) {
    alert('AI Engine not ready: I-download muna ang local model o paganahin ang Demo Mode.');
    return;
  }

  // Pre-fill text content for simulated YouTube and Web sources
  if (state.selectedSource === 'youtube') {
    state.extractedText = `YouTube video transcript on Biology: Mitochondria generate chemical energy ATP required to power the cell. Photosynthesis is the solar kitchen of plants converting sunlight and water into simple glucose. Eukaryotic cells store their genetic DNA instructions inside the nucleus.`;
  } else if (state.selectedSource === 'web') {
    state.extractedText = `Website page article content on Computer Science: JavaScript is the programming language that powers modern interactive web clients. API is the waiter in a restaurant taking orders to the server. Database is a structured filing cabinet storing records.`;
  }

  // Set visual loader state
  wizardContainer.classList.add('hidden');
  studyDeckSection.classList.add('hidden');
  generatingLoader.classList.remove('hidden');
  generateBtn.disabled = true;

  // Let DOM update loader before locking CPU with inference
  setTimeout(async () => {
    try {
      if (state.demoMode) {
        // Call Rule-Based Mock Generator
        state.studyDeck = generateLocalMockSet(state.extractedText, state.selectedLanguage);
      } else {
        // Run Local LLM Inference using WebGPU
        let promptLanguageInstruction = '';
        if (state.selectedLanguage === 'taglish') {
          promptLanguageInstruction = "You are a friendly Taglish peer. Create exactly 3 flashcards and 3 quiz questions from the user text. Use local Filipino analogies. Output raw JSON format matching this structure: { \"flashcards\": [{ \"concept\": \"\", \"definition\": \"\" }], \"quiz\": [{ \"question\": \"\", \"options\": [\"\", \"\", \"\", \"\"], \"correct_index\": 0, \"explanation\": \"\" }] }";
        } else if (state.selectedLanguage === 'filipino') {
          promptLanguageInstruction = "Ikaw ay isang kaibigang nagtuturo. Gumawa ng eksaktong 3 flashcards at 3 quiz questions mula sa text sa wikang Filipino. Gumamit ng mga lokal na halimbawa. Output raw JSON format matching this structure: { \"flashcards\": [{ \"concept\": \"\", \"definition\": \"\" }], \"quiz\": [{ \"question\": \"\", \"options\": [\"\", \"\", \"\", \"\"], \"correct_index\": 0, \"explanation\": \"\" }] }";
        } else {
          promptLanguageInstruction = "You are a friendly study peer. Create exactly 3 flashcards and 3 quiz questions from the user text in English. Use clear analogies. Output raw JSON format matching this structure: { \"flashcards\": [{ \"concept\": \"\", \"definition\": \"\" }], \"quiz\": [{ \"question\": \"\", \"options\": [\"\", \"\", \"\", \"\"], \"correct_index\": 0, \"explanation\": \"\" }] }";
        }

        const messages = [
          { role: 'system', content: promptLanguageInstruction },
          { role: 'user', content: `Analyze this study material:\n\n${state.extractedText}\n\nProvide only the raw JSON output matching the format exactly.` }
        ];

        console.log('[GabayAI] Triggering Qwen2.5 WebGPU Inference...');
        const response = await generator(messages, {
          max_new_tokens: 1024,
          temperature: 0.2
        });

        const rawResult = response[0].generated_text.slice(-1)[0].content;
        console.log('[GabayAI] Model Output:', rawResult);
        state.studyDeck = cleanAndParseJSON(rawResult);
      }

      // Initialize slide states
      state.currentCardIndex = 0;
      state.cardFlipped = false;
      state.currentQuizIndex = 0;
      state.quizAnswers = [];
      state.quizScore = 0;
      state.quizCompleted = false;

      generatingLoader.classList.add('hidden');
      studyDeckSection.classList.remove('hidden');
      renderState();
    } catch (err) {
      console.error('[GabayAI] Generation error:', err);
      alert('Inference error: Nagkaproblema sa pagproseso ng JSON. Mangyaring subukan muli o lumipat sa Demo Mode.');
      generatingLoader.classList.add('hidden');
      wizardContainer.classList.remove('hidden');
      renderState();
    }
  }, 100);
}

// --- Dynamic Content Mock Generator ---
function generateLocalMockSet(text, language) {
  const clean = text.trim();

  // Pick curated set if target phrases are present, or fallback to text segmentation parser
  const hasBiology = /cell|mitochondria|biology|photosynthesis|halaman|organ/i.test(clean);
  const hasKasaysayan = /rizal|bonifacio|rebolusyon|pilipinas|kasaysayan|history|kastila/i.test(clean);
  const hasProgramming = /javascript|code|programming|computer|api|database|software/i.test(clean);

  if (hasBiology) {
    return getBiologyDeck(language);
  } else if (hasKasaysayan) {
    return getKasaysayanDeck(language);
  } else if (hasProgramming) {
    return getProgrammingDeck(language);
  } else {
    return parseTextToDeck(clean, language);
  }
}

// Static mock deck data: Biology
function getBiologyDeck(lang) {
  if (lang === 'taglish') {
    return {
      flashcards: [
        { concept: 'Mitochondria', definition: 'Ang powerhouse of the cell. Parang Meralco ng cell natin—gumagawa ng ATP (energy) para makagalaw at makatrabaho ang buong organism.' },
        { concept: 'Photosynthesis', definition: 'Proseso kung saan gumagawa ng sariling pagkain ang halaman gamit ang sunlight. Parang solar panel kitchen ng kalikasan!' },
        { concept: 'Nucleus', definition: 'Ang control center ng cell kung saan nakatago ang DNA. Parang Munisipyo o Kapitolyo na nagdedesisyon sa lahat ng gagawin ng cell.' }
      ],
      quiz: [
        {
          question: 'Alin sa mga sumusunod ang nagsisilbing "Meralco o Powerhouse" ng ating cells?',
          options: ['Nucleus', 'Mitochondria', 'Cell Membrane', 'Chloroplast'],
          correct_index: 1,
          explanation: 'Mitochondria! Dahil ito ang responsable sa cellular respiration at paggawa ng ATP na nagsisilbing panggatong o kuryente ng cell.'
        },
        {
          question: 'Ano ang pinakamagandang analogo para sa Photosynthesis?',
          options: ['Paggawa ng kuryente sa hydro dam', 'Pagluluto sa solar panel kitchen', 'Pagtatapon ng basura sa basurahan', 'Paghahatid ng sulat ng kartero'],
          correct_index: 1,
          explanation: 'Pagluluto sa solar panel kitchen! Kasi ang halaman ay kumukuha ng liwanag (solar energy) para gumawa ng sariling asukal (pagkain).'
        },
        {
          question: 'Saan nakaimbak ang control operations at DNA sa loob ng isang eukaryotic cell?',
          options: ['Ribosome', 'Cytoplasm', 'Nucleus', 'Lysosome'],
          correct_index: 2,
          explanation: 'Nucleus! Ito ang nagsisilbing main executive branch o munisipyo na nag-uutos sa cell gamit ang blueprint ng DNA.'
        }
      ]
    };
  } else if (lang === 'filipino') {
    return {
      flashcards: [
        { concept: 'Mitochondria', definition: 'Ang gumagawa ng lakas ng cell. Ito ang nagbibigay ng enerhiya upang ang mga bahagi ng halaman o hayop ay gumana ng maayos.' },
        { concept: 'Photosynthesis', definition: 'Ang pamamaraan ng paglikha ng pagkain ng mga halaman sa pamamagitan ng sikat ng araw at tubig.' },
        { concept: 'Nucleus', definition: 'Ang sentro ng pamamahala ng cell na naglalaman ng mga henetikong impormasyon (DNA).' }
      ],
      quiz: [
        {
          question: 'Ano ang bahagi ng cell na gumagawa ng lakas at enerhiya?',
          options: ['Nucleus', 'Mitochondria', 'Chloroplast', 'Cytoplasm'],
          correct_index: 1,
          explanation: 'Mitochondria ang nagsisilbing pangunahing tagagawa ng enerhiya para sa cell upang ito ay mabuhay.'
        },
        {
          question: 'Paano gumagawa ng pagkain ang mga halaman?',
          options: ['Sa pamamagitan ng Mitochondria', 'Sa pamamagitan ng Photosynthesis', 'Sa pamamagitan ng Pagsipsip ng lupa', 'Sa pamamagitan ng Kagubatan'],
          correct_index: 1,
          explanation: 'Photosynthesis ang tawag sa proseso ng paggawa ng pagkain ng mga halaman gamit ang init ng araw.'
        },
        {
          question: 'Ano ang nagsisilbing utak o sentro ng pag-uutos sa cell?',
          options: ['Ribosome', 'Nucleus', 'Cell Wall', 'Vacuole'],
          correct_index: 1,
          explanation: 'Nucleus ang naglalaman ng DNA at nagdidikta ng mga aktibidad ng buong cell.'
        }
      ]
    };
  } else {
    return {
      flashcards: [
        { concept: 'Mitochondria', definition: 'The powerhouse of the cell. It generates chemical energy (ATP) required to power the cell\'s biochemical reactions.' },
        { concept: 'Photosynthesis', definition: 'The process used by plants to convert light energy, usually from the sun, into chemical energy (glucose).' },
        { concept: 'Nucleus', definition: 'The membrane-enclosed organelle that contains the genetic material (DNA) and acts as the cell\'s command center.' }
      ],
      quiz: [
        {
          question: 'Which organelle is widely known as the powerhouse of the cell?',
          options: ['Endoplasmic Reticulum', 'Mitochondria', 'Lysosome', 'Golgi Apparatus'],
          correct_index: 1,
          explanation: 'Mitochondria generate adenosine triphosphate (ATP), the primary energy currency of the cell.'
        },
        {
          question: 'What is the main output of photosynthesis used by plants for food?',
          options: ['Carbon Dioxide', 'Oxygen', 'Glucose', 'Nitrogen'],
          correct_index: 2,
          explanation: 'Glucose is the simple sugar plants generate during photosynthesis to store energy.'
        },
        {
          question: 'Where is the DNA of a eukaryotic cell primarily stored?',
          options: ['Nucleus', 'Ribosome', 'Vacuole', 'Cytoplasm'],
          correct_index: 0,
          explanation: 'The nucleus houses the chromosomes containing the cell\'s genetic instructions.'
        }
      ]
    };
  }
}

// Static mock deck data: Kasaysayan
function getKasaysayanDeck(lang) {
  if (lang === 'taglish') {
    return {
      flashcards: [
        { concept: 'Jose Rizal', definition: 'Pambansang bayani ng Pilipinas. Ginamit ang pluma kaysa espada—parang 19th-century keyboard warrior na lumaban sa kolonyalismo gamit ang Noli at El Fili.' },
        { concept: 'Katipunan (KKK)', definition: 'Lihim na samahan na itinatag ni Andres Bonifacio. Sila ang nagsimula ng rebolusyon matapos punitin ang sedula sa Sigaw ng Pugad Lawin (parang nag-leave sa GC ng mga Kastila!).' },
        { concept: 'Gomburza', definition: 'Tatlong paring martir (Gomez, Burgos, Zamora) na binitay sa garote. Ang kanilang kamatayan ang naging mitsa upang magising ang pagka-nasyonalismo ni Rizal at ng mga Pilipino.' }
      ],
      quiz: [
        {
          question: 'Paano nilabanan ni Jose Rizal ang pamahalaang Kastila?',
          options: ['Sa pamamagitan ng pag-organisa ng militar', 'Sa pamamagitan ng panulat, nobela, at diplomasya', 'Sa pamamagitan ng pakikipagkasundo sa Amerika', 'Sa pamamagitan ng pagpunit ng sedula'],
          correct_index: 1,
          explanation: 'Panulat at nobela! Isinulat niya ang Noli Me Tangere at El Filibusterismo upang ilantad ang katiwalian ng mga Kastila nang walang dumanak na dugo.'
        },
        {
          question: 'Sino ang nagtatag ng lihim na samahang Katipunan (KKK)?',
          options: ['Jose Rizal', 'Andres Bonifacio', 'Emilio Aguinaldo', 'Apolinario Mabini'],
          correct_index: 1,
          explanation: 'Andres Bonifacio! Itinatag niya ang KKK sa Tondo, Maynila upang makamit ang kalayaan mula sa Espanya sa pamamagitan ng rebolusyon.'
        },
        {
          question: 'Ano ang epekto ng pagbitay sa tatlong paring Gomburza?',
          options: ['Natakot ang mga Pilipino at sumuko', 'Nagising ang damdaming nasyonalismo ng mga Pilipino', 'Umalis ang mga Kastila sa bansa', 'Sumuko si Andres Bonifacio'],
          correct_index: 1,
          explanation: 'Nagising ang nasyonalismo! Ang kawalang-katarungan sa pagbitay sa kanila ang nag-udyok sa marami, kasama na si Rizal, na simulan ang Kilusang Propaganda.'
        }
      ]
    };
  } else if (lang === 'filipino') {
    return {
      flashcards: [
        { concept: 'Jose Rizal', definition: 'Ang pambansang bayani ng Pilipinas na sumulat ng mga nobelang nagpaalsa sa kaisipan ng mamamayan laban sa mga Kastila.' },
        { concept: 'Katipunan (KKK)', definition: 'Ang rebolusyonaryong samahan na itinatag ni Andres Bonifacio upang makamit ang kalayaan sa pamamagitan ng armas.' },
        { concept: 'Gomburza', definition: 'Ang tatlong paring sekular na pinatay sa pamamagitan ng garote na nagbigay inspirasyon sa Kilusang Propaganda.' }
      ],
      quiz: [
        {
          question: 'Sino ang pambansang bayani na sumulat ng Noli Me Tangere?',
          options: ['Andres Bonifacio', 'Jose Rizal', 'Marcelo H. Del Pilar', 'Juan Luna'],
          correct_index: 1,
          explanation: 'Si Jose Rizal ang sumulat ng Noli at El Fili na nagbukas sa mata ng mga Pilipino sa pang-aabuso.'
        },
        {
          question: 'Ano ang pangunahing layunin ng Katipunan?',
          options: ['Makipagkaibigan sa Espanya', 'Makipagpalitan ng kalakal', 'Makipaglaban para sa ganap na kalayaan ng bansa', 'Ipalaganap ang bagong relihiyon'],
          correct_index: 2,
          explanation: 'Ganap na kalayaan! Nilayon ng Katipunan na palayasin ang mga kolonyalistang Kastila sa pamamagitan ng pag-aalsa.'
        },
        {
          question: 'Sila ang tatlong pari na binitay na nag-udyok sa pagkakaisa ng mga Pilipino:',
          options: ['Gomez, Burgos, Zamora', 'Rizal, Lopez, Jaena', 'Aguinaldo, Bonifacio, Mabini', 'Luna, del Pilar, Jacinto'],
          correct_index: 0,
          explanation: 'Gomez, Burgos, at Zamora (Gomburza) ang binitay sa Bagumbayan na pinagbintangan sa Pag-aalsa sa Cavite.'
        }
      ]
    };
  } else {
    return {
      flashcards: [
        { concept: 'Jose Rizal', definition: 'The national hero of the Philippines. He advocated for reforms using his pen instead of weapons, writing Noli Me Tangere and El Filibusterismo.' },
        { concept: 'Katipunan (KKK)', definition: 'A secret revolutionary society founded by Andres Bonifacio in 1892 to gain independence from Spain through armed revolt.' },
        { concept: 'Gomburza', definition: 'Three secular priests (Gomez, Burgos, Zamora) executed in 1872, whose martyrdom triggered the awakening of Philippine nationalism.' }
      ],
      quiz: [
        {
          question: 'Which method did Jose Rizal primarily use to fight Spanish colonization?',
          options: ['Armed revolution', 'Literary works and peaceful advocacy', 'Guerrilla warfare', 'Alliances with foreign empires'],
          correct_index: 1,
          explanation: 'Rizal wrote exposes and novels to peacefully demand reforms from the Spanish Crown, inspiring the reform movement.'
        },
        {
          question: 'Who is known as the Father of the Katipunan?',
          options: ['Jose Rizal', 'Andres Bonifacio', 'Emilio Aguinaldo', 'Apolinario Mabini'],
          correct_index: 1,
          explanation: 'Andres Bonifacio founded the Katipunan (KKK) and led the initial phase of the revolution.'
        },
        {
          question: 'What historical event in 1872 is credited with awakening Rizal\'s political activism?',
          options: ['The opening of the Suez Canal', 'The execution of Gomburza', 'The founding of La Liga Filipina', 'The Cry of Pugad Lawin'],
          correct_index: 1,
          explanation: 'The execution of the three Gomburza priests deeply affected Rizal, prompting him to dedicate El Filibusterismo to them.'
        }
      ]
    };
  }
}

// Static mock deck data: Programming
function getProgrammingDeck(lang) {
  if (lang === 'taglish') {
    return {
      flashcards: [
        { concept: 'JavaScript', definition: 'Ang muscles at brain ng websites. Kung ang HTML ay buto at ang CSS ay damit, JS naman ang nagpapagalaw (interactivity, logic) sa screen.' },
        { concept: 'API', definition: 'Application Programming Interface. Parang waiter sa restaurant—kumukuha ng order mo (request), dinadala sa kusina (server), at ibinabalik ang pagkain (response).' },
        { concept: 'Database', definition: 'Lugar kung saan nakatabi ang organized data. Parang digital na locker o filing cabinet kung saan mabilis maghanap at magtago ng impormasyon.' }
      ],
      quiz: [
        {
          question: 'Sa paggawa ng website, alin ang nagsisilbing "muscles at brain" na gumagawa ng interactive features?',
          options: ['HTML', 'CSS', 'JavaScript', 'SQL'],
          correct_index: 2,
          explanation: 'JavaScript! Habang HTML ay structur at CSS ay style, JS ang nagpapatakbo ng interactive actions tulad ng popups at dynamic calculations.'
        },
        {
          question: 'Ano ang ginagawa ng isang API batay sa analogy ng restaurant waiter?',
          options: ['Nagluluto ng pagkain sa kusina', 'Naghahatid ng request sa server at nagdadala ng response sa kliyente', 'Naghuhugas ng plato sa likod', 'Nag-aayos ng lamesa'],
          correct_index: 1,
          explanation: 'Naghahatid ng request at response! API ang nagdudugtong sa client interface at sa remote server backend.'
        },
        {
          question: 'Ano ang pangunahing silbi ng isang Database?',
          options: ['Mag-compile ng code para maging executable', 'Mabilis at maayos na mag-imbak ng impormasyon', 'Mag-ayos ng layout ng website', 'Mag-block ng virus'],
          correct_index: 1,
          explanation: 'Mag-imbak ng impormasyon! Nagbibigay ito ng mabilisang storage, query at pagbabago ng raw application data.'
        }
      ]
    };
  } else if (lang === 'filipino') {
    return {
      flashcards: [
        { concept: 'JavaScript', definition: 'Ang wika ng kompyuter na nagdaragdag ng interaktibidad sa mga pahina ng internet.' },
        { concept: 'API', definition: 'Ugnayan na nagpapahintulot sa dalawang programa na mag-usap at magpalitan ng datos sa isa\'t isa.' },
        { concept: 'Database', definition: 'Isang organisadong imbakan ng mga elektronikong impormasyon o datos.' }
      ],
      quiz: [
        {
          question: 'Ano ang pangunahing gamit ng JavaScript sa web development?',
          options: ['I-format ang disenyo', 'Magdagdag ng interaktibong lohika sa website', 'Gumawa ng mga lamesa sa database', 'Magpadala ng email'],
          correct_index: 1,
          explanation: 'Ginagamit ang JavaScript upang maging buhay at interaktibo ang isang static na HTML page.'
        },
        {
          question: 'Ano ang kahulugan ng API?',
          options: ['Application Programming Interface', 'Access Program Internet', 'Automatic Protocol Integration', 'Address Path Identifier'],
          correct_index: 0,
          explanation: 'API o Application Programming Interface ang nag-uugnay sa magkakaibang aplikasyon.'
        },
        {
          question: 'Saan natin itinatabi ang mga impormasyon tulad ng username at password ng user sa paraang maayos?',
          options: ['API', 'CSS Stylesheet', 'Database', 'Web Browser Cache'],
          correct_index: 2,
          explanation: 'Database ang nagsisilbing ligtas at organisadong imbakan ng pangmatagalang datos ng app.'
        }
      ]
    };
  } else {
    return {
      flashcards: [
        { concept: 'JavaScript', definition: 'The scripting language that enables interactive web pages. It controls behavior, handles calculations, and updates page elements dynamically.' },
        { concept: 'API', definition: 'Application Programming Interface. A set of rules allowing different software applications to communicate and transfer data between each other.' },
        { concept: 'Database', definition: 'An organized collection of structured data, typically stored electronically in a computer system for fast retrieval.' }
      ],
      quiz: [
        {
          question: 'Which technology provides the interactive logic on modern web browsers?',
          options: ['HTML', 'CSS', 'JavaScript', 'XML'],
          correct_index: 2,
          explanation: 'JavaScript is the programming language that runs in the browser, enabling dynamic changes without reloading.'
        },
        {
          question: 'What is the primary role of an API?',
          options: ['To render the graphical user interface', 'To allow two software modules to exchange data', 'To compile code into machine language', 'To secure network ports'],
          correct_index: 1,
          explanation: 'APIs acts as messengers, taking requests to a system and bringing back the responses.'
        },
        {
          question: 'Which of the following describes a Database?',
          options: ['A tool to compile JavaScript', 'A structured electronic storage of data', 'An internet domain name server', 'A graphic designing utility'],
          correct_index: 1,
          explanation: 'A database is optimized to store, organize, query, and manage digital information.'
        }
      ]
    };
  }
}

// Fallback rule-based parsing engine for any arbitrary user text
function parseTextToDeck(text, lang) {
  // Extract sentences
  const sentences = text
    .split(/[.!?\n]+/)
    .map(s => s.trim())
    .filter(s => s.length > 20); // Keep meaningful length

  const flashcards = [];
  const quiz = [];

  // Default templates to pad if text parsing doesn't yield enough cards
  const defaults = getBiologyDeck(lang).flashcards;

  const maxCards = 3;
  for (let i = 0; i < maxCards; i++) {
    let concept = '';
    let definition = '';

    if (sentences[i]) {
      const sentence = sentences[i];
      // Try to split on defining terms
      const splitKeywords = [/ refers to /i, / is /i, / are /i, / ay /i, / ang /i, / tinatawag na /i, / tumutukoy sa /i, /:/];
      let splitPoint = -1;
      let matchedKeyword = '';

      for (const regex of splitKeywords) {
        const match = sentence.match(regex);
        if (match && match.index !== undefined) {
          splitPoint = match.index;
          matchedKeyword = match[0];
          break;
        }
      }

      if (splitPoint !== -1) {
        concept = sentence.slice(0, splitPoint).trim();
        definition = sentence.slice(splitPoint + matchedKeyword.length).trim();

        // Clean up Concept length (limit to 3-4 words)
        if (concept.split(/\s+/).length > 4) {
          concept = concept.split(/\s+/).slice(0, 3).join(' ');
        }
        // Capitalize definition first letter
        definition = definition.charAt(0).toUpperCase() + definition.slice(1);
      } else {
        // Fallback split: grab first 3 words as concept
        const words = sentence.split(/\s+/);
        concept = words.slice(0, 3).join(' ');
        definition = sentence;
      }

      // Clean up concept string
      concept = concept.replace(/^--- Page \d+ ---/g, '').trim();
      concept = concept.charAt(0).toUpperCase() + concept.slice(1);

      if (concept.length < 3) {
        concept = defaults[i].concept;
        definition = sentence;
      }
    } else {
      // Pad using default decks
      concept = defaults[i].concept;
      definition = defaults[i].definition;
    }

    flashcards.push({ concept, definition });
  }

  // Generate 3 Multiple-Choice quiz questions using the flashcard terms
  for (let i = 0; i < maxCards; i++) {
    const card = flashcards[i];

    let questionText = '';
    let explanationText = '';

    if (lang === 'taglish') {
      questionText = `Batay sa teksto, ano ang tumutukoy sa: "${card.definition.slice(0, 90)}..."?`;
      explanationText = `Tumpak! Ang sagot ay "${card.concept}". Ito ay tinukoy bilang: ${card.definition}`;
    } else if (lang === 'filipino') {
      questionText = `Ayon sa talata, ano ang kahulugan ng: "${card.definition.slice(0, 90)}..."?`;
      explanationText = `Tama! Ang sagot ay "${card.concept}". Ang kahulugan nito ay: ${card.definition}`;
    } else {
      questionText = `According to the material, what concept refers to: "${card.definition.slice(0, 90)}..."?`;
      explanationText = `Correct! The response is "${card.concept}". It is defined as: ${card.definition}`;
    }

    // Shuffle options using the card concepts
    const options = [card.concept];
    const otherConcepts = flashcards.filter((_, idx) => idx !== i).map(c => c.concept);

    options.push(otherConcepts[0]);
    options.push(otherConcepts[1]);

    // Add a distractor option
    if (lang === 'taglish') {
      options.push('Lahat ng nabanggit');
    } else if (lang === 'filipino') {
      options.push('Wala sa mga pagpipilian');
    } else {
      options.push('None of the above');
    }

    // Shuffle array and track correct index
    const correctVal = card.concept;
    const shuffledOptions = options.sort(() => Math.random() - 0.5);
    const correctIndex = shuffledOptions.indexOf(correctVal);

    quiz.push({
      question: questionText,
      options: shuffledOptions,
      correct_index: correctIndex,
      explanation: explanationText
    });
  }

  return { flashcards, quiz };
}
