# Status

Last updated: 2026-10-12 (multiple conversations + on-device dictation)

## What exists

- Native macOS SwiftUI app **Jozu**.
- Full-screen **Chat | Lessons**. Settings still a sheet.
- Chat, reply-language toggle, streamed replies. **Multiple persisted threads.** New starts another; title menu switches. API key in the data-protection keychain (Application Support fallback).
- Photo attach / drop / paste → on-device Vision OCR. Image stays local.
- **Dictation:** Mic prefers on-device `SFSpeechRecognizer` only if a pack is actually reported. Otherwise it starts **Keyboard → Dictation** in the composer (`startDictation:`). Does not send audio to Apple’s speech servers. English prefers British when Speech is used.
- **Lessons:** Remember distills chat into a structured guide (word sense / grammar / nuance). Picker if several points. Search. Old memory crumbs migrate on first launch.
- **Review** on a lesson: probe that sense + struggle. Guide hidden until after the grade. Coarse `nextReviewAt`.
- No key / 401: LLM calls blocked; alert points at Settings.

## What does not exist

- Lesson-scoped Discuss + merge (S8b)
- Parent Word → senses
- Screen / other-app peek
- Speech out (TTS)
- whisper.cpp fallback if Apple’s on-device pack is thin
- iPhone target

## Environment constraint

Cloud agent host is Linux. GUI is unverified here.
