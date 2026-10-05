# Decisions

Append-only. Newest first. Supersede; do not rewrite history.

## 2026-10-05 — Peek is on-demand AX selected text

**Choice:** Mac only. Button in the composer. User grants Accessibility. Session allowlist of bundle IDs (cleared on quit). Read `kAXSelectedTextAttribute` from the focused element of an allowlisted app. Show the exact string, let them edit, confirm, then attach to the next turn as `Text from {app} (selected):`. Log app name + text on the turn. Cap 4000 characters. No ScreenCaptureKit. No clipboard scrape. No background observer of content (only last-other-app for the “Allow and read” shortcut).

**Why:** Gap 6 was open. Always-on capture is a hole. Per-turn grant without an allowlist is tedious. Session allowlist + confirm is the middle: you pick Word once this sitting, you still see what leaves the machine. Window screenshots wait.

## 2026-10-05 — Discuss is lesson-scoped; merge rewrites the guide

**Choice:** Discuss is not the inbox. Transcript lives on `StoredLesson` (`discussJSON`). Chat chrome shows a banner (title + sense). Done returns to the inbox; Clear in that mode wipes the discussion only.

**Merge:** Explicit **Update lesson** (or “update the lesson” / “merge this” / 更新して). LLM returns the full revised guide JSON. Same lesson id. `createdAt`, `nextReviewAt`, and interval stay. `updatedAt` bumps. No inline field editing.

**Why:** Follow-ups are the product. Mixing them into the inbox would pollute Remember. A form editor would fight the model. Review schedule is a drip, not a save.

## 2026-10-05 — Lessons replace memory crumbs

**Choice:** The saved unit is a **lesson**: one usable distinction (one word-sense, one grammar use, or one nuance/contrast). Not a `{kind, target, note}` crumb. Remember distills a bounded stretch of chat into a structured guide. If several candidates are in that stretch, list them and the learner picks. Search the library. Chat | Lessons are full screens, not sheets. Settings may stay a sheet.

**Review:** Probe that lesson’s sense. Lean on the conversation’s struggle (`focus`), not a generic gloss quiz. Learner does not see the guide while answering; the model that writes/grades does. After the grade, show the relevant bit.

**Updates:** Chat-only in v1 (“Discuss” + merge). No inline edits. Lesson-scoped discuss + merge is the slice after the library exists.

**Kinds now:** word sense | grammar | nuance. Parent `Word → senses` is Later.

**No key / 401:** Block all LLM features (chat, save, review, update). Alert, point at Settings. No stub tutor.

**Why:** Follow-ups are the product (“how does it differ from X”). A gloss cannot hold that. Sheets hide the material. Ad-hoc signing made a stub-without-key useful for the window; it is no longer the intended loop.

## 2026-10-05 — API key is data-protection keychain, not login-keychain ACL

**Choice:** `kSecUseDataProtectionKeychain`. Never read the old login-keychain item (that dialog is an ACL on the binary’s code signature; “Always Allow” dies on the next ad-hoc ⌘R). If data-protection fails (no team / missing entitlement), store the key in the sandbox Application Support folder.

**Why:** The login-keychain prompt was blocking every rebuild. Data-protection items are partitioned by app id and do not use that ACL. File fallback keeps local unsigned builds usable.

## 2026-10-05 — Review probe is LLM JSON + coarse drip

**Choice:** Due items (header **Review**, Memories **Review due**, or a row) open a probe session, not a chat turn. LLM writes `{"question"}`. Learner answers. LLM returns `{"grade","reason","next_hint"}` with miss / partial / pass / easy. Those map to 1 / 2 / 7 / 14 days and `nextReviewAt`. No key: stub question from the item, stub grade from length / whether the target appears. Skip leaves the item due. Not SM-2. Not BLEU.

**Why:** Matches the 2026-10-04 drip + LLM-as-judge decisions. Exact intervals were open; this is the working table until a later decision replaces it.

## 2026-10-04 — Remember is local extract + list

**Choice:** Assistant **Remember** button, or a “remember this / 覚えて” user turn. Extract one `{kind, target, note}` via LLM JSON when a key exists; otherwise a heuristic. Persist `StoredMemory` with `nextReviewAt = now`. Memories sheet, Due first. Clear chat does not delete memories. No probe/grade yet.

**Why:** The loop has to be visible without S6. Heuristic keeps stub usable.

## 2026-10-04 — Vision OCR, image stays local

**Choice:** File picker / drop / paste → `VNRecognizeTextRequest` (accurate, language-corrected) with native + target language hints. Retry with no language list if that fails. User can edit the reading. Only the text is sent to the LLM. Persist a JPEG thumbnail + OCR string on the turn.

**Why:** On-device, Mac + iPhone later, no OCR SDK. Multimodal upload is a later fallback if Vision is thin on a script.

## 2026-10-04 — One SwiftData thread, streamed tokens

**Choice:** `StoredConversation` / `StoredMessage` on disk via SwiftData. One conversation. User/assistant turns saved after they complete (user immediately, assistant when the stream finishes). LLM path is `stream` only (SSE `chat/completions`). Stub also chunks so the loop is visible without a key.

**Why:** Quit/reopen is the first real product test. Streaming is how a live tutor feels. Multiple threads wait until one thread is boringly solid.

## 2026-10-04 — Slice 0 stack

**Choice:** Native Swift + SwiftUI, macOS 14+, local-first. Shared UI patterns kept iOS-safe. No JS shell.

**Why:** Features 3 and 7 need Vision, Keychain, sandbox, Accessibility, ScreenCaptureKit. Those are first-class on Apple platforms and hostile in Electron. The same SwiftUI views move to iPhone later. React was rejected unless a later decision names a concrete, unavoidable reason.

**Feedback loop:** The user runs `Jozu.xcodeproj` on a Mac. Domain logic that can be extracted later should land in a Swift package so Linux can at least `swift test` it. Not extracted yet — slice 0 is the window.

## 2026-10-04 — LLM behind a protocol

**Choice:** `LLMServicing` with a stub and an OpenAI-compatible HTTP client. Key and base URL live in Settings. Key goes in Keychain.

**Why:** Provider will change. OpenAI-compatible covers OpenAI, Groq, OpenRouter, local Ollama. Do not bake a vendor SDK into the app.

## 2026-10-04 — OCR will be Vision first

**Choice:** Apple Vision (`VNRecognizeTextRequest`) on-device, then optionally send the image to a multimodal model if Vision is thin.

**Why:** Works on Mac and iPhone, no extra dependency, many languages, stays on-device by default. Not implemented yet.

## 2026-10-04 — Review is a drip, not SRS

**Choice:** Items have `nextReviewAt` + a coarse interval. LLM writes a fresh probe and grades the answer. Reschedule from that grade. No SM-2 / FSRS yet.

**Why:** The brief asked for familiarity, not a deck trainer. Exact intervals are still open.

## 2026-10-04 — Grade with the LLM, not n-gram metrics

**Choice:** LLM-as-judge with a structured grade (miss / partial / pass / easy) plus a short reason. Not BLEU, WER, or exact match.

**Why:** Review items are open-ended (“use this grammar in the next line of the script”). Surface-form metrics punish valid paraphrases. If “Jev” meant something else, revisit.

## 2026-10-04 — Other-app peek is Mac-only and scoped

**Choice:** When we get there: user grants Accessibility, picks a frontmost app or a window, we read selected text (and later an optional window screenshot via ScreenCaptureKit). Allowlist. Session-scoped. Never the whole desktop by default. iPhone: share sheet / photo only.

**Why:** Full-desktop capture is a security hole and unnecessary for “help me write this sentence in Word.” iOS will not allow this shape of peek.

## 2026-10-04 — Project management lives in `.jozu/`

**Choice:** Markdown files in `.jozu/`, pointed at by `.cursor/rules/jozu-handoff.mdc`.

**Why:** New conversations must resume without a human briefing. Keep it in-repo, boring, and mandatory.
