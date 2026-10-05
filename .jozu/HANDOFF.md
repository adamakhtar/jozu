# Handoff

Read this first in a new conversation. Then `STATUS.md`.

Updated: 2026-10-05
Branch: `cursor/persist-stream-1eb4`
Slice: 6 shipped; **S8 Lessons locked, not built**

## Now

S6 review probe is on PR #2. Product next is **S8 Lessons** (pulled forward; S7 peek waits). Decisions are in `DECISIONS.md` (2026-10-05 Lessons). Do not start S8 until the user says go — this conversation only locked it and updated docs.

When building S8, first slice only:

- Full-screen **Chat | Lessons** (not sheets).
- Remember → if multiple candidates, picker → one structured lesson (word sense / grammar / nuance).
- Search the library. Subtitle = sense/focus so two かける rows differ.
- Review stays a drip on the lesson: that sense + struggle. Hide the guide until after the grade.
- No key / 401: block LLM, alert, Settings. Remove the stub tutor.
- Chat-only updates and lesson-scoped Discuss are the **following** slice.

This Linux agent cannot compile or launch the app.

## Next (do in this order)

1. User says go on S8.
2. S8 first slice (library + distill + search + full screens + key gate).
3. S8b Discuss this lesson + merge update.
4. S7 Mac-only scoped peek.

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

- Say go on S8.
- LLM provider + API key (required once the stub is removed).
- Confirmation of native / target language defaults (currently English → Japanese).
- What “Jev” meant for scoring.
