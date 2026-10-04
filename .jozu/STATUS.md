# Status

Last updated: 2026-10-04 (S1/S2: persist one thread + stream tokens)

## What exists

- Native macOS SwiftUI app **Jozu**.
- Chat UI, reply-language toggle, Settings (languages + OpenAI-compatible key in Keychain).
- `LLMServicing.stream`: stub chunks without a key; SSE from OpenAI-compatible hosts with a key.
- SwiftData: one `StoredConversation` + `StoredMessage` rows. Relaunch restores the thread. **Clear** deletes it.
- App sandbox + outbound network.

## What does not exist

- Multiple conversations
- Photos / OCR
- Review items / schedule / grading
- Screen / other-app peek
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
