# Status

Last updated: 2026-10-04 (build fix: explicit returns in LLMError / ReplyLanguage switches)

## What exists

- Empty-repo bootstrap: native macOS SwiftUI app named **Jozu**.
- Chat UI (user / assistant bubbles, composer, Cmd-Return to send).
- Reply in **native** or **target** language (session toggle + Settings).
- `LLMServicing` protocol:
  - `StubLLMService` if no API key
  - `OpenAICompatibleLLMService` if a key is present (any OpenAI-compatible base URL)
- Settings: native language, target language, model, base URL, API key (Keychain).
- App sandbox + outbound network client entitlement.

## What does not exist

- Persistence of chats or review items
- Photos / OCR
- Review schedule
- Answer grading
- Screen / other-app peek
- iPhone target (code is mostly portable; the Xcode target is macOS-only)

## Environment constraint

Cloud agent host is Linux. No Xcode, no Simulator, no self-hosted Mac worker. GUI is unverified until someone runs it on a Mac.

## Defaults (assumptions)

| Setting | Value | Why |
| --- | --- | --- |
| Native language | English | Unspecified; easy to change |
| Target language | Japanese | Repo name 上手 / jozu |
| Model | `gpt-4o-mini` | Cheap default; override in Settings |
| API base | `https://api.openai.com/v1` | Swap for Groq, Ollama, etc. |
