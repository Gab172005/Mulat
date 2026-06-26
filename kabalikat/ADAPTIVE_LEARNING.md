# Adaptive Learning — How Kabalikat adapts to the learner

The Accenture brief asks for a companion that **adapts to a student's learning
level**. Kabalikat does this with two cooperating mechanisms: **per-deck
mastery** and a **spaced-repetition schedule** (a forgetting curve). Together
they answer the question *"what should this student study next, and how hard?"*

## 1. Mastery (0..1) per deck
Every quiz answer nudges a deck's mastery up (correct) or down (wrong)
(`AppState.recordAnswer`). Mastery drives:
- the **difficulty band** (`difficultyFor` → 1/2/3), and
- the **progress bars** on Practice and Progress.

## 2. Spaced repetition (the adaptive scheduler)
When a quiz **session** ends, `AppState.recordReviewSession(deckTitle, scorePct)`
runs an SM-2-style scheduler (`services/spaced_repetition.dart`) over a durable
`ReviewState` per deck:

```
score ≥ 70%  → "remembered": grow the interval (1d → 3d → ×ease …), ease ↑
score < 70%  → "forgot": reset streak, interval = 1 day, ease ↓
mastery       = exponential moving average toward the achieved score
nextReview    = now + intervalDays
```

This is what makes it *adaptive* rather than a static quiz app:
- A deck the student aces drifts further into the future (less nagging).
- A deck they slip on snaps back to **tomorrow**.
- Mastery reflects a *trend*, not a single lucky/unlucky run.

## 3. Where the learner sees it
- **Practice tab** sorts **due decks first**, then weakest-first, and shows a
  status chip per deck: `Review due` (accent), `Mastered` (green), or
  `Due in N days`.
- **Progress tab** shows overall + per-deck mastery and a **"N due for review"**
  banner.

## 4. Where the tutor uses it
`AppState._memoryNote()` summarises the learner's decks and **weak topics
(< 50%)** and passes it to the conversational tutor as a profile memory. The
tutor then explains weak topics "extra simply" and tailors examples — so the
chat adapts to the same signal as practice.

## 5. Design choice: why per-deck, not a fixed curriculum
An earlier prototype used a hard-coded concept graph (a fixed DepEd-style
curriculum tree with prerequisites). Kabalikat is **document-driven** — students
bring their *own* material — so a fixed tree doesn't fit. We kept the valuable
part (mastery gating + SM-2 spaced repetition) and re-keyed it to the decks the
student actually generates. This keeps the adaptive engine meaningful without
forcing every learner onto one predefined syllabus.

## Files
- `models/review_state.dart` — durable schedule/mastery state per deck.
- `services/spaced_repetition.dart` — SM-2-lite scheduler + due labels.
- `state/app_state.dart` — `recordReviewSession`, `dueDeckTitles`, `_memoryNote`.
- `screens/practice_screen.dart`, `screens/progress_screen.dart` — surfacing.
