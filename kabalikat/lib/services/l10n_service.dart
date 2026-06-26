import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/student_profile.dart';
import '../state/app_state.dart';

extension LocalizationHelper on String {
  String tr(BuildContext context) {
    final language = context.watch<AppState>().profile.language;
    final dict = _translations[this];
    if (dict == null) return this;
    return dict[language] ?? this;
  }
}

const Map<String, Map<AppLanguage, String>> _translations = {
  // Navigation
  'Tutor': {
    AppLanguage.english: 'Tutor',
    AppLanguage.filipino: 'Guro',
    AppLanguage.taglish: 'Tutor',
  },
  'Practice': {
    AppLanguage.english: 'Practice',
    AppLanguage.filipino: 'Pagsasanay',
    AppLanguage.taglish: 'Practice',
  },
  'Progress': {
    AppLanguage.english: 'Progress',
    AppLanguage.filipino: 'Progreso',
    AppLanguage.taglish: 'Progress',
  },
  'Decks': {
    AppLanguage.english: 'Decks',
    AppLanguage.filipino: 'Decks',
    AppLanguage.taglish: 'Decks',
  },
  'Settings': {
    AppLanguage.english: 'Settings',
    AppLanguage.filipino: 'Mga Setting',
    AppLanguage.taglish: 'Settings',
  },

  // Onboarding
  'Your AI study buddy — kahit walang signal.': {
    AppLanguage.english: 'Your AI study buddy — even without signal.',
    AppLanguage.filipino: 'Ang iyong AI study buddy — kahit walang signal.',
    AppLanguage.taglish: 'Your AI study buddy — kahit walang signal.',
  },
  'Ano ang pangalan mo? / Your name': {
    AppLanguage.english: 'What is your name?',
    AppLanguage.filipino: 'Ano ang pangalan mo?',
    AppLanguage.taglish: 'Ano ang pangalan mo? / Your name',
  },
  'Grade level': {
    AppLanguage.english: 'Grade level',
    AppLanguage.filipino: 'Antas ng Baitang',
    AppLanguage.taglish: 'Grade level',
  },
  'Wikang gagamitin / Language': {
    AppLanguage.english: 'Language',
    AppLanguage.filipino: 'Wikang gagamitin',
    AppLanguage.taglish: 'Language / Wika',
  },
  'Simulan / Start': {
    AppLanguage.english: 'Start',
    AppLanguage.filipino: 'Simulan',
    AppLanguage.taglish: 'Start',
  },

  // Progress
  'Overall mastery': {
    AppLanguage.english: 'Overall mastery',
    AppLanguage.filipino: 'Kabuuang Kasanayan',
    AppLanguage.taglish: 'Overall Mastery',
  },
  'By topic': {
    AppLanguage.english: 'By topic',
    AppLanguage.filipino: 'Ayon sa paksa',
    AppLanguage.taglish: 'By topic',
  },

  // Chat
  '...nag-iisip si Kabalikat': {
    AppLanguage.english: '...Kabalikat is thinking',
    AppLanguage.filipino: '...nag-iisip si Kabalikat',
    AppLanguage.taglish: '...nag-iisip si Kabalikat',
  },
  'cached · offline': {
    AppLanguage.english: 'cached · offline',
    AppLanguage.filipino: 'nakaimbak · offline',
    AppLanguage.taglish: 'cached · offline',
  },
  'Ask a question...': {
    AppLanguage.english: 'Ask a question...',
    AppLanguage.filipino: 'Magtanong...',
    AppLanguage.taglish: 'Magtanong / Ask...',
  },
  'Clear chat': {
    AppLanguage.english: 'Clear chat',
    AppLanguage.filipino: 'Burahin ang chat',
    AppLanguage.taglish: 'I-clear ang chat',
  },
  'Clear conversation history?': {
    AppLanguage.english: 'Clear conversation history?',
    AppLanguage.filipino: 'Burahin ang kasaysayan ng pag-uusap?',
    AppLanguage.taglish: 'I-clear ang chat history?',
  },
  'This will remove all messages and start fresh.': {
    AppLanguage.english: 'This will remove all messages and start fresh.',
    AppLanguage.filipino: 'Mabubura ang lahat ng mensahe at magsisimula ulit.',
    AppLanguage.taglish: 'Mabubura ang lahat ng messages at mag-start fresh.',
  },
  'Cancel': {
    AppLanguage.english: 'Cancel',
    AppLanguage.filipino: 'Kanselahin',
    AppLanguage.taglish: 'Cancel',
  },

  // Practice
  'Next question': {
    AppLanguage.english: 'Next question',
    AppLanguage.filipino: 'Susunod na tanong',
    AppLanguage.taglish: 'Next question',
  },
  'Adaptive Practice': {
    AppLanguage.english: 'Adaptive Practice',
    AppLanguage.filipino: 'Angkop na Pagsasanay',
    AppLanguage.taglish: 'Adaptive Practice',
  },
  'Start practice': {
    AppLanguage.english: 'Start practice',
    AppLanguage.filipino: 'Magsimulang magsanay',
    AppLanguage.taglish: 'Start practice',
  },

  // Decks
  'Study Decks': {
    AppLanguage.english: 'Study Decks',
    AppLanguage.filipino: 'Mga Study Deck',
    AppLanguage.taglish: 'Study Decks',
  },
  'Reading document & generating flashcards...': {
    AppLanguage.english: 'Reading document & generating flashcards...',
    AppLanguage.filipino: 'Binabasa ang dokumento at gumagawa ng mga flashcard...',
    AppLanguage.taglish: 'Reading document at gumagawa ng flashcards...',
  },
  'This may take a moment on local AI.': {
    AppLanguage.english: 'This may take a moment on local AI.',
    AppLanguage.filipino: 'Maaaring tumagal ito nang kaunti sa local AI.',
    AppLanguage.taglish: 'Maaaring tumagal ito nang kaunti sa local AI.',
  },
  'New Deck': {
    AppLanguage.english: 'New Deck',
    AppLanguage.filipino: 'Bagong Deck',
    AppLanguage.taglish: 'New Deck',
  },

  // Deck View
  'This deck is empty.': {
    AppLanguage.english: 'This deck is empty.',
    AppLanguage.filipino: 'Walang laman ang deck na ito.',
    AppLanguage.taglish: 'Empty ang deck na ito.',
  },
  'Flashcards': {
    AppLanguage.english: 'Flashcards',
    AppLanguage.filipino: 'Mga Flashcard',
    AppLanguage.taglish: 'Flashcards',
  },
  'Microquizzes': {
    AppLanguage.english: 'Microquizzes',
    AppLanguage.filipino: 'Maikling Pagsusulit',
    AppLanguage.taglish: 'Microquizzes',
  },

  // Connection Banner
  'You are offline. Showing cached content.': {
    AppLanguage.english: 'You are offline. Showing cached content.',
    AppLanguage.filipino: 'Ikaw ay offline. Ipinapakita ang nakaimbak na nilalaman.',
    AppLanguage.taglish: 'Offline ka. Showing cached content.',
  },

  // Settings
  'Language': {
    AppLanguage.english: 'Language',
    AppLanguage.filipino: 'Wika',
    AppLanguage.taglish: 'Language',
  },
  'Demo: simulate offline': {
    AppLanguage.english: 'Demo: simulate offline',
    AppLanguage.filipino: 'Demo: simulate offline',
    AppLanguage.taglish: 'Demo: simulate offline',
  },
  'Force cached mode without airplane mode': {
    AppLanguage.english: 'Force cached mode without airplane mode',
    AppLanguage.filipino: 'Piliting gumamit ng cached mode nang walang airplane mode',
    AppLanguage.taglish: 'Force cached mode kahit walang airplane mode',
  },
  'Live AI (optional)': {
    AppLanguage.english: 'Live AI (optional)',
    AppLanguage.filipino: 'Live AI (opsyonal)',
    AppLanguage.taglish: 'Live AI (optional)',
  },
  'API key saved — live AI active when online.': {
    AppLanguage.english: 'API key saved — live AI active when online.',
    AppLanguage.filipino: 'Nai-save na ang API key — aktibo ang live AI kapag online.',
    AppLanguage.taglish: 'API key saved — live AI active kapag online.',
  },
  'No key set — app uses cached content only.': {
    AppLanguage.english: 'No key set — app uses cached content only.',
    AppLanguage.filipino: 'Walang naka-set na key — gumagamit lamang ang app ng nakaimbak na nilalaman.',
    AppLanguage.taglish: 'No key set — app uses cached content lang.',
  },
  'Paste API key': {
    AppLanguage.english: 'Paste API key',
    AppLanguage.filipino: 'I-paste ang API key',
    AppLanguage.taglish: 'Paste API key',
  },
  'Save key': {
    AppLanguage.english: 'Save key',
    AppLanguage.filipino: 'I-save ang key',
    AppLanguage.taglish: 'Save key',
  },
  'API key saved': {
    AppLanguage.english: 'API key saved',
    AppLanguage.filipino: 'Nai-save na ang API key',
    AppLanguage.taglish: 'API key saved',
  },
  'Clear': {
    AppLanguage.english: 'Clear',
    AppLanguage.filipino: 'Burahin',
    AppLanguage.taglish: 'I-clear',
  },
  'Wala pang practice. Pumunta sa Practice tab para magsimula.': {
    AppLanguage.english: 'No practice yet. Go to Practice tab to start.',
    AppLanguage.filipino: 'Wala pang practice. Pumunta sa Practice tab para magsimula.',
    AppLanguage.taglish: 'Wala pang practice. Punta sa Practice tab para magsimula.',
  },
  'Online · Live AI tutor': {
    AppLanguage.english: 'Online · Live AI tutor',
    AppLanguage.filipino: 'Online · Live AI tutor',
    AppLanguage.taglish: 'Online · Live AI tutor',
  },
  'Online · add API key for live AI': {
    AppLanguage.english: 'Online · add API key for live AI',
    AppLanguage.filipino: 'Online · magdagdag ng API key para sa live AI',
    AppLanguage.taglish: 'Online · add API key for live AI',
  },
  'Offline · using cached lessons': {
    AppLanguage.english: 'Offline · using cached lessons',
    AppLanguage.filipino: 'Offline · gamit ang nakaimbak na mga aralin',
    AppLanguage.taglish: 'Offline · using cached lessons',
  },
};
