# Kabalikat 🚀

**An offline-first AI study companion for Filipino learners.**
ACM TechSprint — Accenture Project Case.

Kabalikat ("companion/partner") gives every Filipino student a patient tutor
that explains concepts in **Filipino, English, or Taglish**, generates
**adaptive practice**, and — crucially — **keeps working with no internet**.

## Why it's different
Most entries will be a chatbot that dies without wifi. Kabalikat is
**offline-first**: lessons and a practice bank are bundled in the app, so a
student in a low-signal barangay still gets help. When a connection *is*
available and an API key is set, it upgrades to a **live AI tutor** that
generates fresh, grade-aligned content. Same app, graceful fallback.

## Features
- 🗣️ **Bilingual tutor** — Filipino / English / Taglish toggle.
- 🎯 **Adaptive practice** — difficulty (1–3) rises and falls with per-topic mastery.
- 📡 **3-tier AI** — cloud LLM online → optional on-device model offline →
  bundled cached content. Graceful fallback so it always answers.
  (On-device tier is built and ready to activate — see `../ON_DEVICE_MODEL.md`.)
- 📈 **Progress dashboard** — overall + per-topic mastery, saved on-device.
- 📱 **Mobile-first, lightweight** — text-only, minimal data, fast on cheap phones.

## Run it
This repo ships the Dart source (`lib/`) and `pubspec.yaml`. Generate the
platform folders, then run:

```bash
cd kabalikat
flutter create .          # generates android/ ios/ etc. (keeps lib/ + pubspec)
flutter pub get
flutter run               # on an Android device/emulator
```

> `flutter create .` will not overwrite `lib/` or `pubspec.yaml`.

### Optional: enable the live AI tutor
1. Open the app → **Settings** → paste an API key (Anthropic by default).
2. Endpoint/model are in `lib/services/ai_service.dart` — swap for any
   OpenAI-compatible API if preferred.
3. For **release** builds, ensure `android/app/src/main/AndroidManifest.xml`
   has: `<uses-permission android:name="android.permission.INTERNET"/>`
   (present by default in debug).

Without a key, the app runs fully on bundled content — perfect for the
offline demo.

## Demo flow (the judge-winning moment)
1. Onboard as a Grade 7 student, language = Taglish.
2. **Tutor** tab → ask "Explain photosynthesis" → bilingual answer.
3. **Practice** tab → answer a few; watch difficulty + score adapt.
4. **Settings** → toggle **"Simulate offline"** (or flip airplane mode).
5. Go back to Tutor/Practice → still works, now labeled *cached · offline*.
6. **Progress** tab → show mastery bars updating.

See `../DEMO_SCRIPT.md` for the full walkthrough.

## Architecture
```
lib/
  main.dart                 app bootstrap + onboarding gate
  theme.dart                cosmic brand theme
  models/                   StudentProfile, ChatMessage, PracticeQuestion
  data/offline_content.dart bundled bilingual lessons + question bank
  services/
    storage_service.dart    SharedPreferences (profile, mastery, key)
    connectivity_service.dart  online/offline + demo override
    ai_service.dart         HYBRID brain: live LLM ↔ cached fallback
  state/app_state.dart      ChangeNotifier: profile, mastery, adaptivity
  screens/                  onboarding, home, chat, practice, progress, settings
  widgets/connection_banner.dart
```

## Roadmap (post-hackathon)
- SMS/USSD fallback for zero-data phones.
- Pre-downloadable DepEd-aligned content packs per grade/subject.
- Voice input/output for low-literacy learners.
- Teacher dashboard for class-level mastery.

Built for ACM TechSprint, 2026.
