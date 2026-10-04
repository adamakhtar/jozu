# Decisions

Append-only. Newest first. Supersede; do not rewrite history.

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
