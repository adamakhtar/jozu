# Handoff

Read this first in a new conversation. Then `STATUS.md`.

Updated: 2026-10-12
Branch: `cursor/tts-research-1aba`
Slice: 8 shipped on main; this branch is **TTS research only** (no code)

## Now

Product next is still **S8 verify on a Mac**, then S8b. This conversation did not start S8b or speech playback.

TTS research for reading tutor replies (JA/EN) is in [`.jozu/TTS.md`](TTS.md). Recommendation: Apple `AVSpeechSynthesizer` first; cloud only if that fails a listen test. No engine wired. No decision locked.

This Linux agent cannot compile or launch the app.

## Next (do in this order)

1. Confirm S8 on a Mac.
2. S8b — Discuss this lesson + merge update.
3. S7 Mac-only scoped peek.
4. Speech-out only after a listen test of Enhanced Kyoko/Hattori vs a cloud sample (see TTS.md).

## Do not

- Introduce React, Electron, or a JS webview shell.
- Add accounts, sync, or a server until local-first chat + memory work.
- Implement full SRS / SuperMemo.
- Capture the whole screen by default.
- Treat BLEU / exact-match as the grader for open-ended production.
- Add a parent Word→senses object yet (Later).
- Inline-edit lesson body in v1.
- Distill the entire mixed inbox into one lesson; picker if several topics.
- Send the photo bytes to the model unless a later decision says multimodal is needed.

## Blocked on the user

- LLM provider + API key (required).
- Confirmation of native / target language defaults (currently English → Japanese).
- What “Jev” meant for scoring.
