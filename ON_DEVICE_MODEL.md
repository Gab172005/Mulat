# On-Device AI Model (Tier 2) — Activation Guide

Kabalikat's AI works in **three tiers** so it always has an answer:

| Tier | When | Engine | Quality |
|------|------|--------|---------|
| 1 · Cloud | Online + API key | Cloud LLM | Best |
| 2 · On-device | Offline, capable phone | Local model (Gemma) | Good, real AI |
| 3 · Cached | Offline, any phone | Bundled lessons/practice | Always works |

Tiers 1 and 3 ship and run today. **Tier 2 is built but not wired into the
default build** — that keeps the hackathon build bulletproof. Flip it on when
you have a capable Android device (≈3 GB free RAM) and ~20 minutes.

## Why it's a switch, not always-on
The on-device model is a 0.3–0.6 GB download and needs real RAM/GPU. On a low-end
phone it would fail. So we made it an explicit, optional tier: enable it, the
tutor runs as true offline AI; skip it, the app still works via cached content.

## Activate it

1. **Add the dependency** to `kabalikat/pubspec.yaml`:
   ```yaml
   dependencies:
     flutter_gemma: ^0.14.1   # check pub.dev for the latest
   ```
   Then `flutter pub get`.

2. **Enable the implementation**: rename
   `lib/services/local_model_gemma_reference.txt` →
   `lib/services/gemma_local_model_service.dart`.

3. **Swap the service** in `lib/state/app_state.dart`:
   ```dart
   // from:
   final LocalModelService localModel = StubLocalModelService();
   // to:
   final LocalModelService localModel = GemmaLocalModelService();
   ```
   (Add `import '../services/gemma_local_model_service.dart';`.)

4. **Platform setup** (per flutter_gemma docs):
   - **Android**: `minSdkVersion 26`+; allow the model file (large asset/cache).
     GPU backend recommended.
   - **iOS**: enable file sharing / increase memory entitlements as documented.
   - Follow the package's setup section: https://pub.dev/packages/flutter_gemma

5. **Run**, open **Settings → On-device AI → Download model**. After the
   one-time download it shows **Ready — works fully offline**. Now in the Tutor
   tab, with no signal, answers are tagged **"on-device AI · offline"**.

## Picking a model
Smaller = fits more phones, lower quality. Set the URL in
`GemmaLocalModelService(modelUrl: ...)`:

| Model | ~Size | Notes |
|-------|-------|-------|
| Gemma 3 270M | ~300 MB | Fastest, weakest; fine for simple Q&A |
| **Gemma 3 1B** (default) | ~550 MB | Best balance for a demo |
| Qwen3 0.6B | ~400 MB | Decent multilingual alternative |

Models live on Hugging Face / Kaggle and may need a free access token
(`huggingFaceToken`). Use a `*-int4`/`*-int8` `.task` or `.litertlm` build.

## Honest caveats for the pitch
- Small on-device models are **weak in Tagalog** — keep cloud (Tier 1) as the
  best bilingual experience; on-device is the offline safety net above cached.
- First load is slow; generation is a few tokens/sec on low-end hardware.
- This is exactly why all three tiers coexist — it's graceful degradation,
  not one fragile path.
