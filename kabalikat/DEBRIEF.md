# Kabalikat — Debrief & Change Log

Prepared for the ACM TechSprint (Accenture Project Case) presentation.
This file (1) checks the project against the brief, (2) states the uniqueness /
solution case, and (3) lists exactly what was changed in this pass.

---

## 1. Does it follow the core idea? (Accenture brief check)

> *"Develop an AI-powered study companion that provides accessible and
> personalized academic assistance for Filipino learners. The solution should
> explain concepts in both Filipino and English, generate practice exercises,
> and adapt to a student's learning level — optimized for mobile devices and
> low-bandwidth environments."*

| Brief requirement | In Kabalikat | Verdict |
|---|---|---|
| AI-powered study companion | Conversational **Tutor** (Gemini/Ollama) + document→deck generator | ✅ |
| Filipino **and** English | Filipino / English / **Taglish**, with strict per-language guardrails in `student_profile.dart` and `prompt_builder.dart` | ✅ strong |
| Generate practice exercises | Auto-generated **flashcards, reviewers, and microquizzes** from the student's own PDF/photo | ✅ strong |
| Adapt to learning level | **Mastery + spaced-repetition** scheduler; tutor receives a weak-topics memory note | ✅ (newly made concrete — see §3) |
| Mobile + low-bandwidth | Flutter; text-only pipeline; on-device OCR; local LLM; dynamic context sizing; **offline-first 3-tier fallback** | ✅ strong |

**Conclusion:** Yes — the project squarely follows the brief, and on three axes
(bilingual rigor, practice-from-your-own-material, offline-first) it goes
*beyond* a typical entry.

## 2. Uniqueness & the solution case

Most hackathon entries will be a thin wrapper around one cloud API — a chatbot
that **dies without wifi**. Kabalikat's differentiation:

1. **Offline-first, 3-tier AI ladder.** Gemini (cloud) → Ollama (on-device LLM)
   → bundled cached content. The app *never* hard-fails on a bad connection —
   the exact reality of low-signal barangays the brief calls out.
2. **Document-driven, not prompt-driven.** Students turn **their own notes** —
   a PDF or a **photo of handwritten notes** (on-device OCR, no upload) — into a
   reviewer + flashcards + a quiz. That's personalized to *their* class, not a
   generic syllabus.
3. **Real bilingual engineering.** Language directives are written *in the target
   language*, with few-shot good/bad examples and mid-prompt reminders to stop
   small local models from leaking English into Filipino output.
4. **Adapts visibly.** A forgetting-curve scheduler resurfaces weak decks first
   and labels each deck (`Review due` / `Mastered` / `Due in N days`).
5. **Privacy & cost.** OCR and the offline LLM run on-device; the cloud key is
   optional. Cheap to run, friendly to data-capped students.

## 3. What changed in this pass

### Chatbot — memory + de-hardcoding
- **Conversation memory:** the Tutor now receives the recent turns of the chat,
  so follow-ups ("give another example", "translate that") work. (`ai_service`
  uses Gemini multi-turn `contents` / Ollama `/api/chat` `messages`.)
- **Profile memory:** a system persona injects the student's name, grade,
  language, and a summary of **weak decks (<50%)** so answers are personalized.
- **Persistence:** chat history is saved to storage and restored on launch
  (`ChatMessage` JSON + `StorageService.saveChat/loadChat`).
- **Removed hardcoding:** the hard-coded Taglish-only greeting is gone; the
  greeting is now language-aware (l10n) and personalized with the student's name,
  rendered live (never stored, never sent to the model).
- **Right model for the job:** the tutor uses general chat models and *skips* the
  `kabalikat` JSON model (which is tuned for structured output, not chat).
- **Slimmed `ai_service`:** removed the dead duplicate repository + unused
  `generateStudyContent` / `generateStudyDeck` / `nextQuestion` paths (deck
  generation lives in `HybridStudyContentRepository`).

### Adaptive learning — made real
- New `models/review_state.dart` + `services/spaced_repetition.dart` (SM-2-lite).
- `AppState.recordReviewSession` runs at the end of a quiz; Practice/Progress now
  show due-first ordering, status chips, and a "N due for review" banner.
- See `ADAPTIVE_LEARNING.md` for the full design and the rationale for keying it
  to generated decks instead of a fixed curriculum tree.

### PDF — better extraction
- `DocumentService` now extracts **page-by-page** (a bad page no longer loses the
  whole doc), **normalizes whitespace** (fewer wasted tokens), reports a page
  count, derives the **deck title from the file name** (not a timestamp), and
  **detects scanned/image-only PDFs** — guiding the user to the OCR path instead
  of silently failing. Uses the correct `FilePicker.platform.pickFiles` API.

### Settings — best of both versions
- Kept the clean l10n-based layout; added: **AI-status badge**, **edit name**,
  an **On-device AI (Ollama)** info section, and **Reset progress / Clear chat**
  buttons (great for clean demo runs). The other prototype's on-device *model
  picker* was intentionally not ported — Mulat uses Ollama, not a bundled model,
  so a download/enable picker would be dead UI here.

## 4. Known limitations / talk-track honesty
- The offline LLM tier requires Ollama running (see `ON_DEVICE_MODEL.md`); on a
  fresh device the offline tutor falls back to bundled bilingual lessons.
- Paste-notes / PowerPoint / YouTube tiles in Decks are UI stubs ("coming soon").
- `SpacedRepetition.dueLabel` ("Due in N days") is English-only; the key status
  chips (`Review due`, `Mastered`) are localized.
- Not yet run through `flutter analyze` in this environment (no Flutter SDK here)
  — do a quick `flutter pub get && flutter analyze` before presenting.

## 5. Pre-demo checklist
- [ ] `flutter pub get && flutter analyze` (fix any analyzer nits).
- [ ] (Optional) Ollama up with `kabalikat` + one chat model.
- [ ] (Optional) Gemini key pasted in Settings.
- [ ] Settings → **Reset progress** for a clean run.
- [ ] One short text-based PDF on the device.
- [ ] Rehearse the **offline toggle** moment (Settings → Demo: simulate offline).
