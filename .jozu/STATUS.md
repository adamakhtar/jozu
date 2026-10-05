# Status

Last updated: 2026-10-05 (API key: data-protection keychain, no login-keychain prompt)

## What exists

- Native macOS SwiftUI app **Jozu**.
- Chat, reply-language toggle, Settings, streamed replies, one persisted thread. API key in the data-protection keychain (Application Support fallback).
- Photo attach / drop / paste → on-device Vision OCR. Image stays local.
- Review items: Remember on a turn, or type “remember this”. Stored as word / sentence / grammar.
- **Memories** list (Due first). **Review** writes a probe, grades the answer, sets `nextReviewAt`.

## What does not exist

- Multiple conversations
- Screen / other-app peek
- Multimodal image upload to the LLM
- SM-2 / FSRS
- iPhone target

## Environment constraint

Cloud agent host is Linux. GUI is unverified here.
