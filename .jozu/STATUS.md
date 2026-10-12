# Status

Last updated: 2026-10-05 (S8 Lessons first slice)

## What exists

- Native macOS SwiftUI app **Jozu**.
- Full-screen **Chat | Lessons**. Settings still a sheet.
- Chat, reply-language toggle, streamed replies, one persisted thread. API key in the data-protection keychain (Application Support fallback).
- Photo attach / drop / paste → on-device Vision OCR. Image stays local.
- **Lessons:** Remember distills chat into a structured guide (word sense / grammar / nuance). Picker if several points. Search. Old memory crumbs migrate on first launch.
- **Review** on a lesson: probe that sense + struggle. Guide hidden until after the grade. Coarse `nextReviewAt`.
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
