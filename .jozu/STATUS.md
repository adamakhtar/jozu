# Status

Last updated: 2026-10-05 (S7 Mac scoped peek)

## What exists

- Native macOS SwiftUI app **Jozu**.
- Full-screen **Chat | Lessons**. Settings still a sheet.
- Chat, reply-language toggle, streamed replies, one persisted inbox thread. API key in the data-protection keychain (Application Support fallback).
- Photo attach / drop / paste → on-device Vision OCR. Image stays local.
- **Lessons:** Remember distills chat into a structured guide (word sense / grammar / nuance). Picker if several points. Search. Old memory crumbs migrate on first launch.
- **Discuss:** from a lesson, a scoped thread (stored on the lesson, not the inbox). Tutor sees the current guide. **Update lesson** merges the talk into that guide. Review schedule is left alone.
- **Review** on a lesson: probe that sense + struggle. Guide hidden until after the grade. Coarse `nextReviewAt`.
- **Peek (Mac):** selected text from an allowlisted app via Accessibility. Session allowlist. Preview + confirm. Logged on the turn. No screen capture.
- No key / 401: LLM calls blocked; alert points at Settings.

## What does not exist

- Parent Word → senses
- Window / desktop screenshot peek
- Multiple inbox threads
- Stub tutor
- iPhone target

## Environment constraint

Cloud agent host is Linux. GUI is unverified here.
