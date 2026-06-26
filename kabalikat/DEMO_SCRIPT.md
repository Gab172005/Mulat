# Kabalikat — Demo Script (5–6 min)

> Goal: show the three things judges care about — **bilingual help**,
> **practice generated from the student's own material**, and **it adapts +
> works offline**. Keep it tight; the offline toggle is the money moment.

## 0. Setup (before you present)
- Phone/emulator with the app installed.
- (Optional, recommended) Ollama running with the `kabalikat` model so the
  offline tier is *real*, not just the bundled cache — see `ON_DEVICE_MODEL.md`.
- (Optional) A Gemini API key pasted in Settings for the cloud tier.
- In **Settings → Reset progress** for a clean slate.
- Have one short PDF (1–3 pages, real text — not a scan) ready on the device.

## 1. Onboard (20s)
- Enter a name, pick **Grade 7**, language **Taglish**.
- One line: *"Kabalikat meets students where they are — their grade, their language."*

## 2. Tutor with memory (60s)
- Tutor tab → ask **"Explain photosynthesis"** → bilingual, grade-aware answer
  ending in a check-question.
- Ask a **follow-up that needs memory**: *"Can you give another example?"* or
  *"Translate that to pure Filipino."*
- Point out: *"It remembered the topic — no need to repeat myself. The tutor
  also knows my grade and which decks I'm weak on."*

## 3. Turn a document into a study deck (90s)
- Decks tab → **New Deck → PDF** → pick the PDF.
  - (Or **Photograph your notes** → on-device OCR, works offline.)
- While it generates: *"This runs Gemini if online, or a local LLM on-device if
  not — the student's notes never have to leave the phone."*
- Open the deck → flip a few **flashcards** in the chosen language.

## 4. Adaptive practice + spaced repetition (90s)
- Practice tab → open the generated deck → answer the **microquiz**.
- Finish → score screen.
- Back on Practice: show the **status chip** ("Review due" / "Mastered" /
  "Due in N days") and that **due decks float to the top**.
- One line: *"It schedules reviews on a forgetting curve — weak decks come back
  sooner. That's the 'adapts to the learner' requirement, made concrete."*
- Progress tab → overall + per-deck mastery, and the **"N due for review"** banner.

## 5. The offline moment (60s)
- Settings → toggle **"Demo: simulate offline"** (or flip airplane mode).
- Connection banner appears.
- Go to Tutor → ask another question → still answers, now tagged
  **`cached · offline`** (or answered by the on-device LLM).
- Generate or open a deck → still works.
- Closing line: *"Same app, no wifi. A student in a low-signal barangay still
  gets a tutor, practice, and their decks."*

## Fallback if something breaks
- If Gemini errors: it silently cascades to Ollama, then to bundled content —
  nothing crashes. Just keep going.
- If Ollama isn't running offline: the Tutor still answers from the bundled
  bilingual lessons (`data/offline_content.dart`) with the `cached · offline` tag.
