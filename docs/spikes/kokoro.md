# Spike: Kokoro-82M as Sprout's voice

Goal: a listening test and a go/no-go for an on-device neural voice, to replan M5c (paused
after S2). Not production code. Everything lives in `ios/KokoroSpike/` plus a few `#if DEBUG`
lines, so it is easy to delete (section 9).

**Verdict so far: conditional go.** It works end to end, sounds far better than any
`AVSpeechSynthesizer` voice, is fast enough on an M1, and every license we ship is
permissive. The cost is real: about +390 MB of app, 0.7–1.6 GB of memory, and a
small fork of an unmaintained package. The iPhone numbers in section 5 decide it.

---

## 1. Options compared

| | kokoro-ios (KokoroSwift) | mlx-audio-swift (MLXAudioTTS) | FluidAudio (Core ML / ANE) |
|---|---|---|---|
| What | Kokoro-only MLX Swift port | Large multi-model MLX audio SDK, Kokoro is one model | Core ML conversion, 7 stages, ANE + GPU |
| SwiftPM | Yes | Yes | Yes |
| iOS / Swift | iOS 18+, tools 6.2. **Published 1.0.11 doesn't build on Xcode 26** (section 3) | iOS 17+, tools 6.2, active (pushed this week) | iOS 18+ (v3), active |
| Dependencies | mlx-swift, MisakiSwift, MLXUtilsLibrary (+ swift-numerics, ZIPFoundation) | mlx-swift, mlx-swift-lm, swift-transformers, swift-huggingface | Core ML only, own G2P |
| Model in app | Bring your own files: 327 MB fp32 weights + voices | Downloads from Hugging Face by default (bf16, ~164 MB); local folder possible | Downloads from Hugging Face and **compiles on device** at first load |
| First-launch download | No (bundled) | Yes by default (model and G2P dictionaries from `beshkenadze/kitten-tts-g2p`) | Yes (pinned HF release, then on-device Core ML compile) |
| G2P | MisakiSwift: Misaki dictionaries + BART fallback. **No espeak** (dependency commented out) | Misaki port, dictionaries downloaded at runtime; US only in that repo | Misaki lexicon + BART for English |
| Streaming | No: one call per text. The spike chunks by sentence | Yes (`generateStream`) | Per chunk |
| Speed (claimed) | 3.3× real time, iPhone 13 Pro, warm | Not stated for iPhone | M5 Pro only. "Physical-device validation remains outstanding"; OS 26.4+/iOS 27 Core ML crash advisories |
| Licenses | MIT / Apache-2.0 | MIT | Apache-2.0 |

**Chosen: kokoro-ios.** It is the smallest dependency set, runs fully offline from bundled
files, uses the same Misaki G2P as upstream Kokoro (and is espeak-free at compile time),
and is the only one with a published iPhone 13 Pro number. mlx-audio-swift is the better-maintained
home of the same MLX port, but it drags in the Hugging Face and LM stacks, downloads its G2P
dictionaries at runtime, and is a much larger surface for one voice. FluidAudio's Core ML
path is the most promising for speed and memory long term, but it says itself that it isn't
validated on physical devices, and it downloads and compiles models on device.

Apple's Core AI conversions (iOS 27) are out of scope for an iOS 26 target.

---

## 2. What the spike is

- `ios/KokoroSpike/` is a separate local package, so PlantKit doesn't depend on MLX and `swift test`
  on PlantKit stays fast.
  - `KokoroSpike`: Foundation only. The 3 lines, the voice list, the sentence chunker and the view model. Unit-tested (26 tests).
  - `KokoroSpikeEngine`: the MLX model (on one serial queue) and an `AVAudioEngine` graph:
    `AVAudioPlayerNode → AVAudioUnitTimePitch → mainMixerNode`, the graph M5c 2.5 planned.
    Chunks play as they are generated. Swift 6 rules from ARCHITECTURE.md section 3
    (`nonisolated static` closure factories, `DispatchQueue.main.async` + `assumeIsolated`).
  - `KokoroSpikeiOS`: the SwiftUI screen and composer.
  - `KokoroSpikeEngineTests`: an opt-in smoke test of the real model on macOS (the command is in the file).
- **Screen** (DEBUG only): chat › sliders menu › "Voice spike". It has the line (happy / thirsty / sleepy), a voice, a
  second voice with a blend slider (the style tables mixed linearly), pitch (cents, through
  `AVAudioUnitTimePitch`, applied on the next Play), speed (Kokoro's own duration control),
  Play / Stop, and these timings:
  - *Model load + warm-up*: the weights plus one "Hi." generation (G2P and Metal kernels).
  - *First audio*: from the Play tap to the first chunk scheduled and playing.
  - *Generation*: from the tap until every chunk is generated, the audio length, and the real-time factor.
  - *Memory*: `phys_footprint` now and its peak (what jetsam counts).
  - *Last runs*: the last 8 runs, also printed to the Xcode console as `[KokoroSpike] …`.
- The chat itself doesn't change. The menu entry, `PlantChatAction.voiceSpikeTap` and the route are `#if DEBUG`.
- For timings, launch with `-KokoroSpike` to open the screen directly. This works in Release, where the
  DEBUG menu entry doesn't exist. It is compiled only when the app links `KokoroSpikeiOS`
  (`#if canImport`), so the app builds the same as before without the package.
- MLX doesn't run in the Simulator, so there the screen says so instead of loading.

---

## 3. Upstream problems found (and the patch)

The published kokoro-ios 1.0.11 / MisakiSwift 1.0.6 **do not build with Xcode 26**. The
maintainer's last push was January 2026, and the fix PRs are open or were closed unmerged.

1. Their resource bundles keep a `Resources/` folder inside, which codesign rejects
   ("bundle format unrecognized") (kokoro-ios #30, #31, #35; MisakiSwift #15, #20).
2. Both pin `mlx-swift` **exactly** at 0.30.2. That version has iOS 26 SDK link errors (#30) and
   produces static instead of speech on A18 (iPhone 16 Pro). It also has a Neural Accelerator
   overflow in `ConvTransposed1d` that hits Kokoro's vocoder on A19 (iPhone 17 Pro) (#29).
   Both are fixed in 0.30.6.

`setup.sh` fetches the exact upstream commits into `Vendor/` (git-ignored) and applies
`patches/kokoro-ios.patch` and `patches/MisakiSwift.patch`. The patches bump mlx-swift to 0.30.6,
list the resource files one by one, and drop `subdirectory: "Resources"` from 5 lookups. The
model code is unchanged. Note that MisakiSwift silently returns an empty dictionary when a
lookup fails, so the smoke test checks that "colonel" and "Wednesday" come out as the
dictionary pronunciations.

**Consequence: shipping this means owning a fork.** It is small today, but MLX upgrades and
G2P fixes become ours.

---

## 4. Licenses

| Part | License | Status |
|---|---|---|
| kokoro-ios code | MIT | 🟢 |
| MisakiSwift code | Apache-2.0 | 🟢 |
| Misaki dictionaries (`us/gb_gold`, `us/gb_silver`) | Apache-2.0 (hexgrad/misaki). Where the entries come from isn't documented separately | 🟢 (check provenance before release) |
| BART G2P fallback weights (`us/gb_bart`) | Shipped in MisakiSwift under Apache-2.0. Upstream origin not documented in the repo | 🟡 confirm with the author before release |
| **Text-to-phoneme: espeak-ng** | GPL-3.0 | 🔴 but **not included**: the eSpeakNG dependency is commented out in kokoro-ios, so `.eSpeakNG` compiles to "no such engine". Nothing GPL is in the resolved graph |
| Kokoro-82M weights | Apache-2.0 | 🟢 |
| Voice packs (English) | Apache-2.0 at the repo level (hexgrad/Kokoro-82M). Only some Japanese/French voices are CC BY, none we use | 🟢 |
| Training data | Permissive / public domain, plus synthetic audio from closed TTS providers (per the model card) | 🟢 for us. A provider-ToS question is upstream's, not ours |
| mlx-swift | MIT | 🟢 |
| MLXUtilsLibrary | Apache-2.0 | 🟢 |
| swift-numerics | Apache-2.0 | 🟢 |
| ZIPFoundation | MIT | 🟢 |
| KokoroTestApp (where we copy the weight/voice files from) | Apache-2.0 | 🟢 |

Apache-2.0 obligations: include the licenses (and NOTICE files where present) in the app's
acknowledgements.

---

## 5. Measurements

### 5.1 App size (Release, arm64, uncompressed)

| Part | Size |
|---|---|
| Weights `kokoro-v1_0.safetensors` (fp32) | 327 MB |
| Voices: all 28 English voices / one voice | 14.6 MB / 0.5 MB |
| Misaki dictionaries + BART (US and GB; US only is ~9 MB) | 18 MB |
| MLX runtime (`Cmlx` 33 MB, `MLX` 4.5 MB, `default.metallib` 3.6 MB, MLXNN, KokoroSwift, MisakiSwift, others) | ~45 MB |
| **Total added** | **~390 MB** (the Release app went from ~5 MB to 394 MB) |

The weights barely compress (floats). To cut this: test bf16 weights (~164 MB,
`mlx-community/Kokoro-82M-bf16`; key names may differ from what kokoro-ios expects), ship 2–3
voices, US dictionaries only. A realistic floor is ~220 MB. Beyond that, deliver the model
with Background Assets instead of the app bundle, and fall back to the Apple voice until it's there.

### 5.2 Mac baseline (M1 Pro, optimized build, smoke test, model only, no audio output)

Warm (after one generation), af_heart:

| Line | First chunk | Total | Audio | Real time |
|---|---|---|---|---|
| happy | 0.81 s* | 1.01 s | 5.85 s | 5.8× |
| thirsty | 0.21 s | 0.41 s | 5.03 s | 12.4× |
| sleepy | 0.19 s | 0.44 s | 5.72 s | 12.9× |
| happy, 50% af_heart + am_puck | 0.24 s | 0.44 s | 5.65 s | 12.8× |
| happy, bf_emma (first GB) | 0.62 s* | 0.85 s | 6.30 s | 7.4× |

\* includes one-time costs: the first generation builds Metal kernels and the G2P, and
**every switch between a US and a GB voice rebuilds the G2P** (~0.4–1.2 s). Weights load in 0.6 s
(lazily). Blending costs nothing measurable.

Memory (Mac, `phys_footprint`): 72 MB after load, **600–800 MB steady, 1.3–1.6 GB peak**
while generating a ~6 s utterance (MLX peak 1.36 GB). Without a cap on MLX's buffer cache it
grew to **11.7 GB after 9 utterances**, so the spike sets `Memory.cacheLimit = 32 MB` and
calls `Memory.clearCache()` after each chunk. Any real integration must do the same.

### 5.3 iPhone (to fill in from the spike screen: Release build, warm unless noted)

The K0 baseline (17 Pro, 13 Pro, 12 Pro) is recorded in [M5c-kokoro.md](../plans/M5c-kokoro.md) section 1,
including the measurement note: Release, "Debug executable" unticked, Metal API Validation off,
GPU Frame Capture disabled. The table below is the per-line template.

Run each line 3× and take the middle value. *First audio* is the latency Sprout would have.

| | iPhone 17 Pro | iPhone 13 Pro |
|---|---|---|
| Model load + warm-up (first open) | | |
| Happy, af_heart: first audio / generation / real time | | |
| Thirsty, af_heart | | |
| Sleepy, af_heart | | |
| Happy, 50% blend | | |
| First GB voice after a US one: first audio | | |
| Memory now / peak after 10 plays | | |
| Audible artifacts (static, clicks, gaps between sentences)? | | |
| Your verdict on the voice (vs. the best Apple voice) | | |

Expected from the author's 3.3× on a 13 Pro: about 0.6–0.9 s first audio for these lines.
**Use Release for the numbers.** In Debug, Xcode builds the packages (MLX's C++, the Swift G2P and model code)
unoptimized: on the Mac, Debug was about 4× slower (2.8× vs 12× real time), which would make
the iPhone look like a no-go. Debug is fine for the listening test itself.

---

## 6. Risks

1. **Unmaintained upstream.** kokoro-ios is a one-person project, stale since January 2026, and broken on
   Xcode 26 as published. We would own the fork (section 3).
2. **Chip-specific MLX numerics.** Wrong audio on A18/A19 was only fixed in mlx-swift 0.30.6.
   We need a listen on every chip family we support, and a guard: if a generated chunk's peak is
   above ~1.5, treat it as a failure and fall back (the smoke test uses this check).
3. **Memory.** ~0.7 GB resident and ~1.5 GB peak on top of the app. Speech recognition and the
   chat run at the same time. Jetsam risk on 4 GB devices; load the model only while the chat
   is open, and drop it on a memory warning.
4. **App size.** About +390 MB (section 5.1), over the 200 MB cellular prompt. This probably means
   Background Assets, which is then a first-launch download.
5. **No GPU in the background.** Metal work from a backgrounded app fails (kokoro-ios #18). Spoken
   replies only happen in the foreground today, but this must fall back, not crash.
6. **Numbers and names.** MisakiSwift has open bugs reading numbers (#16 "numbers in the 20s are
   misread", #23, #26, #27), and Sprout says numbers ("soil at 23 %"). Spell numbers out in
   PlantChat before speaking, or fix them in the fork.
7. **No streaming within a sentence.** First audio is the time to generate the whole first
   sentence. Long first sentences mean a late start; split on commas too if needed.
8. **One language per voice.** A US↔GB switch costs up to ~1 s of G2P rebuild. Keep each
   personality's voice in one accent.
9. **Simulator and CI.** MLX doesn't run in the Simulator, so the simulator always uses the fallback.
   Building needs Xcode's Metal Toolchain component (`xcodebuild -downloadComponent
   MetalToolchain`), and MLX adds minutes and ~2 GB of DerivedData to clean builds.
10. **Dynamic frameworks with exact pins.** kokoro-ios/MisakiSwift are `.dynamic` and pin mlx-swift
    exactly. This conflicts with any other MLX package we might add later (#26, #28).

---

## 7. Recommendation for M5c

Replan M5c around Kokoro if section 5.3 meets these numbers on the **iPhone 13 Pro**:
first audio ≤ 1 s warm, real time ≥ 2×, peak memory ≤ 1.5 GB, and no artifacts on the 17 Pro.
Otherwise keep M5c as planned (Apple voices + effect), which also stays Kokoro's fallback.

What carries over from the M5c plan:

- **S1 `PlantSpeechStyle`** (pitch cents, effect rate, mood adjustments) is unchanged. It drives the same
  `AVAudioUnitTimePitch`. Kokoro's `speed` takes the place of `AVSpeechUtterance.rate` on the Kokoro path.
- **S2 voice catalog and picker** stay for the fallback path only.
- **S3 `FallbackPlantSynthesizerClient`** is the heart of it: primary = a new
  `KokoroPlantSynthesizerClient` (a `PlantEffectSynthesizerClient`), fallback =
  `AVSpeechPlantSynthesizerClient`. It falls back right away when the model isn't ready (still
  loading, failed, memory warning, app in background, Simulator), on the 3 s start timeout,
  and on a chunk that fails the level check. A failure mid-reply ends the turn, as planned.
- **S4 engine graph** is the same graph. Kokoro gives 24 kHz mono Float32 buffers directly, so the
  `AVSpeechSynthesizer.write` part and most of the converter work go away.
- **S6/S7 voice lab** becomes this spike's screen, promoted: personality and mood pickers, the Kokoro
  voice, the blend and pitch, and Print values.

New steps:

- **K0 Fork:** kokoro-ios + MisakiSwift under our account with the section 3 patches, and number reading fixed.
- **K1 Model delivery:** test bf16 weights, cut to the chosen voices and US dictionaries, and decide bundle vs Background Assets.
- **K2 `KokoroPlantSynthesizerClient` and model lifecycle:** load when the chat opens, warm up once, unload on
  leave and on memory warnings. It lives in **its own local package, linked only by the app** and
  injected through the PlantChat protocol, so PlantKit's `swift test` never builds MLX.
- **K3 Sentence chunking** in PlantChat: pure and unit-tested, like `KokoroSpikeSentences`.
- **Style table:** `preferredVoiceIdentifier` becomes a Kokoro voice (plus an optional blend) per
  personality, chosen in the lab.

---

## 8. How to run the listening test

1. `ios/KokoroSpike/setup.sh` (vendors the patched packages and downloads ~340 MB, checksum-verified).
2. In Xcode, add the local package and link `KokoroSpikeiOS` (exact steps in the hand-off note).
3. Listen (Debug is fine): run on an iPhone, then Plant › Talk › sliders menu › **Voice spike**.
4. Time it (Release): Edit Scheme › Run › Build Configuration **Release**, Arguments › add
   `-KokoroSpike`, run on the iPhone. The app opens on the spike screen. Wait for "Ready",
   play each line 3×, and fill in 5.3. Set the scheme back to Debug and untick the argument afterwards.
5. Don't archive or TestFlight with the package linked: it adds ~390 MB to every configuration.

## 9. How to delete it

- Xcode: remove the KokoroSpike package from the project (Package Dependencies).
- Delete `ios/KokoroSpike/`.
- Remove the `#if DEBUG` voice spike bits: `PlantChatAction.voiceSpikeTap`, `voiceSpike` in
  `PlantChatPersonalityMenuView` and `PlantChatUIComposer`, the test
  `test_personalityMenuVoiceSpikeTap_sendsVoiceSpikeAction` and `simulateVoiceSpikeTap`, and
  `Route.voiceSpike`, `VoiceSpikeScreen`, the `-KokoroSpike` launch check and `rootContent` in
  `TalkingPlantApp.swift`.

Sources: [kokoro-ios](https://github.com/mlalma/kokoro-ios) (issues #18, #26, #29, #30, #31, #35),
[MisakiSwift](https://github.com/mlalma/MisakiSwift), [KokoroTestApp](https://github.com/mlalma/KokoroTestApp),
[hexgrad/Kokoro-82M](https://huggingface.co/hexgrad/Kokoro-82M) and its VOICES.md,
[hexgrad/misaki](https://github.com/hexgrad/misaki), [mlx-audio-swift](https://github.com/Blaizzy/mlx-audio-swift),
[FluidAudio Kokoro ANE](https://github.com/FluidInference/FluidAudio/blob/main/Documentation/TTS/KokoroAne.md).
