# Handoff

Read this first in a new conversation. Then `STATUS.md`.

Updated: 2026-10-12
Branch: `cursor/conversations-dictation-75f6`
Slice: conversations + on-device dictation, on top of S8 Lessons

## Now

Clear is gone. **New** starts another thread; past chats are under the Jozu title. Dictation is on-device Apple Speech (British English `en-GB` / Japanese `ja-JP`) — not an audio API. Mic inserts into the current message; **New with dictation** starts a blank thread already listening.

This Linux agent cannot compile or launch the app. Verify on a Mac: New keeps the old thread, switch back via the title menu, dictate EN and JA into part of a draft, confirm no network transcription. The EN/JA toggle must show **EN**, not a clipped mark. Dictation should start even when Keyboard → Dictation is already on; we no longer treat `supportsOnDeviceRecognition == false` as “not installed.”

## Next (do in this order)

1. Confirm this slice on a Mac (threads + on-device mic).
2. S8b — Discuss this lesson + merge update.
3. S7 Mac-only scoped peek.

## Do not

- Introduce React, Electron, or a JS webview shell.
- Send microphone audio to a server (Apple or otherwise). If on-device Speech fails, tell the user to install the language pack.
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
- First Mac check of on-device ja-JP / en-GB Speech packs.
