# Kabalikat 🚀

**An offline-first AI study companion for Filipino learners.**
ACM TechSprint — Accenture Project Case.

Kabalikat ("companion / katuwang") gives every Filipino student a patient
tutor that explains concepts in **Filipino, English, or Taglish**, turns their
own **notes and PDFs into flashcards and quizzes**, adapts to how well they
remember, and — crucially — **keeps working with no internet**.

## The challenge (Accenture)
> Build an AI-powered study companion that gives accessible, personalized
> academic help to Filipino learners — explaining concepts in Filipino *and*
> English, generating practice exercises, and adapting to a student's learning
> level, optimized for mobile and low-bandwidth environments.

## How Kabalikat answers it
- **Bilingual by design** — every answer, flashcard, and quiz can be produced in
  Filipino, English, or Taglish, with strict language guardrails so content
  doesn't "leak" between languages.
- **Generates practice from *your* material** — upload a PDF or **photograph
  your notes** (on-device OCR) and Kabalikat generates a reviewer, flashcards,
  and a multiple-choice quiz from it.
- **Adapts to the learner** — a spaced-repetition engine tracks mastery per deck
  and schedules reviews on a forgetting curve, surfacing what's *due* first.
- **Conversational tutor with memory** — the Tutor remembers the conversation
  and the student's profile / weak topics, so it isn't a cold-start chatbot.
- **Works offline, low-bandwidth first** — a 3-tier AI ladder degrades
  gracefully instead of dying without wifi.

## Why it's different
Most entries will be a chatbot that dies without wifi. Kabalikat is
**offline-first** and **document-driven**:

```
            ┌─────────────────────────── AI LADDER ───────────────────────────┐
  online +  │  Tier 1 · Gemini (cloud)        fresh, highest-quality content   │
  API key   │     │ fail / timeout / no key ↓                                  │
  offline   │  Tier 2 · Ollama on-device      local LLM, fully offline         │
            │     │ not installed / fail ↓                                     │
  always    │  Tier 3 · Bundled content       cached lessons + question bank   │
            └──────────────────────────────────────────────────────────────────┘
```

Same app, graceful fallback. A student in a low-signal barangay still gets help.

## Features
- 🗣️ **Bilingual tutor & content** — Filipino / English / Taglish.
- 📄 **PDF & photo → study deck** — Syncfusion PDF text extraction + Google ML
  Kit on-device OCR feed the LLM; flashcards + quizzes come back.
- 🧠 **Conversational memory** — the tutor sees recent turns + a profile summary.
- 🎯 **Spaced-repetition practice** — SM-2-style scheduling; "Review due",
  "Mastered", and "Due in N days" badges; due decks float to the top.
- 📡 **3-tier AI** — Gemini online → Ollama offline → bundled cache.
- 📈 **Progress dashboard** — overall + per-deck mastery, saved on-device.
- 📱 **Mobile-first, lightweight** — text-only pipeline, dynamic context sizing
  to fit cheap Android phones.

## Run it
```bash
cd kabalikat
flutter create .          # generates android/ ios/ etc. (keeps lib/ + pubspec)
flutter pub get
flutter run               # on an Android device/emulator
```
> `flutter create .` will not overwrite `lib/` or `pubspec.yaml`.

### Optional: enable the cloud tutor (Tier 1)
1. App → **Settings** → paste a Google **Gemini** API key.
2. Model IDs live in `lib/services/ai_service.dart` and
   `lib/repositories/hybrid_study_content_repository.dart`.
Without a key, the app runs on Ollama (Tier 2) and bundled content (Tier 3).

### Optional: enable the offline LLM (Tier 2)
See **`ON_DEVICE_MODEL.md`** — install Ollama and build the custom `kabalikat`
model from `Modelfile.kabalikat`.

## Demo flow
See **`DEMO_SCRIPT.md`** for the full judge-facing walkthrough. Settings has a
**"Demo: simulate offline"** toggle and a **Reset progress** button for clean runs.

## Architecture
```
lib/
  main.dart                       bootstrap + onboarding gate
  theme.dart                      cosmic brand theme
  models/
    student_profile.dart          profile + AppLanguage directives
    chat_message.dart             tutor turn (persisted)
    study_deck.dart               deck = flashcards + microquizzes
    study_content.dart            unified reviewer/flashcard/quiz items
    review_state.dart             spaced-repetition memory per deck
    practice_question.dart        bundled offline question shape
  data/offline_content.dart       bundled bilingual lessons + question bank
  services/
    ai_service.dart               conversational tutor (memory-aware, 3-tier)
    document_service.dart         PDF pick + clean text extraction
    ocr_service.dart              on-device OCR (ML Kit)
    prompt_builder.dart           language-aware Ollama prompts (few-shot + CoT)
    json_parser.dart              robust LLM-JSON parser
    spaced_repetition.dart        SM-2-lite review scheduler
    l10n_service.dart             FIL/EN/Taglish UI strings
    connectivity_service.dart     online/offline + demo override
    storage_service.dart          SharedPreferences (profile, mastery,
                                  reviews, chat, decks, key)
  repositories/
    study_content_repository.dart        backend contract
    hybrid_study_content_repository.dart  Gemini ↔ Ollama routing
  state/app_state.dart            ChangeNotifier: profile, mastery, reviews, chat
  screens/                        onboarding, home, chat, practice, progress,
                                  decks, deck_view, quiz_session, settings
  widgets/connection_banner.dart
```

## Roadmap (post-hackathon)
- Paste-notes / PowerPoint / YouTube ingestion (UI stubs present).
- SMS/USSD fallback for zero-data phones.
- Pre-downloadable DepEd-aligned content packs per grade/subject.
- Voice input/output for low-literacy learners.
- Teacher dashboard for class-level mastery.

Built for ACM TechSprint, 2026. See **`DEBRIEF.md`** for the change log and
brief-alignment notes, and **`ADAPTIVE_LEARNING.md`** for how the review engine
works.
