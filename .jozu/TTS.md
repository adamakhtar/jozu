# TTS for reading tutor replies (EN / JA)

Research only. No engine is wired. Speech in/out stays Later until a decision.

Checked: 2026-10-12. Prices move; treat tables as snapshot, not a contract.

For Jozu: native Swift, Mac first, iPhone later, local-first, mixed English + Japanese. “Natural” means a tutor, not an anime character and not compact Siri.

## What to ship, if we ship it

1. **Default: Apple `AVSpeechSynthesizer`.** On-device after the Enhanced/Premium voices are downloaded once (System Settings → Accessibility → Spoken Content). Zero extra binary, same API on iPhone, no per-character cost. Quality is clear, not ElevenLabs-natural. Split mixed EN/JA text and switch voice by script.
2. **If that fails a listen test:** cloud TTS behind a protocol (same shape as `LLMServicing`). Best tutor fit is **OpenAI `gpt-4o-mini-tts`** (key already in Settings, instruction-following: “slow, pause between phrases”). Best raw Japanese: **ElevenLabs**. Cheapest promptable natural: **Gemini 3.8 Flash-Lite TTS** (~1–2¢/min through 2026-12-31).
3. **Do not embed Python, VOICEVOX, or a 1.7 GB sidecar in v1.** Those are Mac-only experiments, not the app.

Worked monthly cost for an always-on “read the reply” button:

| Use | Chars / month | Audio / month |
| --- | --- | --- |
| Light (10 short replies/day) | ~100k | ~2 h |
| Active (a lot of chat + review) | ~500k | ~8 h |

At those volumes, **quality and latency dominate price**. Even ElevenLabs Flash is a few dollars a month. Local is $0.

---

## Local (no network after install / first voice download)

Apple Enhanced/Premium voices download over the network **once**, then run fully offline. Everything else in this table is offline if you ship or cache the weights.

| Engine | JP | EN | Native Swift? | Size | Quality | Jozu fit |
| --- | --- | --- | --- | --- | --- | --- |
| **`AVSpeechSynthesizer`** (Enhanced / Premium) | Kyoko, Otoya; Siri Hattori / O-Ren (premium if installed) | Samantha, Siri, many Enhanced | Yes. `AVFAudio`. macOS 14+ / iOS. | Compact built-in; Enhanced/Premium ~100–300 MB/voice, user-downloaded | Clear neural. Still “system TTS.” Weak on mixed-script pitch accent unless you split utterances | **First slice.** No deps. Mac + iPhone. Prompt user to install Enhanced JA + EN if missing |
| **Kokoro-82M via CoreML** (`jud/kokoro-coreml`, SPM) | Voices exist (`jf_gongitsune` and other `jf_`/`jm_`) | Strong (Misaki G2P in Swift) | Yes. Apple Silicon, macOS 15+ / iOS 18+ | ~99 MB models | Natural for EN. JP depends on G2P: Python Kokoro uses `misaki[ja]` + pyopenjtalk. Several Swift ports only ship English Misaki. Verify JA phonemizer before betting the product | Best *in-process* neural if JA G2P actually works in the package we pick |
| **`mweinbach/kokoro-swift`** (MLX or CoreML) | 4F+1M listed | Full US/UK set | Yes. Apple Silicon, macOS 14+ | ~80 MB + voices on demand | Same Kokoro family. README advertises **English G2P only** (Misaki). JP voices without OpenJTalk-class G2P will misread | Don’t use for Japanese until G2P is native |
| **sherpa-onnx** (C API + Swift examples / `sherpa-onnx-spm`) | Piper-Plus / Tsukuyomi / some Supertonic JA | Many Piper EN | Bindings exist; not a clean first-party SPM story on Mac | 20–400 MB/model | EN: solid. JP: often character/anime (Tsukuyomi). Neutral JA models are scarce | Runtime for ONNX if we later pick a specific checkpoint. Don’t ship “sherpa” as the product voice |
| **Piper / Piper Plus** | Piper Plus has JA + `PiperPlusG2P` (jpreprocess / OpenJTalk port, SPM, ~20 MB dict) | Good | Piper Plus has an xcframework; original Piper is C++/ONNX | ~40–80 MB | Small, fast, “assistant” quality. JA community voices skew character | Interesting **G2P** even if we keep Apple for playback. Synthesis quality < cloud |
| **VOICEVOX Engine** (local HTTP `127.0.0.1:50021`) | Best common local JP. Character roster (Zundamon, Metan, …) | Weak / not the point | C core + HTTP. `VoicevoxCoreSwift` exists; engine is a sidecar | App zip ~1.7 GB on Mac arm64 | Very good Japanese, **character timbre**. Nemo sibling = more neutral, same API, other port | Mac experiment only. Character licenses need attribution. Not iPhone. Against “no extra server” |
| **VOICEVOX Nemo** | Neutral JP, education-oriented | Weak | Same HTTP as VOICEVOX | Similar sidecar | Better tutor tone than Zundamon | Same packaging problem |
| **Style-Bert-VITS2 JP-Extra** | Best-in-class local JP (MOS near human in their evals) | Separate models | Python. ONNX export, no Swift runtime | 150–300 MB/voice | The local quality ceiling for Japanese | Not shippable in Jozu |
| **mlx-audio / Kokoro Python** | Yes (with `misaki[ja]`) | Yes | Python + MLX | ~80 MB+ | Good on Apple Silicon from a terminal | Dev sidecar, not in-app |
| **eSpeak-NG** | Robotic | Robotic | C | Tiny | Unusable as a tutor | Skip |
| **Apple Personal Voice** | On-device clone of *the user* | Same | Accessibility API, consent recording | On device | Natural, but it’s the learner’s voice | Wrong product. Don’t read the tutor as the student |

### Apple voices (the actual first implementation)

```swift
let utterance = AVSpeechUtterance(string: text)
utterance.voice = AVSpeechSynthesisVoice(language: "ja-JP") // or "en-US"
utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.85
AVSpeechSynthesizer().speak(utterance)
```

Pick by identifier, not language, so we get Enhanced/Premium:

- JA: `com.apple.voice.enhanced.ja-JP.Kyoko`, `…Otoya`; Siri `…siri_Hattori_ja-JP_premium`, `…siri_O-Ren_ja-JP_premium`
- EN: Enhanced/Premium Samantha / Siri (enumerate `AVSpeechSynthesisVoice.speechVoices()`)

If quality is `.default` only, show Settings copy: download Enhanced Japanese + English under Spoken Content.

Mixed reply (“The nuance of かける is…”): split CJK vs Latin runs, queue two utterances. One voice on mixed text sounds broken.

`NSSpeechSynthesizer` is deprecated. Don’t use it.

### Local catch for Japanese

The model is easy. **G2P is hard.** Japanese needs tokenizer + pitch accent (OpenJTalk / pyopenjtalk / jpreprocess). Engines that skip that will:

- pick the wrong reading (行って as *itte* vs *okonatte*)
- flatten pitch accent (the thing a learner is trying to hear)

Apple’s voices hide this. Kokoro/Piper only sound “natural Japanese” with a real JA G2P. That is why VOICEVOX still wins local JP listen tests, and why Swift Kokoro ports that only bundle English Misaki are a trap.

---

## Cloud APIs (network every utterance)

All of these send the reply text off-device. Against local-first unless the user opts in.

List prices, USD, 2026-10-12. Azure’s public page hides `$` without a signed-in account; Neural **$16 / 1M chars** and Neural HD **$22–30 / 1M** are the widely published figures (HD launched at $30; third-party trackers say $22 after 2026-03). Confirm in Azure before depending on HD.

| Provider / model | JP + EN | Meter | List price | Light (100k chars / ~2 h) | Active (500k / ~8 h) | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| **OpenAI `gpt-4o-mini-tts`** | JP yes; voices **optimized for English** | Text **$0.60 / 1M tokens** + audio **$12 / 1M tokens** | ~**$0.015 / min** of audio (community; slower speech costs more) | ~$1.80 | ~$7 | **Best Jozu cloud default.** Same vendor as chat. `instructions`: “Japanese tutor, slightly slow, pause at particle boundaries.” Streaming PCM/WAV. 2k input tokens/request |
| **OpenAI `tts-1`** | JP yes | **$15 / 1M chars** | $1.50 / 100k | $1.50 | $7.50 | Cheap, less natural than mini-tts |
| **OpenAI `tts-1-hd`** | JP yes | **$30 / 1M chars** | $3 | $3 | $15 | Skip; mini-tts is the current model |
| **ElevenLabs Flash / Turbo** | 32 langs incl. JA | **$0.04 / 1k chars** ($40 / 1M) | $4 | $4 | $20 | ~75 ms. Fine for chat playback |
| **ElevenLabs v2 Multilingual / v3** | v2: 29 langs; v3: 70+; both JA | **$0.08 / 1k chars** ($80 / 1M) | $8 | $8 | $40 | **Best JP quality.** v3 more expressive, 5k char cap |
| **ElevenLabs v4** (promo) | 90+ langs | List **$0.08 / 1k**; **$0.022 / 1k** promo through 2026-10-12 | $2.20 promo / $8 list | $2.20 / $8 | $11 / $40 | Promo ends today. Don’t budget the discount |
| **Google Chirp 3: HD** | JA yes | **$30 / 1M chars**; first **1M / month free** | **$0** | **$0** | **$0** | Light and active both sit under the 1M free cap. $15 only after 1.5M chars in a month |
| **Google Neural2 / Polyglot** | JA yes | **$16 / 1M**; 1M free | $0 | $0 | $0 | Solid, less “generative” |
| **Google WaveNet / Standard** | JA; **1 CJK char = 1 billable char** (not bytes) | **$4 / 1M**; 4M free | $0 | $0 | $0 | Older quality |
| **Google Gemini 3.8 Flash TTS** | JA yes (130 langs) | Text **$0.50 / 1M tokens**; audio **$9 / 1M tokens** through **2026-12-31**, then **2×**. Official 25 audio tokens/s; some 3.8 bills ~32 tok/s | ~**$0.014–0.017 / min** now | ~$1.60–2.00 | ~$6.50–8 | Promptable like OpenAI. Gemini API free-tier audio may apply; Cloud TTS table has no free chars for Gemini |
| **Google Gemini 3.8 Flash-Lite TTS** | JA yes | Text $0.50 / 1M; audio **$6 / 1M** through 2026-12-31, then 2× | ~**$0.009–0.012 / min** | ~$1.10–1.40 | ~$4.30–5.80 | Cheapest natural/promptable |
| **Azure Neural** | Excellent JA (Nanami, Keita, …) | **~$16 / 1M chars**; **0.5M free / month**; **kanji count as 2 chars** | ~$0 (light) | ~$0 | ~$8 if JP-heavy after 2× kanji | SSML, pronunciation. Confirm list price when signed in |
| **Azure Neural HD** (`ja-jp-Nanami:DragonHDLatestNeural`, Masaru) | JA HD is GA | **~$22–30 / 1M**; kanji 2× | ~$2–6 | ~$2–6 | ~$11–30 | Strong long-form JP. Worth a listen vs ElevenLabs |
| **Amazon Polly Neural** | Takumi, Kazuha, Tomoko | **$16 / 1M**; 1M free **first 12 months** | $0 yr1 | $0 yr1 | $0 yr1 / $8 after | Fine, not “natural 2026” |
| **Amazon Polly Generative** | **No Japanese** (EN + some EU/KR) | **$30 / 1M**; 100k free first 12 mo | n/a for JA | — | — | Skip for Jozu |
| **Deepgram Aura-2** | JA voices: fujin, izanami, uzume, ebisu, ama | **$0.030 / 1k** ($30 / 1M); Growth $0.027 | $3 | $3 | $15 | Low latency. $200 intro credit advertised |
| **Inworld Realtime TTS-2** | 200+ langs, JA, cross-lingual clone | **$25 / 1M** on-demand → $15 @$300/mo → $10 enterprise | $2.50 | $2.50 | $12.50 | Instruction/steering. Overkill for playback |
| **Inworld TTS-2 Flash** | Same langs | **$15 / 1M** on-demand, lower on plans | $1.50 | $1.50 | $7.50 | Faster/cheaper sibling |
| **Cartesia Sonic** | JA among ~44 langs | ~**1 credit / char**. Plans: Free 20k; Pro $5 / 100k; Startup $49 / 1.25M; Scale $299 / 8M. Overage ~$38–65 / 1M | $5 plan (Pro) | $5 | $49 plan | ~40 ms TTFA. Credit math is worse than Google/OpenAI at low volume |
| **Fish Audio S2** | JA + EN, 83 langs | **$15 / 1M UTF-8 bytes** — Japanese often **~3×** vs English per character | ~$4–5 JP | ~$4–5 | ~$22 | Byte billing punishes CJK. Open weights exist for self-host |

Polly Standard ($4 / 1M) and Google Standard ($4 / 1M) exist; they sound dated. Skip.

### Cloud that is *product-shaped* for a tutor

Instruction-following (“slower, clearer vowels, don’t swallow particles”) is worth more than 10% MOS:

- OpenAI `gpt-4o-mini-tts` `instructions`
- Gemini TTS (style prompts)
- ElevenLabs audio tags / v3–v4
- Inworld steering

Chirp / Azure Neural / Polly are “pick a voice, get audio.” Fine. Less control.

---

## Cost at a glance (active user, ~500k chars / ~8 h)

| Path | $/month |
| --- | --- |
| Apple / Kokoro / VOICEVOX local | **$0** |
| Google Chirp 3 HD or Neural2 (under 1M free) | **$0** |
| Gemini 3.8 Flash-Lite TTS (promo) | **~$5** |
| OpenAI `gpt-4o-mini-tts` | **~$7** |
| OpenAI `tts-1` / Inworld Flash / Polly Neural (after free year) | **~$7–8** |
| Azure Neural (JP kanji ×2 may push over free) | **~$0–16** |
| ElevenLabs Flash | **$20** |
| Deepgram Aura-2 | **$15** |
| ElevenLabs v2/v3 | **$40** |

Light use is pocket change on every cloud except ElevenLabs Multilingual.

---

## Recommendation for Jozu (not locked)

| Slice | Choice | Why |
| --- | --- | --- |
| First speech-out | `AVSpeechSynthesizer` + Enhanced JA/EN, split mixed text, play button on assistant turns | Matches Vision OCR: on-device, no new vendor, iPhone later. Listen on a Mac before anything else |
| If Apple fails the “would I learn from this?” test | Optional cloud: **OpenAI `gpt-4o-mini-tts`** using the existing key; fallback **Gemini Flash-Lite TTS** if we want cheaper promptable; **ElevenLabs** only if JP quality is the hill | Protocol + Settings toggle. Never the only path |
| Do not | Bundle VOICEVOX, Python, or 100 MB Kokoro until JA G2P is proven in Swift | Breaks iPhone, sandbox, and local-first simplicity |

Open questions (need a listen on a Mac, then a decision):

1. Is Enhanced Kyoko / Hattori good enough for tutor replies?
2. Auto-speak vs tap-to-speak? (auto-speak fights streaming tokens)
3. Speak Japanese only, or the whole mixed reply?
4. Cloud allowed at all, or local-only forever?

No `DECISIONS.md` entry until those are answered. Speech in/out stays Later.
