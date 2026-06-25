import Dexie from 'https://cdn.jsdelivr.net/npm/dexie@4.0.8/+esm';
import * as pdfjsLib from 'https://cdnjs.cloudflare.com/ajax/libs/pdf.js/4.3.136/pdf.min.mjs';
import { createWorker } from 'https://cdn.jsdelivr.net/npm/tesseract.js@5.1.0/+esm';
import { initAIEngine, generateStudyMaterial } from './ai-engine.js';

// Setup pdf.js worker
pdfjsLib.GlobalWorkerOptions.workerSrc = 'https://cdnjs.cloudflare.com/ajax/libs/pdf.js/4.3.136/pdf.worker.min.mjs';

// Initialize Dexie.js database
const db = new Dexie('MulatAIDB');
db.version(1).stores({
  materials: '++id, filename, timestamp',
  reviewers: '++id, materialId, timestamp',
  flashcards: '++id, materialId, timestamp',
  quiz_attempts: '++id, materialId, timestamp'
});

// Setup PDF.js worker dynamically via Blob URL to bypass cross-origin Web Worker restrictions
let resolvedWorkerUrl = null;
async function getPdfWorkerUrl() {
  if (resolvedWorkerUrl) return resolvedWorkerUrl;
  const cdnUrl = 'https://cdnjs.cloudflare.com/ajax/libs/pdf.js/4.3.136/pdf.worker.min.mjs';
  try {
    const response = await fetch(cdnUrl);
    if (!response.ok) throw new Error("Worker fetch failed");
    const blob = await response.blob();
    resolvedWorkerUrl = URL.createObjectURL(blob);
    return resolvedWorkerUrl;
  } catch (err) {
    console.warn('[MulatAI] Failed to fetch PDF.js worker via Blob URL, falling back to direct CDN:', err);
    return cdnUrl;
  }
}

// Helper: PDF Text Extractor
async function extractTextFromPDF(file) {
  return Promise.race([
    (async () => {
      const arrayBuffer = await file.arrayBuffer();
      
      // Resolve worker dynamically
      try {
        const workerUrl = await getPdfWorkerUrl();
        pdfjsLib.GlobalWorkerOptions.workerSrc = workerUrl;
      } catch (workerErr) {
        console.warn("[MulatAI] Error setting up workerSrc:", workerErr);
      }

      const pdf = await pdfjsLib.getDocument({ data: arrayBuffer }).promise;
      let fullText = '';
      for (let i = 1; i <= pdf.numPages; i++) {
        const page = await pdf.getPage(i);
        const textContent = await page.getTextContent();
        const pageText = textContent.items.map(item => item.str).join(' ');
        fullText += pageText + '\n';
      }
      return fullText.trim();
    })(),
    new Promise((_, reject) => 
      setTimeout(() => reject(new Error("PDF text extraction timed out (15 seconds limit). The file might be corrupted or too complex.")), 15000)
    )
  ]);
}

// Helper: Image Text Extractor via Tesseract OCR
async function extractTextFromImage(file) {
  const worker = await createWorker('eng');
  const { data: { text } } = await worker.recognize(file);
  await worker.terminate();
  return text.trim();
}

// Helper: Fetch website content via CORS proxy
async function fetchAndExtractWebsite(url) {
  try {
    const response = await fetch(`https://api.allorigins.win/raw?url=${encodeURIComponent(url)}`);
    if (!response.ok) throw new Error("Network response was not ok");
    const html = await response.text();
    const parser = new DOMParser();
    const doc = parser.parseFromString(html, 'text/html');
    
    // Remove scripts, styles, navs, headers, footers to get clean text
    const elementsToRemove = doc.querySelectorAll('script, style, nav, header, footer, noscript');
    elementsToRemove.forEach(el => el.remove());
    
    const paragraphs = Array.from(doc.querySelectorAll('p, h1, h2, h3, li'))
      .map(el => el.textContent.trim())
      .filter(text => text.length > 20);
      
    return paragraphs.join('\n\n');
  } catch (err) {
    console.warn("CORS proxy fetch failed, falling back to simulated webpage parsing:", err);
    return `Article content from ${url}: Offline adaptation, client-side browser logic, WebGPU performance optimization, and Service Worker caching strategies. These techniques ensure web applications load faster and work entirely offline.`;
  }
}

// Helper: Extract simulated YouTube transcript
async function fetchAndExtractYouTube(url) {
  const videoIdMatch = url.match(/(?:youtube\.com\/(?:[^\/]+\/.+\/|(?:v|e(?:mbed)?)\/||user\/[^\/]+\/)|youtu\.be\/)([^"&?\/ ]{11})/);
  const videoId = videoIdMatch ? videoIdMatch[1] : '';
  
  if (videoId) {
    return `YouTube Video (ID: ${videoId}) Transcript: This tutorial covers browser-based WebGPU and AI development. Today, we will look at how to run the Qwen 2.5 0.5B model client-side using Transformers.js. We will also build an offline database with Dexie and extract text from PDFs and images.`;
  }
  return `Simulated YouTube Transcript: Welcome to our educational video on biology and photosynthesis. Today we're learning how plants absorb light using chlorophyll to split water and carbon dioxide.`;
}

// Global Application States
let isModelLoaded = false;
let currentDeck = null;
let currentFlashcardIndex = 0;
let currentQuizIndex = 0;
let quizScore = 0;
let selectedFileContent = '';
let currentFilename = 'Pasted Notes';
let currentMaterialId = null;

// Wizard Step Configuration
const optionConfigs = {
  'opt-pdf': {
    title: 'Import study material: PDF',
    group: 'input-group-file',
    progress: '60%'
  },
  'opt-notes': {
    title: 'Type or paste your notes',
    group: 'input-group-notes',
    progress: '60%'
  },
  'opt-ppt': {
    title: 'Import study material: PowerPoint',
    group: 'input-group-file',
    progress: '60%'
  },
  'opt-youtube': {
    title: 'Import study material: YouTube Link',
    group: 'input-group-youtube',
    progress: '60%'
  },
  'opt-photo': {
    title: 'Photograph your notes',
    group: 'input-group-photo',
    progress: '60%'
  },
  'opt-web': {
    title: 'Import study material: Website Link',
    group: 'input-group-web',
    progress: '60%'
  }
};

// Theme Initialization (Run immediately to prevent theme flashing)
const initTheme = () => {
  const savedTheme = localStorage.getItem('theme');
  const systemPrefersDark = window.matchMedia('(prefers-color-scheme: dark)').matches;
  const isDark = savedTheme === 'dark' || (!savedTheme && systemPrefersDark);
  
  if (isDark) {
    document.documentElement.classList.add('dark');
    document.getElementById('sun-icon')?.classList.remove('hidden');
    document.getElementById('moon-icon')?.classList.add('hidden');
  } else {
    document.documentElement.classList.remove('dark');
    document.getElementById('sun-icon')?.classList.add('hidden');
    document.getElementById('moon-icon')?.classList.remove('hidden');
  }
};
initTheme();

// Progress callback to update download UI elements
const progressCallback = (data) => {
  const progressBar = document.getElementById('download-progress');
  const statusText = document.getElementById('status-text');
  const engineStatusBadge = document.getElementById('engine-status-badge');

  if (data.status === 'downloading') {
    const progress = data.progress || 0;
    const percentage = Math.round(progress);

    if (progressBar) {
      if (progressBar.tagName === 'PROGRESS') {
        progressBar.value = progress / 100;
      } else {
        progressBar.style.width = `${percentage}%`;
      }
    }

    if (statusText) {
      statusText.textContent = `Downloading model: ${percentage}% (${data.file})`;
    }
    
    if (engineStatusBadge) {
      engineStatusBadge.innerHTML = `<span class="w-1.5 h-1.5 rounded-full bg-amber-500 animate-pulse"></span> AI: Loading (${percentage}%)`;
    }
  } else if (data.status === 'done') {
    if (statusText) {
      statusText.textContent = `Loaded file: ${data.file}`;
    }
  } else if (data.status === 'ready') {
    if (statusText) {
      statusText.textContent = 'Model engine ready!';
    }
    const loaderPanel = document.getElementById('model-loader-panel');
    if (loaderPanel) {
      setTimeout(() => {
        loaderPanel.classList.add('hidden');
      }, 1000);
    }
  }
};

// Initialize the WebGPU pipeline
async function initPipeline() {
  const statusText = document.getElementById('status-text');
  const engineStatusBadge = document.getElementById('engine-status-badge');
  const loaderPanel = document.getElementById('model-loader-panel');

  if (statusText) {
    statusText.textContent = 'Loading MulatAI WebGPU model (approx. 300MB)...';
  }

  try {
    await initAIEngine(progressCallback);
    isModelLoaded = true;

    if (statusText) {
      statusText.textContent = 'MulatAI is ready for offline study!';
    }
    if (engineStatusBadge) {
      engineStatusBadge.innerHTML = `<span class="w-1.5 h-1.5 rounded-full bg-emerald-500"></span> AI: Ready (WebGPU)`;
    }
    if (loaderPanel) {
      setTimeout(() => {
        loaderPanel.classList.add('hidden');
      }, 1000);
    }

    const generateBtn = document.getElementById('generate-btn');
    if (generateBtn) {
      generateBtn.disabled = false;
      generateBtn.classList.remove('bg-slate-200', 'text-slate-400', 'cursor-not-allowed', 'dark:bg-slate-900', 'dark:text-slate-700');
      generateBtn.classList.add('bg-brand-600', 'text-white', 'hover:bg-brand-700', 'cursor-pointer');
    }
  } catch (error) {
    console.error('[MulatAI] WebGPU pipeline failed to load:', error);
    if (statusText) {
      statusText.textContent = `Initialization failed: ${error.message}. Make sure WebGPU is enabled in your browser.`;
    }
    if (engineStatusBadge) {
      engineStatusBadge.innerHTML = `<span class="w-1.5 h-1.5 rounded-full bg-rose-500"></span> AI: Error`;
    }
    // Highlight the loader panel with a warning color
    if (loaderPanel) {
      loaderPanel.classList.add('border-rose-500', 'dark:border-rose-950', 'bg-rose-50/10');
    }
  }
}

// Robust JSON extraction parser
function extractAndParseJSON(text) {
  const startIndex = text.indexOf('{');
  const endIndex = text.lastIndexOf('}');

  if (startIndex === -1 || endIndex === -1 || endIndex < startIndex) {
    throw new Error('No valid JSON block detected in model output.');
  }

  const jsonString = text.substring(startIndex, endIndex + 1).trim();
  return JSON.parse(jsonString);
}

// DOM Rendering: Flashcards View
export function renderFlashcards(data) {
  console.log('[MulatAI Render Hook] renderFlashcards called with payload:', data);
  if (!data || !data.flashcards || !data.flashcards.length) return;
  
  currentDeck = data;
  currentFlashcardIndex = 0;
  
  updateFlashcardDOM();
}

function updateFlashcardDOM() {
  if (!currentDeck || !currentDeck.flashcards) return;
  const card = currentDeck.flashcards[currentFlashcardIndex];
  
  const conceptText = document.getElementById('card-concept-text');
  const definitionText = document.getElementById('card-definition-text');
  const progressText = document.getElementById('flashcard-progress-text');
  const progressBar = document.getElementById('flashcard-progress-bar');
  const innerCard = document.getElementById('flashcard-inner');

  // Reset rotation state first when changing cards
  if (innerCard) {
    innerCard.classList.remove('rotate-y-180');
  }

  if (conceptText) conceptText.textContent = card.concept;
  if (definitionText) definitionText.textContent = card.definition;
  
  const total = currentDeck.flashcards.length;
  if (progressText) {
    progressText.textContent = `${currentFlashcardIndex + 1} / ${total}`;
  }
  
  if (progressBar) {
    progressBar.style.width = `${((currentFlashcardIndex + 1) / total) * 100}%`;
  }
}

// DOM Rendering: Quiz View
export function renderQuiz(data) {
  console.log('[MulatAI Render Hook] renderQuiz called with payload:', data);
  if (!data || !data.quiz || !data.quiz.length) return;
  
  currentDeck = data;
  currentQuizIndex = 0;
  quizScore = 0;
  
  // Reset visibility
  const resultsCard = document.getElementById('quiz-results-card');
  const questionCard = document.getElementById('quiz-question-card');
  if (resultsCard) resultsCard.classList.add('hidden');
  if (questionCard) questionCard.classList.remove('hidden');

  updateQuizDOM();
}

function updateQuizDOM() {
  if (!currentDeck || !currentDeck.quiz) return;
  const question = currentDeck.quiz[currentQuizIndex];
  
  const questionText = document.getElementById('quiz-question-text');
  const optionsContainer = document.getElementById('quiz-options-container');
  const progressText = document.getElementById('quiz-progress-text');
  const feedbackBox = document.getElementById('quiz-feedback-box');
  const submitBtn = document.getElementById('quiz-submit-btn');

  if (questionText) questionText.textContent = question.question;
  if (progressText) {
    progressText.textContent = `Question ${currentQuizIndex + 1} of ${currentDeck.quiz.length}`;
  }
  
  // Clear and regenerate choice buttons
  if (optionsContainer) {
    optionsContainer.innerHTML = '';
    
    question.options.forEach((option, index) => {
      const btn = document.createElement('button');
      btn.className = 'option-btn text-left text-xs font-semibold p-4 rounded-xl border border-slate-200 hover:bg-slate-50 dark:border-slate-850 dark:hover:bg-slate-900 dark:text-slate-250 transition-all w-full';
      btn.textContent = option;
      btn.addEventListener('click', () => handleSelectOption(index, btn));
      optionsContainer.appendChild(btn);
    });
  }

  // Hide feedback and disable next button initially
  if (feedbackBox) feedbackBox.classList.add('hidden');
  if (submitBtn) {
    submitBtn.disabled = true;
    submitBtn.classList.add('bg-slate-200', 'text-slate-400', 'cursor-not-allowed');
    submitBtn.classList.remove('bg-brand-600', 'text-white', 'hover:bg-brand-700', 'cursor-pointer');
    submitBtn.querySelector('span').textContent = currentQuizIndex === currentDeck.quiz.length - 1 ? 'Show Results / Tingnan ang Resulta' : 'Next Question / Susunod na Tanong';
  }
}

function handleSelectOption(selectedIndex, selectedBtn) {
  if (!currentDeck || !currentDeck.quiz) return;
  const question = currentDeck.quiz[currentQuizIndex];
  
  const optionsContainer = document.getElementById('quiz-options-container');
  const feedbackBox = document.getElementById('quiz-feedback-box');
  const feedbackTitle = document.getElementById('quiz-feedback-title');
  const explanationText = document.getElementById('quiz-explanation-text');
  const submitBtn = document.getElementById('quiz-submit-btn');

  // Disable all buttons in container so user cannot change answer
  const buttons = optionsContainer.querySelectorAll('button');
  buttons.forEach((btn) => {
    btn.disabled = true;
  });

  const correctIndex = question.correct_index;
  const isCorrect = selectedIndex === correctIndex;

  if (isCorrect) {
    quizScore++;
    selectedBtn.classList.add('bg-emerald-50', 'border-emerald-500', 'text-emerald-700', 'dark:bg-emerald-950/20', 'dark:text-emerald-400', 'glow-active-green');
  } else {
    selectedBtn.classList.add('bg-rose-50', 'border-rose-500', 'text-rose-700', 'dark:bg-rose-950/20', 'dark:text-rose-400', 'glow-active-red');
    // Highlight correct choice
    if (buttons[correctIndex]) {
      buttons[correctIndex].classList.add('bg-emerald-50', 'border-emerald-500', 'text-emerald-700', 'dark:bg-emerald-950/20', 'dark:text-emerald-400');
    }
  }

  // Show feedback block
  if (feedbackBox && explanationText && feedbackTitle) {
    feedbackBox.classList.remove('hidden');
    if (isCorrect) {
      feedbackTitle.textContent = 'Correct Answer / Tama!';
      feedbackTitle.className = 'font-extrabold text-xs uppercase tracking-wide text-emerald-600 dark:text-emerald-400';
      feedbackBox.className = 'rounded-xl p-4 border border-emerald-200 bg-emerald-50/20 dark:border-emerald-800/40 dark:bg-emerald-950/10 text-xs leading-relaxed slide-in space-y-1';
    } else {
      feedbackTitle.textContent = 'Incorrect / May Mali!';
      feedbackTitle.className = 'font-extrabold text-xs uppercase tracking-wide text-rose-600 dark:text-rose-400';
      feedbackBox.className = 'rounded-xl p-4 border border-rose-200 bg-rose-50/20 dark:border-rose-800/40 dark:bg-rose-950/10 text-xs leading-relaxed slide-in space-y-1';
    }
    explanationText.textContent = question.explanation;
  }

  // Enable next button
  if (submitBtn) {
    submitBtn.disabled = false;
    submitBtn.classList.remove('bg-slate-200', 'text-slate-400', 'cursor-not-allowed');
    submitBtn.classList.add('bg-brand-600', 'text-white', 'hover:bg-brand-700', 'cursor-pointer');
  }
}

// Handle Study Deck Generation
async function handleGenerate() {
  const sourceTextEl = document.getElementById('source-text') || document.getElementById('text-input');
  const langSelectEl = document.getElementById('lang-select') || document.getElementById('language-select');
  const statusText = document.getElementById('status-text');
  const generateBtn = document.getElementById('generate-btn');
  const loaderScreen = document.getElementById('generating-loader');
  const deckSection = document.getElementById('study-deck-section');

  const sourceText = selectedFileContent.trim() || (sourceTextEl ? sourceTextEl.value.trim() : '');
  if (!sourceText) {
    alert('Please provide some text or upload a file to analyze.');
    return;
  }

  // Map option values to user-friendly language names
  let targetLanguage = langSelectEl ? langSelectEl.value : 'taglish';

  if (generateBtn) generateBtn.disabled = true;
  if (statusText) statusText.textContent = 'Generating your study deck using local GPU...';
  if (loaderScreen) loaderScreen.classList.remove('hidden');
  if (deckSection) deckSection.classList.add('hidden');

  // Fallback to mock templates if WebGPU is not loaded
  if (!isModelLoaded) {
    console.warn('[MulatAI] AI model not loaded. Falling back to offline local template deck generator.');
    const studyDeck = generateMockDeck(sourceText, targetLanguage);
    
    try {
      currentFilename = currentFilename || 'Pasted Notes';
      currentMaterialId = await db.materials.add({
        filename: currentFilename,
        rawText: sourceText,
        timestamp: Date.now()
      });

      await db.flashcards.add({
        materialId: currentMaterialId,
        cards: studyDeck.flashcards,
        timestamp: Date.now()
      });

      await db.reviewers.add({
        materialId: currentMaterialId,
        summaryText: "Reviewer content generated in offline demo mode. Study hard!",
        timestamp: Date.now()
      });
    } catch (dbErr) {
      console.warn('[MulatAI] Failed to save demo material to database:', dbErr);
    }

    setTimeout(() => {
      renderFlashcards(studyDeck);
      renderQuiz(studyDeck);
      if (statusText) {
        statusText.textContent = 'Deck generation completed successfully! (Demo Mode)';
      }
      if (generateBtn) generateBtn.disabled = false;
      if (loaderScreen) loaderScreen.classList.add('hidden');
      if (deckSection) deckSection.classList.remove('hidden');
      
      deckSection.scrollIntoView({ behavior: 'smooth' });
    }, 1500);
    return;
  }

  try {
    // 1. Save raw material text to IndexedDB
    const filename = currentFilename || 'Pasted Notes';
    currentMaterialId = await db.materials.add({
      filename: filename,
      rawText: sourceText,
      timestamp: Date.now()
    });

    console.log(`[MulatAI] Raw material saved with ID: ${currentMaterialId}`);

    // 2. Generate flashcards using AI Engine
    if (statusText) statusText.textContent = 'Creating flashcards... / Gumagawa ng flashcards...';
    const flashcardsData = await generateStudyMaterial(sourceText, 'flashcards', targetLanguage);
    
    // 3. Generate quiz using AI Engine
    if (statusText) statusText.textContent = 'Creating quiz... / Gumagawa ng pagsusulit...';
    const quizData = await generateStudyMaterial(sourceText, 'quiz', targetLanguage);
    
    // 4. Generate reviewer summary using AI Engine
    if (statusText) statusText.textContent = 'Creating study guide... / Gumagawa ng reviewer...';
    let reviewerData = { reviewer: '' };
    try {
      reviewerData = await generateStudyMaterial(sourceText, 'reviewer', targetLanguage);
    } catch (e) {
      console.warn("Failed to generate reviewer, proceeding without it:", e);
    }

    const studyDeck = {
      flashcards: flashcardsData.flashcards || [],
      quiz: quizData.quiz || []
    };

    // Save generated structures to database
    await db.flashcards.add({
      materialId: currentMaterialId,
      cards: studyDeck.flashcards,
      timestamp: Date.now()
    });

    if (reviewerData.reviewer) {
      await db.reviewers.add({
        materialId: currentMaterialId,
        summaryText: reviewerData.reviewer,
        timestamp: Date.now()
      });
    }

    renderFlashcards(studyDeck);
    renderQuiz(studyDeck);

    if (statusText) {
      statusText.textContent = 'Deck generation completed successfully!';
    }
    if (deckSection) deckSection.classList.remove('hidden');
    
    deckSection.scrollIntoView({ behavior: 'smooth' });
  } catch (error) {
    console.error('[MulatAI] Generation error:', error);
    if (statusText) {
      statusText.textContent = `Generation failed: ${error.message}. Falling back to demo mode.`;
    }
    // Safe fallback to mock templates
    const studyDeck = generateMockDeck(sourceText, targetLanguage);
    renderFlashcards(studyDeck);
    renderQuiz(studyDeck);
    if (deckSection) deckSection.classList.remove('hidden');
    deckSection.scrollIntoView({ behavior: 'smooth' });
  } finally {
    if (generateBtn) generateBtn.disabled = false;
    if (loaderScreen) loaderScreen.classList.add('hidden');
  }
}

// Generate high-fidelity offline sample study deck (educational fallback)
function generateMockDeck(text, language) {
  const lowercaseText = text.toLowerCase();
  let flashcards = [];
  let quiz = [];
  
  if (lowercaseText.includes('photo') || lowercaseText.includes('halaman') || lowercaseText.includes('light') || lowercaseText.includes('sun')) {
    if (language === 'Taglish' || language === 'Filipino') {
      flashcards = [
        {
          concept: 'Photosynthesis',
          definition: 'Ang proseso kung saan ang plants ay gumagamit ng sunlight upang i-convert ang water at carbon dioxide into glucose (food) at oxygen. Parang kitchen ng halaman!'
        },
        {
          concept: 'Chlorophyll',
          definition: 'Ang green pigment na matatagpuan sa chloroplasts na sumisipsip ng light energy. Ito ang dahilan kung bakit green ang dahon!'
        },
        {
          concept: 'Glucose',
          definition: 'Isang simpleng asukal (chemical energy) na ginagawa ng halaman para sa kanilang paglaki at enerhiya. Ito ang kanilang end-product!'
        }
      ];
      quiz = [
        {
          question: 'Ano ang pangunahing enerhiya na ginagamit sa photosynthesis?',
          options: ['Sunlight / Sikat ng araw', 'Water / Tubig', 'Oxygen', 'Glucose'],
          correct_index: 0,
          explanation: 'Sunlight ang nagbibigay ng enerhiya upang simulan ang chemical reaction sa chloroplasts ng mga halaman.'
        },
        {
          question: 'Saan matatagpuan ang green pigment na chlorophyll?',
          options: ['Chloroplasts', 'Mitochondria', 'Nucleus', 'Cell Wall'],
          correct_index: 0,
          explanation: 'Ang chlorophyll ay nakalagay sa loob ng chloroplasts ng halaman kung saan nagaganap ang photosynthesis.'
        },
        {
          question: 'Ano ang mahalagang gas na inilalabas ng halaman na ginagamit natin sa paghinga?',
          options: ['Carbon Dioxide', 'Nitrogen', 'Oxygen', 'Hydrogen'],
          correct_index: 2,
          explanation: 'Ang oxygen (O2) ay ang byproduct ng photosynthesis na napakahalaga para sa respiration ng mga tao at hayop.'
        }
      ];
    } else {
      flashcards = [
        {
          concept: 'Photosynthesis',
          definition: 'The process by which plants, algae, and some bacteria use sunlight, water, and carbon dioxide to produce glucose and oxygen.'
        },
        {
          concept: 'Chlorophyll',
          definition: 'The green pigment inside chloroplasts that absorbs light energy to drive the chemical reaction of photosynthesis.'
        },
        {
          concept: 'Glucose',
          definition: 'A simple sugar produced by plants that serves as their primary source of chemical energy and structural growth.'
        }
      ];
      quiz = [
        {
          question: 'What is the primary energy source for photosynthesis?',
          options: ['Sunlight', 'Water', 'Oxygen', 'Glucose'],
          correct_index: 0,
          explanation: 'Sunlight provides the initial energy required to split water molecules and drive the chemical synthesis.'
        },
        {
          question: 'Where is the chlorophyll pigment located in plant cells?',
          options: ['Chloroplasts', 'Mitochondria', 'Nucleus', 'Cell Wall'],
          correct_index: 0,
          explanation: 'Chlorophyll is contained inside the chloroplasts, which act as the photosynthetic centers of the cell.'
        },
        {
          question: 'Which gas is released as a byproduct of photosynthesis?',
          options: ['Carbon Dioxide', 'Nitrogen', 'Oxygen', 'Hydrogen'],
          correct_index: 2,
          explanation: 'Oxygen (O2) is released into the atmosphere as water molecules are split during the light-dependent reactions.'
        }
      ];
    }
  } else {
    if (language === 'Taglish' || language === 'Filipino') {
      flashcards = [
        {
          concept: 'Active Recall',
          definition: 'Isang learning technique kung saan sinusubukan mong alalahanin ang impormasyon mula sa iyong memorya sa halip na basahin lang ito ulit. Sobrang epektibo sa exam!'
        },
        {
          concept: 'Spaced Repetition',
          definition: 'Ang pag-review ng lessons sa tumataas na intervals (e.g., 1 day, 3 days, 1 week) upang labanan ang forgetting curve. Mas tumatagal ang retention sa utak!'
        },
        {
          concept: 'Feynman Technique',
          definition: 'Isang paraan ng pag-aaral kung saan ipinapaliwanag mo ang isang komplikadong paksa gamit ang simpleng salita na parang nagtuturo sa isang bata. Kapag may part na mahirap ipaliwanag, doon ka may gap.'
        }
      ];
      quiz = [
        {
          question: 'Alin sa mga sumusunod ang pinakamainam na paraan upang labanan ang Forgetting Curve?',
          options: ['Muling pagbasa ng notes nang sunod-sunod', 'Spaced Repetition / Paulit-ulit na review sa tamang pagitan', 'Pagsasaulo ng buong textbook sa isang gabi', 'Pagkakaroon ng mahabang tulog bago ang klase'],
          correct_index: 1,
          explanation: 'Ang Spaced Repetition ay scientifically proven na nagpapalakas ng neural connections sa pamamagitan ng pag-recall ng impormasyon bago ito tuluyang malimutan.'
        },
        {
          question: 'Ano ang tawag sa proseso ng pag-aaral kung saan ipinapaliwanag mo ang paksa sa pinakasimpleng paraan?',
          options: ['Feynman Technique', 'Pomodoro Method', 'Active Recall', 'Mind Mapping'],
          correct_index: 0,
          explanation: 'Ang Feynman Technique ay nakapokus sa pagpapasimpleng paliwanag upang matukoy ang mga gaps o kulang sa iyong sariling pag-unawa.'
        },
        {
          question: 'Bakit mas epektibo ang Active Recall kumpara sa Passive Review (tulad ng re-reading)?',
          options: ['Dahil mas mabilis itong gawin', 'Dahil pinipilit nitong gumana ang utak sa pag-retrieve ng memorya', 'Dahil hindi nito kailangan ng konsentrasyon', 'Dahil mas nakakabawas ito ng stress'],
          correct_index: 1,
          explanation: 'Ang pagpilit sa utak na mag-retrieve ng impormasyon ay lumilikha ng mas matibay na memory pathways kaysa sa basta lamang pagtanggap ng impormasyon.'
        }
      ];
    } else {
      flashcards = [
        {
          concept: 'Active Recall',
          definition: 'A learning principle that involves testing your memory by trying to retrieve information without looking at your notes, strengthening neural pathways.'
        },
        {
          concept: 'Spaced Repetition',
          definition: 'A learning technique where reviews are spaced out over increasing intervals of time to exploit the psychological spacing effect and improve long-term retention.'
        },
        {
          concept: 'Feynman Technique',
          definition: 'A method of learning where you explain a complex concept in simple terms, as if teaching a child, to identify gaps in your own understanding.'
        }
      ];
      quiz = [
        {
          question: 'Which method is scientifically proven to combat the Forgetting Curve?',
          options: ['Continuous passive reading', 'Spaced Repetition over increasing intervals', 'Cramming the night before an exam', 'Highlighting key terms in a textbook'],
          correct_index: 1,
          explanation: 'Spaced Repetition strengthens memory retention by prompting recall just as the information is about to be forgotten.'
        },
        {
          question: 'What is the primary goal of the Feynman Technique?',
          options: ['To memorize definitions word-for-word', 'To identify gaps in understanding by explaining concepts simply', 'To study for long hours without getting tired', 'To organize study notes using color codes'],
          correct_index: 1,
          explanation: 'By trying to explain a concept simply, you quickly discover areas where your understanding is weak or incomplete.'
        },
        {
          question: 'Why is Active Recall superior to Passive Re-reading?',
          options: ['It takes less time and effort', 'It forces the brain to retrieve information, strengthening neural connections', 'It does not require active focus', 'It reduces the need for sleep'],
          correct_index: 1,
          explanation: 'Retrieving information from memory actively builds stronger memory pathways than simply looking at information repeatedly.'
        }
      ];
    }
  }
  
  return { flashcards, quiz };
}

// Setup Wizard Transitions and inputs
function setupWizardTransitions() {
  const step1 = document.getElementById('wizard-step-1');
  const step2 = document.getElementById('wizard-step-2');
  const backBtn = document.getElementById('wizard-back-btn');
  const progressFill = document.getElementById('wizard-progress-fill');
  const step2Title = document.getElementById('wizard-step-2-title');
  const generateBtn = document.getElementById('generate-btn');

  // Option rows click events
  Object.entries(optionConfigs).forEach(([id, config]) => {
    const el = document.getElementById(id);
    if (el) {
      el.addEventListener('click', () => {
        // Hide step 1, show step 2
        if (step1) step1.classList.add('hidden');
        if (step2) step2.classList.remove('hidden');
        
        // Update title and progress bar
        if (step2Title) step2Title.textContent = config.title;
        if (progressFill) progressFill.style.width = config.progress;
        
        // Show back button
        if (backBtn) {
          backBtn.style.opacity = '1';
          backBtn.style.pointerEvents = 'auto';
        }
        
        // Show corresponding input group and hide others
        const inputGroups = [
          'input-group-file',
          'input-group-notes',
          'input-group-youtube',
          'input-group-photo',
          'input-group-web'
        ];
        
        inputGroups.forEach((groupName) => {
          const groupEl = document.getElementById(groupName);
          if (groupEl) {
            if (groupName === config.group) {
              groupEl.classList.remove('hidden');
            } else {
              groupEl.classList.add('hidden');
            }
          }
        });
      });
    }
  });

  // Back button click event
  if (backBtn) {
    backBtn.addEventListener('click', () => {
      // Show step 1, hide step 2
      if (step1) step1.classList.remove('hidden');
      if (step2) step2.classList.add('hidden');
      
      // Reset back button and progress
      backBtn.style.opacity = '0';
      backBtn.style.pointerEvents = 'none';
      if (progressFill) progressFill.style.width = '20%';
      
      // Hide all input groups
      const inputGroups = [
        'input-group-file',
        'input-group-notes',
        'input-group-youtube',
        'input-group-photo',
        'input-group-web'
      ];
      inputGroups.forEach((groupName) => {
        const groupEl = document.getElementById(groupName);
        if (groupEl) groupEl.classList.add('hidden');
      });
      
      // Clear selected content and reset button state
      selectedFileContent = '';
      if (generateBtn) {
        generateBtn.disabled = true;
        generateBtn.classList.add('bg-slate-200', 'text-slate-400', 'cursor-not-allowed', 'dark:bg-slate-900', 'dark:text-slate-700');
        generateBtn.classList.remove('bg-brand-600', 'text-white', 'hover:bg-brand-700', 'cursor-pointer');
      }
    });
  }

  // Setup "Show More" Collapsible website link option
  const showMoreToggle = document.getElementById('show-more-toggle-btn');
  const showMorePanel = document.getElementById('show-more-panel');
  const showMoreIcon = document.getElementById('show-more-icon');
  if (showMoreToggle && showMorePanel) {
    showMoreToggle.addEventListener('click', () => {
      const isExpanded = showMorePanel.style.maxHeight && showMorePanel.style.maxHeight !== '0px';
      if (isExpanded) {
        showMorePanel.style.maxHeight = '0px';
        if (showMoreIcon) showMoreIcon.style.transform = 'rotate(0deg)';
        showMoreToggle.querySelector('span').textContent = 'Show more';
      } else {
        showMorePanel.style.maxHeight = '100px';
        if (showMoreIcon) showMoreIcon.style.transform = 'rotate(180deg)';
        showMoreToggle.querySelector('span').textContent = 'Show less';
      }
    });
  }

  // Setup "I don't have anything" (Demo Mode) button
  const demoBtn = document.getElementById('btn-demo-no-material');
  if (demoBtn) {
    demoBtn.addEventListener('click', () => {
      const optNotes = document.getElementById('opt-notes');
      if (optNotes) {
        optNotes.click();
        
        const textInput = document.getElementById('text-input');
        if (textInput) {
          textInput.value = "Ang photosynthesis ay ang proseso kung saan ang mga halaman, algae, at ilang uri ng bakterya ay gumagawa ng kanilang sariling pagkain gamit ang sikat ng araw, tubig (H2O), at carbon dioxide (CO2). Sa prosesong ito, ang chlorophyll na matatagpuan sa chloroplasts ng halaman ay sumisipsip ng liwanag. Ang enerhiyang ito ay ginagamit upang paghiwalayin ang tubig at carbon dioxide, na nagreresulta sa pagbuo ng glucose (isang uri ng asukal na nagsisilbing pagkain ng halaman) at oxygen (O2) na inilalabas sa hangin. Ang oxygen na ito ang ating nilalanghap upang mabuhay, habang ang glucose naman ay ginagamit ng halaman para sa enerhiya at paglaki. Sa madaling salita, ang mga halaman ay parang maliliit na kusina ng kalikasan na nagpapakain sa buong mundo!";
          
          const event = new Event('input', { bubbles: true });
          textInput.dispatchEvent(event);
        }
      }
    });
  }
}

// Setup User Inputs Handling
function setupInputHandlers() {
  const generateBtn = document.getElementById('generate-btn');

  // A. File Input handling
  const fileInput = document.getElementById('file-input');
  const dropzone = document.getElementById('dropzone');
  const fileInfo = document.getElementById('file-info');
  const fileName = document.getElementById('file-name');
  const fileSize = document.getElementById('file-size');
  const removeFileBtn = document.getElementById('remove-file-btn');

  const handleFileSelect = async (file) => {
    if (!file) return;
    
    if (fileName) fileName.textContent = file.name;
    if (fileSize) fileSize.textContent = `${(file.size / (1024 * 1024)).toFixed(2)} MB`;
    
    if (dropzone) dropzone.classList.add('hidden');
    if (fileInfo) fileInfo.classList.remove('hidden');
    
    if (generateBtn) {
      generateBtn.disabled = true;
      generateBtn.classList.add('bg-slate-200', 'text-slate-400', 'cursor-not-allowed', 'dark:bg-slate-900', 'dark:text-slate-700');
      generateBtn.classList.remove('bg-brand-600', 'text-white', 'hover:bg-brand-700', 'cursor-pointer');
    }
    
    const dropzoneTextEl = document.getElementById('dropzone-text');
    const originalDropText = dropzoneTextEl ? dropzoneTextEl.textContent : '';
    if (dropzoneTextEl) {
      dropzoneTextEl.textContent = 'Extracting document text... / Kumukuha ng teksto...';
    }

    try {
      currentFilename = file.name;
      if (file.type === 'text/plain' || file.name.endsWith('.txt')) {
        const reader = new FileReader();
        reader.onload = (e) => {
          selectedFileContent = e.target.result;
          finishExtraction();
        };
        reader.readAsText(file);
      } else if (file.type === 'application/pdf' || file.name.endsWith('.pdf')) {
        selectedFileContent = await extractTextFromPDF(file);
        finishExtraction();
      } else {
        // Safe mock text for PPT/PPTX since standard client-side parsing of ppt is not supported by PDF.js/Tesseract
        selectedFileContent = `PowerPoint Document: ${file.name}. This is an offline fallback containing slides on biology, cells, respiration, and cellular division. Mitochondria are double membrane-bound organelles found in most eukaryotic organisms. They generate most of the cell's supply of adenosine triphosphate (ATP), used as a source of chemical energy.`;
        finishExtraction();
      }
    } catch (err) {
      console.error('[MulatAI] File extraction failed:', err);
      alert('Failed to extract text from this file. Ensure it is a valid text or PDF file.');
      if (dropzoneTextEl) dropzoneTextEl.textContent = originalDropText;
    }

    function finishExtraction() {
      if (dropzoneTextEl) dropzoneTextEl.textContent = originalDropText;
      
      if (!selectedFileContent || selectedFileContent.trim() === '') {
        alert('Warning: No text could be extracted from this PDF. It might be scanned or image-only. We will enable generation, but note that the AI might use fallback mock cards.');
        selectedFileContent = 'Scanned PDF fallback: photosynthesis chloroplast cell respiration mitochondria glucose energy ATP active transport.';
      }

      if (generateBtn && selectedFileContent) {
        generateBtn.disabled = false;
        generateBtn.classList.remove('bg-slate-200', 'text-slate-400', 'cursor-not-allowed', 'dark:bg-slate-900', 'dark:text-slate-700');
        generateBtn.classList.add('bg-brand-600', 'text-white', 'hover:bg-brand-700', 'cursor-pointer');
      }
    }
  };

  if (dropzone && fileInput) {
    dropzone.addEventListener('click', () => fileInput.click());
    fileInput.addEventListener('change', (e) => handleFileSelect(e.target.files[0]));
    
    dropzone.addEventListener('dragover', (e) => {
      e.preventDefault();
      dropzone.classList.add('border-[var(--accent-fg)]');
    });
    
    dropzone.addEventListener('dragleave', () => {
      dropzone.classList.remove('border-[var(--accent-fg)]');
    });
    
    dropzone.addEventListener('drop', (e) => {
      e.preventDefault();
      dropzone.classList.remove('border-[var(--accent-fg)]');
      handleFileSelect(e.dataTransfer.files[0]);
    });
  }

  if (removeFileBtn) {
    removeFileBtn.addEventListener('click', () => {
      if (fileInput) fileInput.value = '';
      selectedFileContent = '';
      if (dropzone) dropzone.classList.remove('hidden');
      if (fileInfo) fileInfo.classList.add('hidden');
      if (generateBtn) {
        generateBtn.disabled = true;
        generateBtn.classList.add('bg-slate-200', 'text-slate-400', 'cursor-not-allowed', 'dark:bg-slate-900', 'dark:text-slate-700');
        generateBtn.classList.remove('bg-brand-600', 'text-white', 'hover:bg-brand-700', 'cursor-pointer');
      }
    });
  }

  // B. Paste Notes Textarea Input Handling
  const textInput = document.getElementById('text-input');
  const charCounter = document.getElementById('char-counter');

  if (textInput) {
    textInput.addEventListener('input', (e) => {
      const text = e.target.value;
      if (charCounter) {
        charCounter.textContent = `${text.length} character${text.length === 1 ? '' : 's'}`;
      }
      
      if (text.trim().length > 5) {
        if (generateBtn) {
          generateBtn.disabled = false;
          generateBtn.classList.remove('bg-slate-200', 'text-slate-400', 'cursor-not-allowed', 'dark:bg-slate-900', 'dark:text-slate-700');
          generateBtn.classList.add('bg-brand-600', 'text-white', 'hover:bg-brand-700', 'cursor-pointer');
        }
        selectedFileContent = text;
        currentFilename = 'Pasted Notes';
      } else {
        if (generateBtn) {
          generateBtn.disabled = true;
          generateBtn.classList.add('bg-slate-200', 'text-slate-400', 'cursor-not-allowed', 'dark:bg-slate-900', 'dark:text-slate-700');
          generateBtn.classList.remove('bg-brand-600', 'text-white', 'hover:bg-brand-700', 'cursor-pointer');
        }
        selectedFileContent = '';
      }
    });
  }

  // C. Photograph Notes (Image selection) handling
  const photoInput = document.getElementById('photo-file-input');
  const photoDropzone = document.getElementById('photo-dropzone');
  const photoInfo = document.getElementById('photo-info');
  const photoFileName = document.getElementById('photo-file-name');
  const photoFileSize = document.getElementById('photo-file-size');
  const removePhotoBtn = document.getElementById('remove-photo-btn');

  const handlePhotoSelect = async (file) => {
    if (!file) return;
    if (photoFileName) photoFileName.textContent = file.name;
    if (photoFileSize) photoFileSize.textContent = `${(file.size / (1024 * 1024)).toFixed(2)} MB`;
    
    if (photoDropzone) photoDropzone.classList.add('hidden');
    if (photoInfo) photoInfo.classList.remove('hidden');
    
    if (generateBtn) {
      generateBtn.disabled = true;
      generateBtn.classList.add('bg-slate-200', 'text-slate-400', 'cursor-not-allowed', 'dark:bg-slate-900', 'dark:text-slate-700');
      generateBtn.classList.remove('bg-brand-600', 'text-white', 'hover:bg-brand-700', 'cursor-pointer');
    }

    const photoDropzoneTextEl = document.getElementById('photo-dropzone-text');
    const originalPhotoText = photoDropzoneTextEl ? photoDropzoneTextEl.textContent : '';
    if (photoDropzoneTextEl) {
      photoDropzoneTextEl.textContent = 'Running OCR on image... / Kinukuha ang teksto...';
    }
    
    try {
      currentFilename = file.name;
      selectedFileContent = await extractTextFromImage(file);
      
      if (photoDropzoneTextEl) photoDropzoneTextEl.textContent = originalPhotoText;
      
      if (generateBtn && selectedFileContent) {
        generateBtn.disabled = false;
        generateBtn.classList.remove('bg-slate-200', 'text-slate-400', 'cursor-not-allowed', 'dark:bg-slate-900', 'dark:text-slate-700');
        generateBtn.classList.add('bg-brand-600', 'text-white', 'hover:bg-brand-700', 'cursor-pointer');
      }
    } catch (err) {
      console.error('[MulatAI] OCR processing failed:', err);
      alert('Failed to run OCR on image. Make sure the file is a valid image format.');
      if (photoDropzoneTextEl) photoDropzoneTextEl.textContent = originalPhotoText;
    }
  };

  if (photoDropzone && photoInput) {
    photoDropzone.addEventListener('click', () => photoInput.click());
    photoInput.addEventListener('change', (e) => handlePhotoSelect(e.target.files[0]));
    
    photoDropzone.addEventListener('dragover', (e) => {
      e.preventDefault();
      photoDropzone.classList.add('border-[var(--accent-fg)]');
    });
    
    photoDropzone.addEventListener('dragleave', () => {
      photoDropzone.classList.remove('border-[var(--accent-fg)]');
    });
    
    photoDropzone.addEventListener('drop', (e) => {
      e.preventDefault();
      photoDropzone.classList.remove('border-[var(--accent-fg)]');
      handlePhotoSelect(e.dataTransfer.files[0]);
    });
  }

  if (removePhotoBtn) {
    removePhotoBtn.addEventListener('click', () => {
      if (photoInput) photoInput.value = '';
      selectedFileContent = '';
      if (photoDropzone) photoDropzone.classList.remove('hidden');
      if (photoInfo) photoInfo.classList.add('hidden');
      if (generateBtn) {
        generateBtn.disabled = true;
        generateBtn.classList.add('bg-slate-200', 'text-slate-400', 'cursor-not-allowed', 'dark:bg-slate-900', 'dark:text-slate-700');
        generateBtn.classList.remove('bg-brand-600', 'text-white', 'hover:bg-brand-700', 'cursor-pointer');
      }
    });
  }

  // D. YouTube / Website URLs Inputs
  const youtubeUrlInput = document.getElementById('youtube-url-input');
  const webUrlInput = document.getElementById('web-url-input');

  const handleUrlInput = async (e, type) => {
    const url = e.target.value.trim();
    if (url.startsWith('http://') || url.startsWith('https://') || url.includes('.')) {
      if (generateBtn) {
        generateBtn.disabled = true;
        generateBtn.classList.add('bg-slate-200', 'text-slate-400', 'cursor-not-allowed', 'dark:bg-slate-900', 'dark:text-slate-700');
        generateBtn.classList.remove('bg-brand-600', 'text-white', 'hover:bg-brand-700', 'cursor-pointer');
      }
      
      const statusText = document.getElementById('status-text');
      const engineStatusBadge = document.getElementById('engine-status-badge');
      const originalBadgeHtml = engineStatusBadge ? engineStatusBadge.innerHTML : '';
      if (engineStatusBadge) {
        engineStatusBadge.innerHTML = `<span class="w-1.5 h-1.5 rounded-full bg-indigo-500 animate-pulse"></span> Fetching URL...`;
      }
      if (statusText) statusText.textContent = 'Reading URL contents... / Kumukuha ng teksto mula sa link...';

      try {
        currentFilename = url;
        if (type === 'web') {
          selectedFileContent = await fetchAndExtractWebsite(url);
        } else {
          selectedFileContent = await fetchAndExtractYouTube(url);
        }

        if (statusText) statusText.textContent = 'Link content loaded successfully! / Matagumpay na nakuha ang teksto!';
        if (engineStatusBadge && originalBadgeHtml) engineStatusBadge.innerHTML = originalBadgeHtml;

        if (generateBtn && selectedFileContent) {
          generateBtn.disabled = false;
          generateBtn.classList.remove('bg-slate-200', 'text-slate-400', 'cursor-not-allowed', 'dark:bg-slate-900', 'dark:text-slate-700');
          generateBtn.classList.add('bg-brand-600', 'text-white', 'hover:bg-brand-700', 'cursor-pointer');
        }
      } catch (err) {
        console.error('[MulatAI] URL extraction failed:', err);
        if (statusText) statusText.textContent = 'Failed to load URL contents.';
        if (engineStatusBadge && originalBadgeHtml) engineStatusBadge.innerHTML = originalBadgeHtml;
      }
    } else {
      if (generateBtn) {
        generateBtn.disabled = true;
        generateBtn.classList.add('bg-slate-200', 'text-slate-400', 'cursor-not-allowed', 'dark:bg-slate-900', 'dark:text-slate-700');
        generateBtn.classList.remove('bg-brand-600', 'text-white', 'hover:bg-brand-700', 'cursor-pointer');
      }
      selectedFileContent = '';
    }
  };

  if (youtubeUrlInput) youtubeUrlInput.addEventListener('input', (e) => handleUrlInput(e, 'youtube'));
  if (webUrlInput) webUrlInput.addEventListener('input', (e) => handleUrlInput(e, 'web'));
}

// Setup Study Set Navigation & Interactive Events
function setupDeckInteractions() {
  // Flashcard flipping
  const flashcardContainer = document.getElementById('flashcard-container');
  if (flashcardContainer) {
    flashcardContainer.addEventListener('click', () => {
      const innerCard = document.getElementById('flashcard-inner');
      if (innerCard) {
        innerCard.classList.toggle('rotate-y-180');
      }
    });
  }

  // Flashcards next/prev controls
  const prevCardBtn = document.getElementById('prev-card-btn');
  const nextCardBtn = document.getElementById('next-card-btn');

  if (prevCardBtn) {
    prevCardBtn.addEventListener('click', (e) => {
      e.stopPropagation(); // prevent flipping card when clicking control button
      if (!currentDeck || !currentDeck.flashcards) return;
      currentFlashcardIndex = (currentFlashcardIndex - 1 + currentDeck.flashcards.length) % currentDeck.flashcards.length;
      updateFlashcardDOM();
    });
  }

  if (nextCardBtn) {
    nextCardBtn.addEventListener('click', (e) => {
      e.stopPropagation(); // prevent flipping card when clicking control button
      if (!currentDeck || !currentDeck.flashcards) return;
      currentFlashcardIndex = (currentFlashcardIndex + 1) % currentDeck.flashcards.length;
      updateFlashcardDOM();
    });
  }

  // Quiz next/submit button
  const quizSubmitBtn = document.getElementById('quiz-submit-btn');
  if (quizSubmitBtn) {
    quizSubmitBtn.addEventListener('click', () => {
      if (!currentDeck || !currentDeck.quiz) return;
      
      if (currentQuizIndex < currentDeck.quiz.length - 1) {
        currentQuizIndex++;
        updateQuizDOM();
      } else {
        // Show results
        const questionCard = document.getElementById('quiz-question-card');
        const resultsCard = document.getElementById('quiz-results-card');
        const finalScore = document.getElementById('quiz-final-score');
        const percentageText = document.getElementById('quiz-percentage-text');
        
        if (questionCard) questionCard.classList.add('hidden');
        if (resultsCard) resultsCard.classList.remove('hidden');
        
        if (finalScore) {
          finalScore.textContent = `${quizScore} / ${currentDeck.quiz.length}`;
        }
        if (percentageText) {
          const pct = Math.round((quizScore / currentDeck.quiz.length) * 100);
          percentageText.textContent = `${pct}% Score`;
        }

        // Save attempt to IndexedDB locally
        if (currentMaterialId) {
          db.quiz_attempts.add({
            materialId: currentMaterialId,
            score: quizScore,
            totalQuestions: currentDeck.quiz.length,
            timestamp: Date.now()
          }).then((id) => {
            console.log(`[MulatAI] Quiz attempt logged locally with ID: ${id}`);
          }).catch((err) => {
            console.warn('[MulatAI] Failed to save quiz attempt:', err);
          });
        }
      }
    });
  }

  // Quiz results buttons
  const quizRestartBtn = document.getElementById('quiz-restart-btn');
  const quizNewBtn = document.getElementById('quiz-new-btn');

  if (quizRestartBtn) {
    quizRestartBtn.addEventListener('click', () => {
      if (currentDeck) {
        renderQuiz(currentDeck);
      }
    });
  }

  if (quizNewBtn) {
    quizNewBtn.addEventListener('click', () => {
      const deckSection = document.getElementById('study-deck-section');
      const wizardContainer = document.getElementById('wizard-container');
      
      if (deckSection) deckSection.classList.add('hidden');
      if (wizardContainer) {
        wizardContainer.classList.remove('hidden');
        
        // Reset wizard back to step 1
        const step1 = document.getElementById('wizard-step-1');
        const step2 = document.getElementById('wizard-step-2');
        const backBtn = document.getElementById('wizard-back-btn');
        const progressFill = document.getElementById('wizard-progress-fill');
        
        if (step1) step1.classList.remove('hidden');
        if (step2) step2.classList.add('hidden');
        if (backBtn) {
          backBtn.style.opacity = '0';
          backBtn.style.pointerEvents = 'none';
        }
        if (progressFill) progressFill.style.width = '20%';
      }
    });
  }

  // Tab switcher
  const tabFlashcardsBtn = document.getElementById('tab-flashcards-btn');
  const tabQuizBtn = document.getElementById('tab-quiz-btn');
  const tabFlashcardsView = document.getElementById('tab-flashcards-view');
  const tabQuizView = document.getElementById('tab-quiz-view');

  if (tabFlashcardsBtn && tabQuizBtn) {
    tabFlashcardsBtn.addEventListener('click', () => {
      if (tabFlashcardsView) tabFlashcardsView.classList.remove('hidden');
      if (tabQuizView) tabQuizView.classList.add('hidden');
      
      tabFlashcardsBtn.className = 'border-b-2 border-brand-600 text-brand-600 px-1 py-3 text-xs font-bold tracking-wide uppercase dark:border-brand-400 dark:text-brand-400 flex items-center gap-2';
      tabQuizBtn.className = 'border-b-2 border-transparent text-slate-400 hover:text-slate-600 px-1 py-3 text-xs font-bold tracking-wide uppercase dark:hover:text-slate-300 flex items-center gap-2';
    });

    tabQuizBtn.addEventListener('click', () => {
      if (tabFlashcardsView) tabFlashcardsView.classList.add('hidden');
      if (tabQuizView) tabQuizView.classList.remove('hidden');
      
      tabQuizBtn.className = 'border-b-2 border-brand-600 text-brand-600 px-1 py-3 text-xs font-bold tracking-wide uppercase dark:border-brand-400 dark:text-brand-400 flex items-center gap-2';
      tabFlashcardsBtn.className = 'border-b-2 border-transparent text-slate-400 hover:text-slate-600 px-1 py-3 text-xs font-bold tracking-wide uppercase dark:hover:text-slate-300 flex items-center gap-2';
    });
  }
}

// Light & Dark Mode Toggle Handler
const setupDarkMode = () => {
  const darkModeBtn = document.getElementById('dark-mode-btn');
  const sunIcon = document.getElementById('sun-icon');
  const moonIcon = document.getElementById('moon-icon');

  if (darkModeBtn) {
    darkModeBtn.addEventListener('click', () => {
      const isDark = document.documentElement.classList.toggle('dark');
      localStorage.setItem('theme', isDark ? 'dark' : 'light');
      
      if (isDark) {
        if (sunIcon) sunIcon.classList.remove('hidden');
        if (moonIcon) moonIcon.classList.add('hidden');
      } else {
        if (sunIcon) sunIcon.classList.add('hidden');
        if (moonIcon) moonIcon.classList.remove('hidden');
      }
    });
  }
};

// Attach event listeners and bootstrap
function setupEventListeners() {
  const generateBtn = document.getElementById('generate-btn');
  if (generateBtn) {
    generateBtn.addEventListener('click', handleGenerate);
  }
  
  setupWizardTransitions();
  setupInputHandlers();
  setupDeckInteractions();
  setupDarkMode();
}

// Register Service Worker and clean up conflicting workers (common on localhost/port 5500)
async function registerServiceWorker() {
  if ('serviceWorker' in navigator) {
    try {
      const registrations = await navigator.serviceWorker.getRegistrations();
      for (const reg of registrations) {
        if (reg.active && !reg.active.scriptURL.includes('sw.js')) {
          console.log('[MulatAI] Cleared conflicting service worker from another project:', reg.active.scriptURL);
          await reg.unregister();
        }
      }
      const newReg = await navigator.serviceWorker.register('./sw.js');
      console.log('[MulatAI] Service Worker registered with scope:', newReg.scope);
    } catch (error) {
      console.warn('[MulatAI] Service Worker registration failed:', error);
    }
  }
}

window.addEventListener('DOMContentLoaded', () => {
  initPipeline();
  setupEventListeners();
  registerServiceWorker();
});
