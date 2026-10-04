# Status

Last updated: 2026-10-04 (S3: Vision OCR on attached photos)

## What exists

- Native macOS SwiftUI app **Jozu**.
- Chat UI, reply-language toggle, Settings (languages + OpenAI-compatible key in Keychain).
- Streamed replies (stub or live SSE). One SwiftData thread. **Clear** deletes it.
- Photo attach (file picker, drop, paste). Vision OCR on-device using native + target language hints. Editable reading. Thumbnail persisted; image is not sent to the model.

## What does not exist

- Multiple conversations
- Review items / schedule / grading
- Screen / other-app peek
- Multimodal image upload to the LLM
- iPhone target (views are mostly portable; Xcode target is macOS-only)

## Environment constraint

Cloud agent host is Linux. GUI is unverified here.

## Defaults (assumptions)

| Setting | Value | Why |
| --- | --- | --- |
| Native language | English | Unspecified; easy to change |
| Target language | Japanese | Repo name 上手 / jozu |
| Model | `gpt-4o-mini` | Cheap default; override in Settings |
| API base | `https://api.openai.com/v1` | Swap for Groq, Ollama, etc. |
