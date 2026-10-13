# M5c plan: a cartoon voice for Sprout

Scope:

- Voice choice: the best installed voice for the style's language, with an optional
  preferred voice per personality.
- Character effect: render the speech to buffers and play it through `AVAudioEngine` with
  `AVAudioUnitTimePitch`.
- Style: `PlantSpeechStyle` gets `pitchCents`, `effectRate` (and `wobbleCents` for
  drowning), as a pure, unit-tested function of personality + mood.
- A DEBUG voice lab to tune the values on the device.
- Fallback to plain `AVSpeechSynthesizer.speak` so Sprout never goes silent.

Out of scope: downloading voices, Personal Voice, lip sync, spoken notifications, new
languages, AirPods audio quality (HFP), and any change to the listening flow or the chat
view model's state machine.

Implementation is split into steps S1–S8, one session each (section 7).

---

## 1. Why it sounds robotic today

- `AVSpeechSynthesisVoice(language:)` returns the default **compact** voice, even when an
  enhanced or premium voice is installed.
- `pitchMultiplier` is applied inside the synthesizer's own formant model. Past about ±10%
  it sounds damaged, not like a character.
- A time-pitch effect on a good voice shifts the pitch while keeping the timing, which is
  how cartoon voices are usually made.

---

## 2. Design

### 2.1 Slice

Everything stays in `PlantChat` / `PlantChatiOS`, as in M5b 1.1. `AVFoundation` is still
imported only inside `PlantChat/Client/`. The voice lab is DEBUG only and lives in the same
slice (`#if DEBUG`), because it drives PlantChat's own types.

### 2.2 Speech style

```swift
public struct PlantSpeechStyle: Equatable, Sendable {
    public let language: String
    /// AVSpeechUtterance's 0–1 scale, 0.5 is normal. How fast the voice itself talks.
    public let rate: Float
    /// Pitch shift of the effect, in cents (100 = one semitone).
    public let pitchCents: Float
    /// Playback speed of the effect, 1 is unchanged.
    public let effectRate: Float
    /// Depth of a slow pitch wobble, in cents. 0 is none.
    public let wobbleCents: Float
    /// Used when installed, otherwise the best voice for `language`.
    public let preferredVoiceIdentifier: String?
}
```

- `pitch` (the multiplier) is removed. Both paths speak with `pitchMultiplier = 1`
  (open question 1).
- `wobbleCents` and `preferredVoiceIdentifier` default to `0` and `nil` in the init.
- **Pure function:** `PlantPersonality.speechStyle` stays the base table, and
  `PlantSpeechStyle.adjusted(for mood: PlantMood?) -> PlantSpeechStyle` applies the mood.
  The chat speaks with `personality.speechStyle.adjusted(for: latestFacts?.mood)`. The lab
  uses the same `adjusted(for:)` on its slider values.
- **Clamps** (static constants, applied in `adjusted(for:)`): `pitchCents` −1200…1200,
  `effectRate` 0.5…2, `wobbleCents` 0…200, `rate` 0…1.

**Base table** (starting values, tuned with the lab in S8):

| Personality | Language | Rate | Pitch cents | Effect rate | Shown |
|---|---|---|---|---|---|
| cheerful | en-US | 0.50 | +500 | 1.00 | yes |
| chillSurfer | en-AU | 0.46 | +200 | 0.90 | yes |
| politeButler | en-GB | 0.48 | +100 | 1.00 | yes |
| dramatic | en-US | 0.46 | +300 | 0.95 | hidden |
| grumpyGrandma | en-IE | 0.42 | +150 | 0.95 | hidden |

`preferredVoiceIdentifier` is `nil` for all of them until the lab shows which voices sound
best.

**Mood adjustment** (added to the base, rates multiplied):

| Mood | Pitch cents | Effect rate | Wobble cents |
|---|---|---|---|
| happy | +100 | ×1.05 | 0 |
| thirsty, veryThirsty, tooHot, tooCold | −100 | ×0.92 | 0 |
| drowning | 0 | ×0.90 | 60 |
| tooDark, dryAir, offline, nil | 0 | ×1 | 0 |

### 2.3 Voice choice

New domain type and a pure picker:

```swift
public struct PlantSynthesisVoice: Equatable, Sendable {
    public enum Quality: Int, Comparable, Sendable { case standard, enhanced, premium }
    public let identifier: String
    public let name: String
    public let language: String
    public let quality: Quality
}

public enum PlantVoicePicker {
    public static func voice(for style: PlantSpeechStyle, among voices: [PlantSynthesisVoice]) -> PlantSynthesisVoice?
}
```

Rules, in order:

1. `style.preferredVoiceIdentifier` is installed → that voice.
2. Voices whose `language` equals `style.language`: highest quality first, then by name
   (so the choice is stable).
3. Same rule for `en-US`.
4. `nil`: the client uses `AVSpeechSynthesisVoice(language:)`, then `en-US`, as today.

`AVSpeechVoiceCatalog` (PlantChat/Client, internal to the clients but `public` for the app
and the lab):

- `installed() -> [PlantSynthesisVoice]` maps `AVSpeechSynthesisVoice.speechVoices()`.
  Novelty voices (`voiceTraits.isNoveltyVoice`) and Personal Voice are left out.
- `avVoice(for style:) -> AVSpeechSynthesisVoice?` runs the picker and looks the voice up
  by identifier, with rule 4 as the fallback.
- Both synthesizer clients use it, so the plain path and the effect path always pick the
  same voice.

### 2.4 Shape of the synthesizer

`PlantSynthesizerClient` doesn't change, so the chat view model and its spies don't either.
Three pieces sit behind it:

```
PlantChatViewModel ──► PlantSynthesizerClient
                         └─ FallbackPlantSynthesizerClient          (PlantChat/API, unit-tested)
                              ├─ primary:  PlantEffectSynthesizerClient
                              │              └─ AVAudioEnginePlantSynthesizerClient   (Client, new)
                              └─ fallback: PlantSynthesizerClient
                                             └─ AVSpeechPlantSynthesizerClient        (Client, existing)
```

```swift
@MainActor public protocol PlantEffectSynthesizerClient {
    /// Sends `.started` once audio is playing, then exactly one `.finished` or `.failed`.
    /// Nothing is sent after `stop()`.
    func speak(_ text: String, style: PlantSpeechStyle, update: @escaping (PlantEffectSpeechEvent) -> Void)
    /// Stops at once, synchronously.
    func stop()
}

public enum PlantEffectSpeechEvent: Equatable, Sendable {
    case started
    case finished
    case failed
}
```

Why a composite instead of a fallback hidden inside the engine client:

- The contract rules (completion exactly once, `stop()` immediate, stale events ignored,
  when to fall back) are where the bugs would be. In the composite they are plain logic
  with spies and an injected timer, fully unit-tested.
- The engine client only reports what happened. It never decides what to do next.

**`FallbackPlantSynthesizerClient(primary:fallback:schedule:)`**

- `schedule: (TimeInterval, @escaping @MainActor () -> Void) -> Void` is a one-shot timer,
  the same shape as `TranscriberPlantTranscriptLoader`'s. Default: `Task.sleep` on the main
  actor. Tests fire it themselves.
- `static let startTimeout: TimeInterval = 3`.
- A generation counter, bumped on every `speak` and `stop`, makes old events, timers and
  fallback completions do nothing.

| State | Event | Then |
|---|---|---|
| any | `speak` | `stop()` what's pending (completes it); `primary.speak`; schedule the start timeout |
| primary | `.started` | remember it started |
| primary | `.finished` | complete |
| primary | `.failed`, not started | `fallback.speak` (same text and style) |
| primary | `.failed`, started | complete; the reply is not replayed (open question 7) |
| primary | start timeout, not started | `primary.stop()`, `fallback.speak` |
| fallback | completion | complete |
| any | `stop()` | bump the generation, stop the active path, complete synchronously |

- "Complete" calls the caller's completion once and clears it.
- Each fallback is logged (`Logger`, category `voice`), so the lab and the Xcode console
  show when the effect path failed.

### 2.5 The engine client

`AVAudioEnginePlantSynthesizerClient` (`@MainActor`, PlantChat/Client).

**Graph** (built lazily on the first `speak`, rebuilt after a configuration change or a
media services reset):

```
AVAudioPlayerNode ──(renderFormat)──► AVAudioUnitTimePitch ──► mainMixerNode ──► output
```

- `renderFormat`: Float32, non-interleaved, mono, 48 kHz. The graph never depends on the
  voice's format. The mixer handles mono → stereo and the hardware rate.
- `engine.inputNode` is **never** touched. Reading it would open an input on the engine
  and fight the transcriber's engine for the mic.
- The client never sets the session category or activates it. It plays in the session the
  view model already activated (`playAndRecord`, `spokenAudio`).

**One utterance**

1. `stop()` anything pending; bump the generation.
2. Set `timePitch.pitch = style.pitchCents`, `timePitch.rate = style.effectRate`.
3. `engine.start()`, `player.play()`. A throw → `.failed`.
4. Make an `AVSpeechUtterance` (voice from `AVSpeechVoiceCatalog`, `rate`,
   `pitchMultiplier = 1`) and call `synthesizer.write(utterance, toBufferCallback:)`.
5. Each buffer: convert to `renderFormat`, `scheduleBuffer` with
   `completionCallbackType: .dataPlayedBack`, count it. The first scheduled buffer sends
   `.started`.
6. The end of the stream (a buffer with `frameLength == 0`): flush the converter, then
   schedule 0.25 s of silence so the time-pitch tail is heard and the last syllable isn't
   clipped (open question 10).
7. When the end was seen and every scheduled buffer was played back → `player.stop()`,
   `engine.stop()`, `.finished`.
8. The end arrives with no audio scheduled → `.failed` (the composite falls back).

`engine.stop()` after each utterance gives the hardware back cleanly, so tapping the mic
right after Sprout speaks starts the transcriber's engine without a clash. The graph stays
attached, so the next `start()` is cheap.

**Buffer conversion**

- The synthesizer's buffers are usually Int16 or Float32, mono, 22.05 kHz or 24 kHz,
  depending on the voice. Not every buffer is guaranteed to have the same format.
- One `AVAudioConverter` per utterance, made from the first buffer's format, and made
  again if a later buffer's format differs.
- Use `convert(to:error:withInputFrom:)`. The simpler `convert(to:from:)` can't change the
  sample rate.
- Output capacity: `ceil(frames × 48000 / inputRate) + 1024`. The input block hands over
  the buffer once and then returns `.noDataNow`. At the end it returns `.endOfStream` to
  flush the resampler's last frames.
- A non-PCM buffer is ignored. A conversion error before anything was scheduled →
  `.failed`; after → stop and `.failed`, and the composite completes without a replay.

**Swift 6 rules** (ARCHITECTURE.md section 3, the M5b crash):

- The `write` callback and the `scheduleBuffer` completion run on audio threads. Both
  closures are created in `nonisolated static` functions, so they are never inferred
  `@MainActor`.
- The `write` callback only copies the buffer into a new `AVAudioPCMBuffer` (the
  synthesizer may reuse its own) and posts it with
  `DispatchQueue.main.async { MainActor.assumeIsolated { … } }`. The main queue keeps the
  order, which a `Task` hop wouldn't. The copy travels in a small
  `struct TransferredBuffer: @unchecked Sendable`; the audio thread never touches it again.
- The playback completion posts only `(generation, index)` the same way.
- The converter, counters, generation and nodes are touched only on the main actor.
- Notification observers use `queue: .main` and `MainActor.assumeIsolated`, like
  `AVAudioSessionPlantAudioSessionClient`. Values are read out of the `Notification` first.
- Observers are removed in `isolated deinit`.

**`stop()`**: bump the generation, `synthesizer.stopSpeaking(at: .immediate)`,
`player.stop()`, `engine.stop()`, cancel the wobble. Nothing is sent. The player calls the
pending playback completions when it stops; the old generation drops them.

**Wobble** (S5): while `wobbleCents > 0`, a main-actor `Task` loop sets
`timePitch.pitch = pitchCents + wobbleCents × sin(2π × 5 Hz × t)` every 30 ms. It's
cancelled at the end of the utterance and in `stop()`. Parameter changes from the main
thread are safe on an audio unit. If the steps are audible, the wobble is dropped and
drowning is just slower (open question 5).

### 2.6 Audio session, interruptions and route changes

The session stays owned by the view model (M5b 1.6). The new client only has to survive
what happens to it.

| What happens | Who reacts | Result |
|---|---|---|
| Interruption begins (call, Siri, alarm) | View model calls `stop()` (M5b). The engine client also observes `interruptionNotification` and sends `.failed` | Speech stops. Whichever comes first wins; the other is dropped by a generation |
| Interruption ends | nobody | Nothing resumes (as in M5b) |
| Old output device lost (AirPods out) | View model calls `stop()` (M5b) | Speech stops, doesn't jump to the speaker |
| New output device, or any other route change mid-reply | `AVAudioEngineConfigurationChange` stops the engine. The client sends `.failed` and marks the graph for a rebuild | The reply is cut off and the turn ends (open question 4). The next reply rebuilds and plays on the new route |
| Media services reset (iOS) | The client drops the engine, nodes and synthesizer and makes new ones on the next `speak`. A pending utterance sends `.failed` | Turn ends; the next reply works |
| Mic tap while speaking | View model: `stop()` then listen (M5b) | `stop()` is synchronous and stops the engine before the transcriber starts |

Without the last three rows, a stopped engine would never call the playback completions and
Sprout would stay "speaking" forever. The composite's start timeout covers the case where
the engine never starts producing audio at all.

### 2.7 Fallback

- **Before any audio** (engine start fails, no buffers, conversion fails, 3 s without
  audio): the composite speaks the same text with `AVSpeechPlantSynthesizerClient`.
- **After audio started:** the turn just ends. Replaying from the start would repeat
  words.
- The plain path uses the same voice choice and `rate`, with `pitchMultiplier = 1`. It
  doesn't have the character effect.
- `AVSpeechPlantSynthesizerClient` keeps `usesApplicationAudioSession = true` and its
  existing delegate code.

### 2.8 DEBUG voice lab

**Entry:** a "Voice lab" button at the bottom of the sliders menu, under "Speak replies",
only in DEBUG builds. It sends `PlantChatAction.voiceLabTap` (a `#if DEBUG` case). The app
pushes `AppNavigation.Route.voiceLab`. Being a push matters: the chat's `onDisappear` runs,
so its speech stops and its session deactivates first.

**Screen** (one `Form`):

- Personality picker: every `PlantPersonality`, including the hidden ones.
- Mood picker: every `PlantMood`, plus "none".
- Sliders for the **base** values: pitch cents (−1200…1200, step 25), effect rate
  (0.5…1.5, step 0.01), utterance rate (0.3…0.7, step 0.01), each with its value.
- A line with the effective values after the mood adjustment.
- A text field. Empty uses a sample line ("Hi! I'm Sprout. A little water would be lovely
  today.").
- Play / Stop.
- "Voice: Zoe (Premium) · com.apple.voice.premium.en-US.Zoe", from the same picker the
  clients use, or "System default (en-AU)" when the picker finds nothing.
- "Print values".

**Behavior**

- Choosing a personality resets the sliders to its row in the table.
- Play: activate the session (false → a "can't play right now" line), then
  `synthesizer.speak(text, style: base.adjusted(for: mood))`. The completion deactivates
  and shows Play again. Play while playing stops first. A stale completion is ignored.
- An interruption or a lost output stops playback, like the chat.
- Leaving the screen stops and deactivates.
- "Print values" logs one line ready to paste into `PlantPersonality.speechStyle`, with the
  voice used as a comment:

  ```swift
  case .cheerful: PlantSpeechStyle(language: "en-US", rate: 0.50, pitchCents: 525, effectRate: 1.02) // voice: Zoe (Premium), com.apple.voice.premium.en-US.Zoe
  ```

- The lab gets its **own** `FallbackPlantSynthesizerClient` and its own
  `AVAudioSessionPlantAudioSessionClient`. The session client keeps a single subscriber, so
  sharing the chat's would steal its events.
- The labels are plain English literals in the view model, not in `PlantChat.strings`,
  because this screen never ships.

**Types**

- `PlantVoiceLabViewModel` (PlantChat/Presentation, `#if DEBUG`): `init(synthesizer:
  audioSession: installedVoices: () -> [PlantSynthesisVoice], initialPersonality: log:
  (String) -> Void)`. Inputs: `appear`, `select(_ personality)`, `select(_ mood)`,
  `setPitchCents`, `setEffectRate`, `setRate`, `setText`, `playTap`, `printTap`,
  `disappear`. Observers: `loadedValues`, `loadedVoice`, `loadedIsPlaying`, `loadedNotice`.
- `PlantSpeechStyleSnippet.line(personality:style:voice:) -> String` (pure, `#if DEBUG`).
- `PlantVoiceLabUIComposer`, `PlantVoiceLabStore`, `PlantVoiceLabView` (PlantChatiOS,
  `#if DEBUG`).
- The app passes `log: { print($0) }`, so the line can be copied from the Xcode console
  without `Logger` prefixes.

---

## 3. Where things go

| Piece | Target / folder | Step |
|---|---|---|
| `PlantSpeechStyle` fields, base table, `adjusted(for:)` | PlantChat/Domain | S1 |
| `PlantSynthesisVoice`, `PlantVoicePicker` | PlantChat/Domain | S2 |
| `AVSpeechVoiceCatalog` | PlantChat/Client | S2 |
| `PlantEffectSynthesizerClient` (+ event) | PlantChat/Client | S3 |
| `FallbackPlantSynthesizerClient` | PlantChat/API | S3 |
| `AVAudioEnginePlantSynthesizerClient` | PlantChat/Client | S4, S5 |
| Wiring | App target (`AppGraph.swift`) | S4, S7 |
| `PlantVoiceLabViewModel`, `PlantSpeechStyleSnippet` | PlantChat/Presentation (DEBUG) | S6 |
| `PlantChatAction.voiceLabTap` | PlantChat/Domain (DEBUG case) | S7 |
| Lab view, store, composer; menu entry | PlantChatiOS (DEBUG) | S7 |
| Route `.voiceLab` | App target (DEBUG) | S7 |

---

## 4. Test doubles

Added to `PlantChatXCTestCase` (and `PlantChatiOSXCTestCase` where the lab's integration
tests need them):

- `EffectSynthesizerSpy`: records `speak(text, style)` and `stop`; sends events by index.
- `ScheduleSpy`: already there from M5b; reused for the start timeout.
- `SynthesizerSpy`: unchanged, used as the composite's fallback and by the lab.
- `AudioSessionSpy`: unchanged.
- `makeVoice(identifier:name:language:quality:)` factory.

---

## 5. Docs (S8)

- **ROADMAP.md:** an M5c section linking this plan.
- **M5b-voice.md 3.3:** a one-line note that the style table moved to M5c.
- **ARCHITECTURE.md section 3, rule 2:** add audio-thread callbacks (`write`,
  `scheduleBuffer`, taps) to the examples: created in `nonisolated static` functions, hop
  with `DispatchQueue.main.async` + `assumeIsolated`.

---

## 6. How to listen on the device

- Premium and enhanced voices are downloaded by the user in Settings › Accessibility ›
  Spoken Content › Voices › English. The app can't download them.
- For the checks, install at least one premium en-US voice and one enhanced en-GB or en-AU
  voice, and keep one language with only the compact voice to see the fallback rule.

---

## 7. Steps

Each step leaves `swift test --filter PlantChatTests` green and the app building. No
commits. The human runs PlantChatiOSTests and the device checks.

### S1. Style: cents, effect rate, mood

- **Files:**
  - `PlantChat/Domain/PlantSpeechStyle.swift`: new fields, `pitch` removed, base table from
    2.2, `adjusted(for:)` and the clamps.
  - `PlantChat/Client/AVSpeechPlantSynthesizerClient.swift`: `pitchMultiplier = 1` (one
    line, until S4 brings the effect).
  - `PlantChat/Presentation/PlantChatViewModel.swift`: `speak` uses
    `settings.load().speechStyle.adjusted(for: latestFacts?.mood)`.
  - `Tests/PlantChatTests/PlantSpeechStyleTests.swift`, `PlantChatViewModelTests.swift`.
- **Tests:**
  - `test_speechStyle_matchesTablePerPersonality` (new values).
  - `test_adjusted_withNilMood_isUnchanged`, and the same for tooDark, dryAir, offline.
  - `test_adjusted_happy_raisesPitchAndSpeed`.
  - `test_adjusted_lowMoods_lowerPitchAndSpeed` (thirsty, veryThirsty, tooHot, tooCold).
  - `test_adjusted_drowning_wobblesAndSlows`.
  - `test_adjusted_clampsOutOfRangeValues`.
  - View model: a voice turn's reply while thirsty is spoken with
    `politeButler.speechStyle.adjusted(for: .thirsty)`.
- **On device:** replies sound like the natural voice (no pitch yet). Expected until S4.

### S2. Voice choice

- **Files:**
  - `PlantChat/Domain/PlantSynthesisVoice.swift`, `PlantChat/Domain/PlantVoicePicker.swift`.
  - `PlantChat/Client/AVSpeechVoiceCatalog.swift`.
  - `AVSpeechPlantSynthesizerClient.swift`: the voice comes from `AVSpeechVoiceCatalog`.
  - `Tests/PlantChatTests/PlantVoicePickerTests.swift`, the factory in the base class.
- **Tests (`PlantVoicePickerTests`):**
  - the preferred voice wins when installed, even if a better quality exists;
  - a preferred identifier that isn't installed is ignored;
  - premium beats enhanced beats standard for the same language;
  - other languages are never picked over the style's language;
  - equal quality → first by name;
  - no voice in the language → best en-US;
  - nothing suitable → nil.
- **On device:** with a premium en-US voice installed, cheerful uses it (clearly less
  robotic). Deleting it falls back to enhanced, then compact, with no crash.

### S3. Fallback composite

- **Files:**
  - `PlantChat/Client/PlantEffectSynthesizerClient.swift` (protocol + event).
  - `PlantChat/API/FallbackPlantSynthesizerClient.swift`.
  - `EffectSynthesizerSpy` in `PlantChatXCTestCase`.
  - `Tests/PlantChatTests/FallbackPlantSynthesizerClientTests.swift`.
- Not wired yet.
- **Tests:**
  - init sends nothing to either client;
  - speak forwards text and style to the primary and schedules the start timeout;
  - `.started` then `.finished` completes once; the fallback is never used;
  - `.failed` before `.started` speaks the same text and style with the fallback; its
    completion completes once;
  - `.failed` after `.started` completes once without the fallback;
  - the start timeout without `.started` stops the primary and uses the fallback; after
    `.started` it does nothing;
  - stop during the primary stops the primary and completes synchronously, once; later
    primary events do nothing;
  - stop during the fallback stops the fallback and completes once, even though the
    fallback also calls its completion;
  - speak while speaking completes the first once, then starts the second; events of the
    first are ignored;
  - stop when idle completes nothing;
  - `test_speak_doesNotCreateMemoryLeaks`.
- **On device:** nothing.

### S4. Engine client and wiring

- **Files:**
  - `PlantChat/Client/AVAudioEnginePlantSynthesizerClient.swift` (2.5, 2.6; no wobble yet).
  - `TalkingPlant/AppGraph.swift`: `synthesizer:` becomes
    `FallbackPlantSynthesizerClient(primary: AVAudioEnginePlantSynthesizerClient(), fallback:
    AVSpeechPlantSynthesizerClient())`.
- **Tests:** none; it wraps system APIs. `swift test` still compiles it on macOS
  (interruption and media reset observers inside `#if os(iOS)`).
- **On device:**
  - each personality sounds like a character, not a damaged voice; cheerful is clearly
    higher, chill surfer slower;
  - the last syllable isn't clipped; loudness is close to before (open question 11);
  - a 3–4 sentence reply plays to the end and the mic is enabled again right after;
  - tapping the mic mid-reply cuts it at once and the transcript doesn't contain Sprout's
    words;
  - a phone call or Siri mid-reply stops it, and the next voice turn works;
  - pulling out AirPods stops it; connecting AirPods mid-reply ends it, and the next reply
    plays in the AirPods;
  - music in another app stops while talking and resumes after the reply (no change from
    M5b);
  - a thirsty plant sounds a bit lower and slower than a happy one;
  - fallback check: temporarily make `engine.start()` throw in a DEBUG build (or set the
    time-pitch to an invalid format) and confirm the plain voice still speaks; the console
    shows the fallback log. Revert after.

### S5. Wobble for drowning

- **Files:** `AVAudioEnginePlantSynthesizerClient.swift` only.
- **Tests:** none (the value is already covered in S1).
- **On device:** a drowning plant wobbles without clicks or zipper noise; stop and the
  mic tap cut it at once; other moods don't wobble.

### S6. Voice lab: view model

- **Files:**
  - `PlantChat/Presentation/PlantVoiceLabViewModel.swift` (`#if DEBUG`).
  - `PlantChat/Presentation/PlantSpeechStyleSnippet.swift` (`#if DEBUG`).
  - `Tests/PlantChatTests/PlantVoiceLabViewModelTests.swift`,
    `PlantSpeechStyleSnippetTests.swift` (`#if DEBUG`).
- **Tests:**
  - appear emits the initial personality's base values and its voice;
  - selecting a personality resets the values and the voice;
  - each slider emits new base and effective values; selecting a mood changes only the
    effective values;
  - play activates, then speaks the text with `base.adjusted(for: mood)`; finish
    deactivates and emits not playing;
  - play with an empty text speaks the sample line;
  - activation failure → notice, nothing spoken;
  - play while playing stops first; the stale completion doesn't deactivate the new one;
  - an interruption or a lost output while playing stops and deactivates;
  - disappear stops and deactivates; disappear when idle does nothing;
  - print logs `PlantSpeechStyleSnippet.line(...)` for the current values;
  - snippet: exact string, two decimals for rates, whole cents, the voice comment, and
    `preferredVoiceIdentifier:` only when the base has one;
  - `test_playTap_doesNotCreateMemoryLeaks`.
- **On device:** nothing.

### S7. Voice lab: screen and entry

- **Files:**
  - `PlantChat/Domain/PlantChatAction.swift`: `#if DEBUG case voiceLabTap`.
  - `PlantChatiOS/Views/PlantVoiceLabView.swift`, `Stores/PlantVoiceLabStore.swift`,
    `Composers/PlantVoiceLabUIComposer.swift` (all `#if DEBUG`).
  - `PlantChatPersonalityMenuView.swift`: an optional `voiceLab` button after the toggle.
  - `PlantChatUIComposer.swift`: sets it in DEBUG only.
  - `TalkingPlant/TalkingPlantApp.swift`: `Route.voiceLab`, `.voiceLabTap` handling.
  - `TalkingPlant/AppGraph.swift`: `makeVoiceLab()` with its own synthesizer and session
    client, like `makeCalibration()`.
  - `PlantChatiOSXCTestCase.swift`, `PlantChatView+ViewInspector.swift`.
- **Integration tests (`PlantVoiceLabUIITests`, `#if DEBUG`; one in `PlantChatUIITests`):**
  - the chat menu shows "Voice lab", and tapping it sends `.voiceLabTap`;
  - the lab shows the pickers, three sliders with their values, the voice line and the
    buttons;
  - moving a slider updates its value and the effective line;
  - Play speaks with the slider style; the button reads Stop until the spy finishes;
  - Print calls `log` with the snippet.
- **On device:** the lab opens from the menu; leaving the chat stops its speech; sliders
  change the sound right away on the next Play; the voice line names the voice heard;
  Print puts a pasteable line in the Xcode console; a Release build has no menu entry.

### S8. Tune and document

- The human tunes each shown personality (and checks the moods) in the lab and pastes the
  printed lines.
- **Files:** `PlantSpeechStyle.swift` table and `PlantSpeechStyleTests` with the tuned
  values; docs from section 5.
- **On device:** a final listen of every shown personality, happy and thirsty.

---

## 8. Answered questions

These replace the open questions. Each says what was decided.

1. **Fallback pitch.** Stays natural: the plain path speaks at `pitchMultiplier = 1`.
2. **Voice picker in the lab.** Yes. The lab gets a picker over the installed voices for the
   personality's language; the choice feeds `preferredVoiceIdentifier` and the printed line
   (added in S6/S7).
3. **Tuning moods in the lab.** The table is good enough. Mood offsets stay in code, no
   extra sliders.
4. **New route mid-reply.** AirPods connecting mid-reply may cut the reply off for now. No
   restart or resume.
5. **Wobble.** Try it in S5. If it is choppy on the device, drop it; drowning is then just
   slower.
6. **Start timeout.** 3 s. Tune after S4 if a premium voice needs longer.
7. **Mid-reply failure.** The turn ends instead of replaying. Not planned further.
8. **AirPods quality.** Out of scope. No `.allowBluetoothA2DP`; it belongs in its own change.
9. **Premium voices with `write`.** Assumed to work on iOS 26. Confirm in S4; the composite
   falls back if a voice produces no buffers.
10. **Tail silence.** Keep 0.25 s. Check in S4 that it doesn't delay the mic noticeably.
11. **Loudness.** If the buffer path is quieter, raise `mainMixerNode.outputVolume` or the
    player's volume in S4, not the session.
12. **Hidden personalities.** dramatic and grumpyGrandma keep untuned values until they are
    shown again.
