# Status

Last updated: 2026-10-12 (Review kit)

## What exists

- Native macOS SwiftUI app **Jozu**.
- Full-screen **Chat | Lessons**. Settings still a sheet.
- Chat, reply-language toggle, streamed replies, one persisted thread. API key in the data-protection keychain (Application Support fallback).
- Photo attach / drop / paste → on-device Vision OCR. Image stays local.
- **Lessons:** Remember distills chat into a structured guide (word sense / grammar / nuance). Picker if several points. Search. Old memory crumbs migrate on first launch.
- **Review:** One LLM call writes a 3-probe production kit (kind-specific patterns). Shown one at a time, graded one at a time. Guide hidden until the last probe. `nextReviewAt` from the worst grade. Coarse drip 1 / 2 / 7 / 14 days.
- No key / 401: LLM calls blocked; alert points at Settings.

## What does not exist

- Lesson-scoped Discuss + merge (S8b)
- Parent Word → senses
- Screen / other-app peek
- Multiple inbox threads
- Stub tutor
- iPhone target

## Environment constraint

Cloud agent host is Linux. GUI is unverified here.
