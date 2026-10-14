# M5c plan (Kokoro): Sprout's own voice

Replaces steps S3–S8 of [M5c-voice.md](M5c-voice.md). S1 (style) and S2 (voice catalog and
picker) are done and stay: S1's mood table now drives Kokoro's speed, and S2 stays for the
Apple fallback. Background and measurements: [docs/spikes/kokoro.md](../spikes/kokoro.md).
Decisions on the open questions are in section 10.

Scope:

- One Kokoro voice, **"sprout"**: af_heart blended with 55% af_nicole, baked into one file at
  build time, base speed ×1.05.
- No pitch effect. `AVAudioUnitTimePitch` is dropped. Moods change Kokoro's speed only.
- Ship only what Sprout needs: one voice, float16 weights, US English dictionaries only.
- Memory: load when the home screen appears, unload in the background and on a memory
  warning, speak in sentence chunks, cap MLX's cache. Target peak **under ~700 MB on iPhone
  13 Pro**; up to ~1 GB is accepted (decision 3). Kokoro runs only on devices with at least
  6 GB of RAM.
- Everything stays behind `PlantSynthesizerClient`, so `PlantChatViewModel` doesn't change.
  The Apple voice (`AVSpeechPlantSynthesizerClient`) is always the fallback.
- We own the patched kokoro-ios / MisakiSwift, vendored in the repo. No `setup.sh`.
- The spike screen and `ios/KokoroSpike/` are removed at the end.

Out of scope: more voices or accents, a voice picker for users, Background Assets (section
5 recommends bundling), the S5 wobble, the full S6/S7 voice lab, lip sync, spoken
notifications, and changes to the listening flow.

Steps K0–K12, one Sonnet session each (section 9).

---

## 1. Spike results

K0 baseline, spike build (af_heart + 55% af_nicole, speed 1.0, no pitch), fp32 weights, 28
voices, US + GB dictionaries, sentence chunks, 32 MB MLX cache:

| Device and build | First audio (warm) | Real time | Memory idle / peak | Model load |
|---|---|---|---|---|
| iPhone 17 Pro, Debug, debugger attached | 0.44–0.69 s | ~7× | 417 MB / 1291 MB | 10.3 s |
| iPhone 13 Pro, Debug, debugger attached | 0.71–1.21 s | 3.1–4.1× | 487 MB / 1156 MB | 52.6 s |
| iPhone 13 Pro, Release, debugger attached + Metal validation | not recorded | not recorded | — / ~730 MB | 37–39 s |
| iPhone 13 Pro, Release, no debugger, Metal API Validation off, GPU Frame Capture disabled | not recorded | not recorded | 516–577 MB / 706–735 MB | 5.95 s first launch, 0.94–0.98 s next launches |
| iPhone 12 Pro, Release, no debugger | not measured yet, check in K11 | | | |

**Measurement note.** All performance checks use Release with "Debug executable" unticked,
Metal API Validation off and GPU Frame Capture disabled. The debugger and Metal validation made
model loading ~6–40× slower, so the Debug and debugger rows above say nothing about the shipped
app. Targets: model load **under 3 s on the 13 Pro on a normal launch**, peak memory **under
700 MB** (section 7).

The clean Release row already sits at the 700 MB line, which is why decision 3 allows up to ~1 GB.

---

## 2. What ships

### 2.1 Expected sizes

Worked out from the tensor shapes in `kokoro-v1_0.safetensors` (81.8 M parameters, all fp32).
K1's script reports the real numbers.

| Part | Spike | Plan |
|---|---|---|
| Weights | 327 MB (fp32) | **~164 MB fp16** (8-bit would be ~151 MB, not shipped: decision 4) |
| Voices | 14.6 MB (28 voices) | **0.5 MB** (`sprout.safetensors`, 510 × 1 × 256 fp32) |
| Dictionaries | 18 MB (US + GB) | **9.1 MB** (`us_gold`, `us_silver`, `us_bart`) |
| MLX runtime + Swift code | ~45 MB | ~44 MB (MLXUtilsLibrary and ZIPFoundation dropped if K2 confirms they're unused) |
| **Added to the app** | **~390 MB** | **~218 MB** |

**Why 8-bit was dropped:** MLX quantizes only `Linear` and `Embedding` weights, which is
13.2 M parameters here. **57.8 M parameters (71%) are 3-D convolution weights** (the
weight-normed `Conv1d` / `ConvTranspose1d` in the decoder, the text encoder's CNN and the
prosody predictor), and MLX has no quantized convolution. The predictor LSTMs (10.7 M)
are plain matrices that kokoro-ios multiplies by hand, so they can only be quantized with a fork
change. So 8-bit would save roughly 13 MB of 164 MB. We ship float16 only (decision 4). The
asset script still reports what 8-bit would save, for the record.

### 2.2 The Sprout voice

`sprout = af_heart × 0.45 + af_nicole × 0.55`, the same linear mix the spike used. Stored as
one fp32 tensor named `sprout` in `sprout.safetensors`, read with `MLX.loadArrays`, so the app
doesn't need `NpyzReader`. The base speed of 1.05 lives next to the voice in PlantKokoro
(`KokoroSproutGenerator.baseSpeed`).

### 2.3 Speed from the style

Pitch is gone, so `pitchCents` and `wobbleCents` have no reader left. K3 removes them and
renames `effectRate` to `speed`: 1 means the voice's normal speed. The base table and mood
factors stay as they are:

```
Kokoro speed = KokoroSproutGenerator.baseSpeed (1.05) × style.speed
style.speed  = personality base × mood factor (happy ×1.05; thirsty, veryThirsty, tooHot, tooCold ×0.92;
               drowning ×0.90), clamped 0.5…2
```

`rate` and `preferredVoiceIdentifier` still drive the Apple fallback, as in S1/S2.

---

## 3. Design

### 3.1 Where the code goes

```
ios/
├── PlantKit/                               # unchanged rule: no MLX, `swift test` stays fast
│   └── Sources/PlantChat/
│       ├── Domain/PlantSpeechChunker.swift                 # K3, pure
│       ├── Client/PlantPrimarySynthesizerClient.swift      # K4, protocol + PlantSpeechEvent
│       ├── Client/PlantSpeechGeneratorClient.swift         # K5, protocol
│       ├── Client/PlantSpeechPlayerClient.swift            # K5, protocol
│       ├── Client/AVAudioEnginePlantSpeechPlayerClient.swift  # K6, AVFoundation
│       ├── API/FallbackPlantSynthesizerClient.swift        # K4 (the old S3)
│       └── API/ChunkedPlantSynthesizerClient.swift         # K5
├── PlantKokoro/                            # new local package, linked only by the app
│   ├── Package.swift
│   ├── Vendor/KokoroSwift/                 # kokoro-ios 1.0.11 + our changes (MIT)
│   ├── Vendor/MisakiSwift/                 # MisakiSwift 1.0.6 + our changes, US only (Apache-2.0)
│   ├── Vendor/README.md                    # upstream URLs, commits, our changes, licenses
│   ├── Sources/PlantKokoro/
│   │   ├── KokoroSproutGenerator.swift     # MLX on a serial queue: prewarm, generate, unload
│   │   ├── KokoroMemory.swift              # phys_footprint now / peak (from the spike)
│   │   └── Resources/                      # generated by tools/kokoro, git-ignored
│   └── Tests/PlantKokoroTests/             # opt-in smoke test (xcodebuild, macOS)
└── TalkingPlant/TalkingPlant/
    ├── AppGraph.swift                      # wiring + model lifecycle
    └── VoiceCheckView.swift                # DEBUG only, replaces the spike screen
tools/kokoro/                               # build-time assets: Makefile, build_assets.py, requirements.txt, assets.sha256
```

- **PlantKokoro doesn't import PlantKit.** `KokoroSproutGenerator` has exactly the shape of
  `PlantSpeechGeneratorClient`. The app adds the conformance in one line
  (`extension KokoroSproutGenerator: PlantSpeechGeneratorClient {}`). Only the composition root
  knows both, and no feature imports another.
- All decision logic (chunks, events, fallback, level check) is in PlantChat and unit-tested
  with spies. PlantKokoro and the AVAudioEngine player only wrap MLX and system APIs.

### 3.2 Shape

```
PlantChatViewModel ──► PlantSynthesizerClient                         (unchanged)
                         └─ FallbackPlantSynthesizerClient            PlantChat/API, K4
                              ├─ primary: PlantPrimarySynthesizerClient
                              │    └─ ChunkedPlantSynthesizerClient   PlantChat/API, K5
                              │         ├─ generator: PlantSpeechGeneratorClient
                              │         │    └─ KokoroSproutGenerator               PlantKokoro, K2
                              │         └─ player: PlantSpeechPlayerClient
                              │              └─ AVAudioEnginePlantSpeechPlayerClient  PlantChat/Client, K6
                              └─ fallback: AVSpeechPlantSynthesizerClient            (existing)
```

```swift
// PlantChat/Client
@MainActor public protocol PlantPrimarySynthesizerClient {
    /// Sends `.started` once audio plays, then exactly one `.finished` or `.failed`. Nothing after `stop()`.
    func speak(_ text: String, style: PlantSpeechStyle, update: @escaping (PlantSpeechEvent) -> Void)
    func stop()
}
public enum PlantSpeechEvent: Equatable, Sendable { case started, finished, failed }

@MainActor public protocol PlantSpeechGeneratorClient {
    /// 24 kHz mono samples for one chunk. `speed` 1 is the voice's normal speed.
    /// Waits for a load that is in progress. Throws right away when the model is neither
    /// loaded nor loading. The caller's 3 s start timeout bounds the wait.
    func generate(_ text: String, speed: Float) async throws -> [Float]
}

@MainActor public protocol PlantSpeechPlayerClient {
    /// Starts the engine. Throws if it can't.
    func start() throws
    /// Queues 24 kHz mono samples. `completion(true)` once played back, `(false)` if playback
    /// broke (interruption, route change, media reset). Never called after `stop()`.
    func enqueue(_ samples: [Float], completion: @escaping (Bool) -> Void)
    /// Stops at once, synchronously.
    func stop()
}
```

`PlantPrimarySynthesizerClient` is S3's `PlantEffectSynthesizerClient` under a new name,
because there is no effect any more.

### 3.3 FallbackPlantSynthesizerClient

Exactly M5c-voice.md 2.4 (state table, generation counter, injected `schedule`, 3 s start
timeout, log on each fallback), with the renamed types. The Kokoro cases it covers:

- model not loading and not loaded (unloaded, Simulator, app in the background, device under
  6 GB) → the generator throws → `.failed` before `.started` → Apple voice speaks the same text;
- model still loading → the generator waits for the load, and the 3 s start timeout below is
  the wait budget (decision 2). The budget covers the wait and the first chunk;
- first chunk fails the level check → same;
- nothing playing after 3 s → Apple voice;
- failure after `.started` → the turn ends, nothing is replayed.

### 3.4 ChunkedPlantSynthesizerClient

`init(generator:player:)`. One utterance:

1. `stop()` whatever is pending; bump the generation.
2. `chunks = PlantSpeechChunker.chunks(text)`. Empty → `.finished`.
3. `player.start()`. A throw → `.failed`.
4. Generate chunk 0 with `speed: style.speed`. A throw → `.failed`.
5. **Level check:** a chunk that is empty or has a peak `abs` above 1.5 counts as a failure
   (spike risk 2: MLX numerics on new chips).
6. Enqueue it, send `.started`, start generating the next chunk while this one plays
   (one ahead, never more).
7. Every chunk generated and played back → `.finished`.
8. Any failure after `.started` (generation, level, `completion(false)`) → `player.stop()`, `.failed`.
9. `stop()`: bump the generation, `player.stop()`, send nothing. Late generation results
   are dropped by the generation check.

It logs (`Logger`, category `voice`) the time from `speak` to `.started` ("first audio").
Release measurements rely on this line.

### 3.5 PlantSpeechChunker

Pure, in `PlantChat/Domain`, a port of the spike's `KokoroSpikeSentences` (and its tests):

- split after `.`, `!`, `?`, `…`, keeping the punctuation; don't split decimals ("2.5") or
  common abbreviations ("Mr.", "e.g.");
- a sentence over `maxWords` (default 20) is split at its last `,` `;` `:` before the cap,
  otherwise at the cap;
- whitespace trimmed, empty chunks dropped.

Shorter chunks lower both the time to first audio and the peak memory (K10 tunes
`maxWords`).

### 3.6 KokoroSproutGenerator (PlantKokoro)

```swift
@MainActor public final class KokoroSproutGenerator {
    public static let baseSpeed: Float = 1.05
    public init(resources: URL = Bundle.module.resourceURL!)
    /// Loads the weights and voice, generates "Hi." once (G2P + Metal kernels). Idempotent.
    public func prewarm() async throws
    /// Drops the model and clears MLX's cache. A pending generation finishes, then is dropped.
    public func unload()
    /// Waits for a prewarm in progress. Throws `.notLoaded` when none is running and the model
    /// isn't loaded; `.unavailable` in the Simulator.
    public func generate(_ text: String, speed: Float) async throws -> [Float]
}
```

- MLX runs on one private serial `DispatchQueue` (as in the spike), never on the main actor or
  the cooperative pool. Results come back through `withCheckedThrowingContinuation`.
- `Memory.cacheLimit = 32 MB`, and `Memory.clearCache()` after each chunk and on unload.
- Logs load time, warm-up time, each chunk's generation time and the `phys_footprint` peak.
- `Language.enUS` only.

### 3.7 Model lifecycle (app)

All in the composition root. The chat view model doesn't know about it. Kokoro is created only
on devices with at least 6 GB of RAM (`ProcessInfo.physicalMemory`, compared with a threshold
just under 6 GB because iOS reports slightly less than the marketing size; K7 checks the value
the 13 Pro reports). On other devices the app uses the Apple voice alone.

| When | Then |
|---|---|
| the home screen appears | `Task { try? await voice.prewarm() }` (idempotent) |
| scene phase `.active` | same, so a model dropped in the background comes back |
| scene phase `.background` | `voice.unload()` (no GPU in the background, and less jetsam risk) |
| `UIApplication.didReceiveMemoryWarningNotification` | `voice.unload()` |

The model stays loaded while the app is in the foreground, including after the chat closes
(decision 2 replaces "unload when the chat closes"). If a reply is due before the load is done,
it waits up to 3 s for Kokoro and then the Apple voice speaks it. After a memory-warning unload,
replies use the Apple voice until the next prewarm.

### 3.8 Player (`AVAudioEnginePlantSpeechPlayerClient`)

M5c-voice.md 2.5 and 2.6 without the synthesizer, converter, time-pitch or wobble:

- graph `AVAudioPlayerNode ──(24 kHz mono Float32)──► mainMixerNode`, built on the first `start()`;
- `engine.inputNode` is never touched; the session is never set or activated here;
- `engine.stop()` once the last buffer has played back, so the mic gets the hardware cleanly;
- `scheduleBuffer` completions are made in `nonisolated static` functions and hop with
  `DispatchQueue.main.async { MainActor.assumeIsolated { … } }` (ARCHITECTURE.md section 3);
- interruption, `AVAudioEngineConfigurationChange` and media services reset → every pending
  `completion(false)`; the graph is rebuilt on the next `start()`.

---

## 4. Owning the fork

**Recommendation: vendor it into the repo as plain targets of the PlantKokoro package.**

| | Vendored in `ios/PlantKokoro/Vendor/` | Forks on GitHub |
|---|---|---|
| Build | `Package.swift` points at local target paths. Only mlx-swift is fetched | Two more remote packages, pinned by `revision:` |
| Changing it | One commit in this repo, reviewed in Xcode with the rest | Push to the fork, bump the pin, then change the app |
| Our changes so far | Resource paths, mlx-swift 0.30.6, US only, fp16 loading, weight-norm folding, maybe number fixes | Same, across two repos |
| Upstream fixes | Merged by hand (upstream has been stale since Jan 2026) | `git merge upstream`, easier if upstream comes back |
| Size in git | ~6k lines of Swift + 9.1 MB of US dictionaries | none |

How it builds without `setup.sh`:

- `ios/PlantKokoro/Package.swift` declares `KokoroSwift` and `MisakiSwift` as **targets**
  (`path: "Vendor/KokoroSwift"`), not as packages. There is no `.dynamic` product and no
  `exact:` pin inside a nested manifest (spike risk 10). The only remote dependency is
  `mlx-swift` (exact 0.30.6, the version with the A18/A19 fixes).
- The spike's patches are applied once, when the code is copied in. Then they're just
  code. `Vendor/README.md` lists the upstream commits, every change we made, and keeps the
  upstream `LICENSE` files.
- Resources are listed file by file (the codesign fix), US only. `.enGB` and `.eSpeakNG`
  throw "unsupported".
- The model files come from `make -C tools/kokoro assets` (section 6), which you run once
  per clone, like `make -C firmware test`. An Xcode build phase fails with that command
  in the message when they're missing.

---

## 5. Model delivery

**Recommendation: bundle it in the app for M5c.** Reconsider Background Assets only before
an App Store release, and only if the thinned download is over 200 MB.

| | Bundled | Background Assets (Apple-hosted, iOS 26) |
|---|---|---|
| App download | ~220 MB uncompressed. fp16 barely compresses, so expect around 200 MB thinned (K11 measures it) | ~55 MB |
| Total bytes for the user | same | same |
| First launch | Kokoro ready after the first prewarm | Apple voice until the pack finishes downloading |
| Work | none | a downloader extension target, `ba-package` packaging, App Store Connect / TestFlight hosting, `xcrun ba-serve` for local runs, a "downloaded?" state in the lifecycle |
| Offline / dev runs from Xcode | always works | needs the mock server or a DEBUG bundled copy |

The cost is the 200 MB cellular prompt, which users can allow. If the plan changes
later, only `KokoroSproutGenerator(resources:)` and the lifecycle table change. PlantChat
already falls back to the Apple voice while the model isn't ready.

---

## 6. Build-time assets (`tools/kokoro/`)

- `requirements.txt`: `mlx` and `numpy`, pinned. Installed into `tools/kokoro/.venv`
  (git-ignored) by the Makefile. Nothing from it ships.
- `build_assets.py` (run by `make -C tools/kokoro assets`):
  1. Downloads the spike's pinned `kokoro-v1_0.safetensors` and `voices.npz` into a cache
     (same URLs and checksums as `setup.sh`).
  2. Writes `sprout.safetensors` (section 2.2).
  3. Writes `kokoro-f16.safetensors`: every float tensor as fp16, keys unchanged.
  4. Prints a report: file sizes; parameters and bytes per component (bert, predictor,
     text_encoder, decoder); and, for the record only, what 8-bit would save: which tensors
     MLX could quantize and **which it can't, with the reason** (3-D conv: no quantized conv in
     MLX; LSTM matrices: used by hand, not `Linear`), with the size and the round-trip error
     per tensor. No 8-bit file is written.
  5. Writes into `ios/PlantKokoro/Sources/PlantKokoro/Resources/` and checks every output
     against `tools/kokoro/assets.sha256` (committed). `--update-checksums` rewrites it.
- `.gitignore`: the generated files, the cache and `.venv`.

---

## 7. Measuring on the device

All performance checks use a **Release** build run from Xcode with "Debug executable"
unticked, Metal API Validation off and GPU Frame Capture disabled (measurement note in
section 1). With the debugger or Metal validation on, model loading is ~6–40× slower, and
numbers taken that way are not comparable.

- **Time to first audio:** the `voice` log line "first audio X s" (3.4). Run the three spike
  lines 3× each with the voice check screen for listening, and in normal chat turns for
  numbers. Take the middle value.
- **Peak memory:** the generator's `phys_footprint` peak log after 10 replies, compared with
  Xcode's memory gauge. Use Instruments › Allocations once in K10. The model now stays
  loaded on the home screen, so also note the idle footprint there.
- **Load time:** the generator's "load / warm-up" log line after the home screen appears. Report
  the first launch after install and a normal launch separately (13 Pro in the spike: 5.95 s
  and ~1 s).
- **App size:** Product › Archive (Release) › Distribute App › Custom › Release Testing (or
  Development) › App Thinning: "iPhone 13 Pro". Read `App Thinning Size Report.txt`, which has
  the compressed (download) and uncompressed (install) sizes.

Targets, all on the **iPhone 13 Pro**:

| | Target |
|---|---|
| First audio, warm | ≤ 1 s |
| Model load, normal launch | < 3 s |
| Peak memory over 10 replies | < 700 MB. Up to ~1 GB is accepted if there are no crashes or memory warnings (decision 3) |
| Thinned download | report it. < 200 MB avoids the cellular prompt |

---

## 8. Test doubles

In `PlantChatXCTestCase`:

- `PrimarySynthesizerSpy`: records `speak` / `stop` and sends events by index (the old
  `EffectSynthesizerSpy`).
- `GeneratorSpy`: records `(text, speed)`; completes each request by index with samples or an
  error.
- `PlayerSpy`: records `start` / `enqueue` / `stop`; `start` can throw; completes enqueues by index
  with `true` / `false`.
- `ScheduleSpy`, `SynthesizerSpy`: existing, reused.

---

## 9. Steps

Each step leaves `swift test --filter PlantChatTests` green (when it touches PlantKit) and
the app building. No commits. You run PlantChatiOSTests and the device checks.

### K0. iPhone 13 Pro baseline (you, with the spike) — done

- Baseline recorded in section 1, with the measurement note. The 12 Pro row is filled in K11.
- **Go/no-go** (spike section 7): first audio ≤ 1 s warm, ≥ 2× real time, peak ≤ 1.5 GB, no
  artifacts. Real time (3.1–4.1×) and peak (≤ 1156 MB) pass. First audio in a clean Release
  build and the artifact check are not in the recorded numbers; confirm them from the K7 logs.
  A no-go stops this plan, and M5c goes back to the Apple-voice plan.
- Done before K7, which unlinks the spike package.

### K1. Asset script

- **Files:** `tools/kokoro/Makefile`, `requirements.txt`, `build_assets.py`, `assets.sha256`,
  `README.md` (one paragraph); `.gitignore` entries.
- **Checks (in the script, not XCTest):** the blend equals `0.45·heart + 0.55·nicole` on
  every value; every fp16 tensor round-trips within fp16 precision; the outputs match
  `assets.sha256`.
- **Done when:** `make -C tools/kokoro assets` on a clean checkout produces two files
  (`sprout.safetensors`, `kokoro-f16.safetensors`) and the report. Paste the report into the step summary. It replaces the estimates in 2.1.

### K2. PlantKokoro package: vendored fork + generator (fp16)

- **Files:**
  - `ios/PlantKokoro/Package.swift` (iOS 26 / macOS 15, Swift 6 mode for our target;
    vendored targets may stay in Swift 5 mode if they need it).
  - `Vendor/KokoroSwift/`, `Vendor/MisakiSwift/`: copied from the upstream commits in `setup.sh`
    with both spike patches applied. Then: GB resources removed, the eSpeakNG processor
    removed, `BenchmarkTimer` calls removed, and the MLXUtilsLibrary dependency dropped if
    nothing else needs it (`NpyzReader` isn't needed any more). `Vendor/README.md`.
  - `Sources/PlantKokoro/KokoroSproutGenerator.swift` (3.6),
    `KokoroMemory.swift` (from `KokoroSpikeMemory+Current.swift`).
  - `Tests/PlantKokoroTests/KokoroSproutGeneratorSmokeTests.swift`: opt-in like the spike's
    (the command is in the file): prewarm, generate "Hi." and a 2-sentence line, samples are
    non-empty with peak ≤ 1.5, "colonel" and "Wednesday" come out with the dictionary
    pronunciation (catches a silent dictionary load failure), `generate` before `prewarm`
    throws `.notLoaded`, `generate` during a `prewarm` waits and then succeeds, `unload` then
    `generate` throws.
- **Check that fp16 works as is:** `MLX.loadArrays` keeps fp16, and fp32 inputs promote each
  op to fp32. If the smoke test or a listen shows a problem, add one switch in `WeightLoader`
  that upcasts at load (no size change, but weights take 327 MB in memory again) and note it.
- **Done when:** the smoke test passes on the Mac, and `xcodebuild -scheme PlantKokoro
  -destination generic/platform=iOS build` builds with no `setup.sh`.

### K3. Style cleanup and chunker (PlantChat, pure)

- **Files:** `PlantChat/Domain/PlantSpeechStyle.swift` (remove `pitchCents`, `wobbleCents`
  and their ranges; `effectRate` → `speed`, `speedRange`); every reader;
  `PlantChat/Domain/PlantSpeechChunker.swift`; `PlantSpeechStyleTests.swift`,
  `PlantSpeechChunkerTests.swift`.
- **Tests:** the S1 style tests rewritten for `speed` (table per personality; happy faster;
  low moods slower; drowning slower; nil/tooDark/dryAir/offline unchanged; clamps). Chunker:
  the spike's sentence tests ported; decimals and abbreviations don't split; long sentence
  splits at the last comma before `maxWords`, and at the cap with no comma; whitespace and
  empty input give no chunks; a single short sentence is one chunk.

### K4. Fallback composite (the old S3)

- **Files:** `PlantChat/Client/PlantPrimarySynthesizerClient.swift`,
  `PlantChat/API/FallbackPlantSynthesizerClient.swift`, `PrimarySynthesizerSpy`,
  `FallbackPlantSynthesizerClientTests.swift`.
- **Tests:** the S3 list in M5c-voice.md section 7, unchanged apart from the names, plus: a
  primary that is still waiting for the model at the 3 s timeout → the Apple voice speaks, and
  a primary result arriving after that is dropped.
- Not wired yet.

### K5. Chunked client

- **Files:** `PlantChat/Client/PlantSpeechGeneratorClient.swift`,
  `PlantSpeechPlayerClient.swift`, `PlantChat/API/ChunkedPlantSynthesizerClient.swift`,
  `GeneratorSpy`, `PlayerSpy`, `ChunkedPlantSynthesizerClientTests.swift`.
- **Tests:**
  - init does nothing;
  - speak starts the player and asks for chunk 0 with `style.speed`;
  - a generator that waits for a load: nothing is sent until it completes, then `.started`
    follows normally;
  - `start()` throws → `.failed`, nothing generated;
  - chunk 0 throws → `.failed`, no `.started`;
  - chunk 0 too loud (peak > 1.5) or empty → `.failed`, nothing enqueued;
  - chunk 0 ok → enqueued, `.started` once, chunk 1 requested (and never chunk 2 before 1 is
    enqueued);
  - all chunks generated and played → `.finished` once;
  - a later chunk throws or fails the level check → player stopped, `.failed`, no
    `.finished`;
  - `completion(false)` → player stopped, `.failed`;
  - stop → player stopped, no event, late generator results and completions ignored;
  - speak while speaking: the first sends nothing more, the second runs normally;
  - empty text → `.finished`, the player never started;
  - `test_speak_doesNotCreateMemoryLeaks`.

### K6. Player

- **Files:** `PlantChat/Client/AVAudioEnginePlantSpeechPlayerClient.swift` (3.8). Interruption
  and media-reset observers inside `#if os(iOS)`.
- **Tests:** none, it wraps system APIs. `swift test` still compiles it on macOS.

### K7. Wiring and lifecycle

- **You, in Xcode (hand-off note with exact steps):** remove the KokoroSpike package from the
  app. The `#if canImport` spike code then shows its placeholder; it is deleted in K12. Both
  packages define a `KokoroSwift` module, so they can't be linked together. Run `make -C
  tools/kokoro assets`, add `ios/PlantKokoro`, and link `PlantKokoro` to the app.
- **Files:** `AppGraph.swift`: the conformance line,
  `FallbackPlantSynthesizerClient(primary: ChunkedPlantSynthesizerClient(generator: voice,
  player: AVAudioEnginePlantSpeechPlayerClient()), fallback: AVSpeechPlantSynthesizerClient())`,
  the memory-warning observer and the 6 GB RAM gate (no `KokoroSproutGenerator` below it, Apple
  voice only). `TalkingPlantApp.swift`: home-screen appear and scene-phase handling (3.7).
  The missing-assets build phase (section 4).
- **On device (17 Pro, then 13 Pro):**
  - the home screen appearing logs load + warm-up; a reply due during the load waits up to 3 s
    and then uses the Apple voice (the fallback is logged), and replies after "ready" use
    Sprout's voice;
  - happy sounds a bit faster than thirsty; no clicks or gaps between sentences; the last
    word isn't clipped;
  - a 3–4 sentence reply plays to the end and the mic works right after;
  - tapping the mic mid-reply cuts it at once, and the transcript doesn't contain Sprout's words;
  - a call or Siri mid-reply stops it, and the next turn works; AirPods out stops it;
  - going to the background logs unload and the memory gauge drops, and coming back reloads;
    a simulated memory warning unloads too, and the next reply uses the Apple voice;
  - the 13 Pro passes the 6 GB gate; the surfer and butler personalities speak with Sprout's
    voice;
  - the Simulator speaks with the Apple voice;
  - Release (section 7 settings): first audio, load time and peak memory logged.

### K8. DEBUG voice check screen

Replaces the spike screen, reusing its uncommitted menu plumbing (rename `voiceSpikeTap` →
`voiceCheckTap`, `Route.voiceSpike` → `.voiceCheck`, and the test
`test_personalityMenuVoiceCheckTap_sendsVoiceCheckAction`).

- **Files:** `TalkingPlant/VoiceCheckView.swift` (`#if DEBUG`, app target like
  `TestPeripheralView.swift`); the renamed bits in `PlantChatAction`,
  `PlantChatPersonalityMenuView`, `PlantChatUIComposer`, `PlantChatUIITests`,
  `PlantChatView+ViewInspector`, `TalkingPlantApp.swift`.
- **Screen:** line picker (happy / thirsty / sleepy from the spike, plus a numbers line:
  "My soil is at 23 percent, and it's 21.5 degrees."), mood picker, Play / Stop, and readouts:
  load + warm-up, first audio, generation time, footprint now / peak. It uses the real
  `ChunkedPlantSynthesizerClient` and its own `KokoroSproutGenerator` (prewarm on appear,
  unload on disappear), so it measures the production path.
- **Tests:** the renamed menu test only. The screen is DEBUG tooling in the app target.
- **On device:** the menu entry opens it; numbers match the K7 logs.

### K9. Removed

The 8-bit weights and the A/B toggle are dropped (decision 4). Float16 is the only format. The
step number stays so K10–K12 keep their names.

### K10. Memory pass (13 Pro)

Measure after each lever with the voice check screen (Release, section 7 settings, 10 plays of
each line) and keep only the ones that help. Stop once the peak is under ~700 MB, or when
it is under ~1 GB with no crashes or memory warnings (decision 3).

1. **Fold weight norm at build time.** kokoro-ios recomputes `g · v / ‖v‖` for every
   convolution on every call. That materializes ~57.8 M fp32 weights (~230 MB) per
   generation. The script writes the folded `weight` instead of `weight_g` / `weight_v`.
   `ConvWeighted` takes it as is, and `WeightLoader`'s transposition rule moves with it. The smoke test
   compares folded against unfolded output for "Hi." (fixed `MLXRandom` seed, small max
   abs difference). This should also speed up generation.
2. **Smaller chunks:** try `maxWords` 20 → 12. Listen for choppy prosody.
3. **Evaluate per stage:** `eval()` after the BERT/duration stage and after the prosody stage in
   `KokoroTTS.generateAudio`, so their intermediates are freed before the decoder runs.
4. **MLX cache:** check that 32 MB is still right. Try `Memory.memoryLimit` as a ceiling.
5. **Load time:** target under 3 s on the 13 Pro on a normal launch (5.95 s first launch,
   ~1 s after, in the spike). Split the log into weights / G2P dictionaries / first generation,
   and fix anything cheap (for example, start the "Hi." warm-up only after the dictionaries load).

- **Files:** whichever levers are kept, with their tests (chunker test for `maxWords`, smoke
  test for folding), `build_assets.py`, `assets.sha256`.
- **Done when:** the section 7 targets are met, or the peak is within the ~1 GB allowance
  of decision 3 with no crashes or memory warnings.

### K11. Ship size

- **Files:** `assets.sha256` updated if K10 changed the assets. Nothing else to remove: there
  is no 8-bit option (decision 4).
- **On device (you):** Release archive with the App Thinning report for iPhone 13 Pro (section 7).
  Record download and install sizes. Measure the iPhone 12 Pro (Release, no debugger) and fill
  in its row in section 1. A last listen of every shown personality, happy and thirsty.

### K12. Remove the spike, docs

- **Delete:** `ios/KokoroSpike/`, and the `#if canImport(KokoroSpikeiOS)` code, `VoiceSpikeScreen`,
  `rootContent`'s `-KokoroSpike` check and `voiceSpike` in `TalkingPlantApp.swift` (spike section 9;
  the menu bits were already renamed in K8). Check the scheme for a leftover `-KokoroSpike`
  argument.
- **Docs:**
  - `docs/ROADMAP.md`: an M5c section linking this plan.
  - `docs/SETUP.md`: `xcodebuild -downloadComponent MetalToolchain`, `make -C tools/kokoro
    assets` once per clone, and the smoke-test command.
  - `docs/ARCHITECTURE.md`: PlantKokoro in the section 2 tree and the dependency table
    ("linked only by the app; never imported by PlantKit"); audio-thread callbacks in section
    3 rule 2 (from M5c-voice.md section 5).
  - `docs/spikes/kokoro.md`: final numbers, and a line saying the spike code is gone.
  - `docs/plans/M5c-voice.md`: a note at the top that S3–S8 are replaced by this plan.
  - `CLAUDE.md` repo layout: `PlantKokoro/` and `tools/kokoro/`.

---

## 10. Decisions

1. **Personalities.** Sprout's Kokoro voice speaks every visible personality, including the
   surfer (en-AU) and the butler (en-GB). The personality is in the words and the speed.
   `language` only matters for the Apple fallback.
2. **Model loading.** Loading starts when the home screen appears, not when the chat opens. If
   a reply is due before the model is ready, it waits up to 3 s for Kokoro (the fallback's
   start timeout, which also covers the first chunk), then the Apple voice speaks it. The model
   stays loaded in the foreground and is dropped on background or a memory warning (3.7).
3. **Memory.** The target stays under 700 MB peak on the 13 Pro. If K10 can't get there, accept
   up to ~1 GB peak as long as there are no crashes or memory warnings. Kokoro is used only on
   devices with at least 6 GB of RAM; others use the Apple voice (3.7). The clean Release
   baseline is already 706–735 MB, so the allowance is likely to be used. The RAM gate is built
   in K7 either way, because 4 GB phones were never measured.
4. **Weights.** Float16 only. The 8-bit file, `.int8` loading and the A/B picker are removed
   (K1, K9, K11). The size report in K1 keeps the 8-bit numbers for the record.
5. **Unload grace period.** None. Decision 2 goes further: the model is no longer unloaded
   when the chat closes at all.
6. **Style cleanup (K3).** Yes: remove `pitchCents` / `wobbleCents` and rename `effectRate` →
   `speed`.
7. **Script tooling.** Yes: Python with `mlx` and `numpy`, pinned, in a git-ignored venv, build
   time only.
8. **Assets in git.** Generated weights stay out of git: one `make` per clone,
   checksum-verified. No Git LFS.
9. **Numbers.** Listen to the numbers line in K7/K8. Only if it sounds wrong, add a step:
   either spell numbers out before speaking (pure, in PlantChat, unit-tested) or fix the
   fork's `EnglishNum2Word`. No step now.
10. **Distribution.** No App Store or public TestFlight release in M5c. Revisit Background
    Assets (section 5), the Apache-2.0 / MIT acknowledgements screen and the dictionary/BART
    provenance check (spike section 4) before any release.
11. **Voice check screen after K11.** The plan gave no recommendation; kept as DEBUG tooling
    for future speed tuning, not deleted in K12. K12 only removes the spike.
12. **Chips.** Listening on the 13 Pro (A15) and 17 Pro (A19) is the check. The level check
    catches loud static but not quieter garbling. Trying an A16–A18 phone once is a bonus, not
    a blocker.
