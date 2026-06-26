# On-Device AI (Tier 2) — Ollama Setup

Kabalikat's offline tier runs a **local LLM via [Ollama](https://ollama.com)**.
This is what lets the app generate fresh flashcards/quizzes and answer the tutor
**without internet or any API key**. If Ollama isn't present, the app still
falls back to bundled content (Tier 3) — so this is optional but makes the
offline demo much stronger.

## 1. Install Ollama
Download from <https://ollama.com> (macOS / Windows / Linux). Start it; it
listens on `http://localhost:11434`.

## 2. Build the custom `kabalikat` model
The repo ships `Modelfile.kabalikat` — a Llama 3.2 3B tuned for strict,
bilingual, JSON study-content generation (low temperature, tight sampling,
JSON stop-sequences).

```bash
cd kabalikat
ollama pull llama3.2:3b
ollama create kabalikat -f Modelfile.kabalikat

# verify
ollama show kabalikat --modelfile
ollama run kabalikat '{"flashcards":[{"front":"test","back":"test"}]}'
```

The app's model fallback chain (content generation) is:
`kabalikat → llama3.2:3b-instruct-q4_K_M → llama3.2:3b → gemma2:2b… → qwen2.5:0.5b`.
Pull whichever you can; the app tries them in order.

> **Tutor chat** deliberately skips the `kabalikat` model (it's tuned for JSON,
> not conversation) and uses general chat models: `llama3.2:3b`, `gemma2:2b`,
> `llama3.2:1b`, `qwen2.5:0.5b`. Pull at least one of these for the offline tutor.

## 3. Networking notes
- **Android emulator** reaches the host machine at `10.0.2.2`. The app tries
  `10.0.2.2` then `127.0.0.1`.
- **Desktop / physical device on the same LAN**: point at the host's LAN IP.
  Hosts are listed in `lib/services/ai_service.dart` (tutor) and
  `lib/repositories/hybrid_study_content_repository.dart` (content gen).

## 4. How routing decides
```
isOnline && hasApiKey ?  → Gemini (Tier 1)
   ↓ fail / timeout / empty
Ollama localhost:11434   → on-device (Tier 2)
   ↓ all hosts/models fail
Bundled content          → cached lessons + question bank (Tier 3)
```
Connectivity is re-checked live (DNS lookup) before each content-generation
call, so weak/airplane transitions cascade correctly instead of hanging.

## 5. Tuning
All sampling params live in `Modelfile.kabalikat` with rationale comments
(temperature 0.15, top_p 0.85, top_k 35, repeat_penalty 1.15, num_ctx 4096).
The app sizes `num_ctx` dynamically per request to save RAM on phones.
