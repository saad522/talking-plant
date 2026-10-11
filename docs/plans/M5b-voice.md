# M5b plan: voice for Sprout

Scope:

- Speech in: the user talks to Sprout through the mic, transcribed on device.
- Speech out: Sprout's replies are spoken, with a voice per personality.
- The four activity states the Rive file will need.
- Audio session handling, permissions, and a setting to mute spoken replies.
- Step 0: the notifier's severity ranking is injected.

Out of scope: spoken notifications, the Rive file and its binding, talking over Sprout
without tapping (barge-in), lip sync, languages other than English, and streamed replies.

Implementation is split into steps S0–S7, one session each (section 9).

---

## 1. Decisions

### 1.1 Slice: part of PlantChat, not a new PlantVoice slice

Voice goes into `PlantChat` / `PlantChatiOS`. Reasons:

- **One pipeline.** A spoken turn is a chat turn: same session, personality, facts,
  fallback and bubbles. In a separate slice, the transcript would have to leave PlantVoice
  as an action, the app would call the chat, and the reply would come back through the app
  to be spoken. That is a second path, glued together in the composition root with no unit
  tests.
- **One state machine.** "Thinking" is the chat's pending reply. Listening, thinking and
  speaking are one sequence and belong in one tested view model, not split across two
  features and the app.
- **One screen.** DESIGN.md section 6 puts the voice controls in place of the Talk
  screen's text field. Nothing else uses voice yet.
- **Shared code is promoted, not planned.** If spoken notifications or a speaking home
  bubble come later, the clients move to PlantShared then.
- **Names.** PlantChat already uses `PlantVoice…` for the language-model voice
  (`PlantVoiceFacts`, `PlantVoicePrompt`, `PlantVoiceLineLoader`). A `PlantVoice` slice
  would mix up two meanings.

The import rule from M5 still holds. `Speech` and `AVFoundation` are imported only inside
`PlantChat/Client/`, like FoundationModels and UserNotifications.

### 1.2 Speech in: SpeechAnalyzer, no SFSpeechRecognizer fallback

- `SpeechAnalyzer` with a `SpeechTranscriber` module and volatile (partial) results. It
  runs fully on device.
- **Fallback:** when `SpeechTranscriber.isAvailable` is false, or it doesn't support the
  locale, the same client uses `DictationTranscriber` in the same `SpeechAnalyzer`.
  `DictationTranscriber` uses the on-device dictation models.
- **SFSpeechRecognizer isn't needed for recognition.** The deployment target is iOS 26, so
  SpeechAnalyzer is always there. SFSpeechRecognizer would only add server recognition,
  which sends audio off the device.
- `SFSpeechRecognizer.requestAuthorization` may still be needed for the permission prompt
  (open question 1).
- When neither transcriber supports the locale, the authorization is `.unsupported` and
  the Talk screen is keyboard only.
- **Locale:** the device's English variant when the device language is English, otherwise
  `en-US`. The app and the prompts are English only.
- **Model assets:** `prepare()` runs when the Talk screen first appears. It checks
  `AssetInventory` and starts `assetInstallationRequest(supporting:)` if needed. A mic tap
  while the assets are still installing shows the "getting ready" notice.

### 1.3 Tap to start, auto-stop (not push-to-talk)

- **Tap the mic** to start listening.
- **It stops by itself** after 1.5 s without new words. Each new word restarts the timer.
- **Tap again** to stop early and send what was heard. This covers noisy rooms where
  silence never comes.
- **Nothing heard** in the first 6 s → back to idle, nothing is sent.
- **Hard cap of 30 s**, then it stops and sends.

Why not push-to-talk:

- **Hands.** People talk to the plant with a watering can or a phone in one hand. Holding a
  button while talking is awkward.
- **Accessibility.** Holding is hard with VoiceOver, Switch Control, and for people with
  motor impairments. A tap is a normal button.
- **Design.** The 84 pt mic between a keyboard button and an end button (DESIGN.md 6) is a
  tap control, like a call screen.
- **Turns are short.** Questions to a plant are one sentence, which is where silence
  detection works well.
- **Testable.** The stop rules live in a loader with an injected scheduler and are fully
  unit-tested. No timing lives in the platform client.

The downside: a slow speaker can get cut off. 1.5 s is a starting value to tune on the
device (open question 7).

### 1.4 Speech out: AVSpeechSynthesizer, voice-in → voice-out

- `AVSpeechSynthesizer` speaks the reply with a `PlantSpeechStyle` per personality
  (section 3.3).
- **Which replies are spoken:** only replies to turns that started at the mic.
  - Typed turns are never spoken.
  - The greeting isn't spoken, so opening Talk never makes a sound (open question 2).
  - Siri works the same way: it answers out loud when you speak and quietly when you type.
- **The template fallback reply is spoken too.** Transcription doesn't need Apple
  Intelligence, so talking works on every iOS 26 iPhone, with template answers when the
  model is unavailable.
- **Before speaking,** the text is cleaned (section 3.4). The model sometimes writes
  `*sighs*`, and the synthesizer would read the asterisks out loud.
- **Mute:** "Speak replies" (on by default) is saved and switches spoken replies off.
  Turning it off while Sprout is talking stops the speech.

### 1.5 Activity states for Rive

`PlantChatActivity`: `idle`, `listening`, `thinking`, `speaking`.

- **`thinking`:** whenever a reply is pending, typed or spoken. It replaces nothing:
  `loadedTyping` stays for the "…" bubble.
- **`speaking`:** only while the synthesizer is talking.
- The view model emits `loadedActivity`, and the store keeps `@Published var activity`.
- For now, only the mic button uses it (its icon and whether it's enabled). The Rive
  milestone binds the state machine input to it. For example, the face factory could then
  take `(PlantMood, PlantChatActivity)`. That change isn't part of this plan.

### 1.6 Audio session

- **Category:** `.playAndRecord`, mode `.spokenAudio`.
- **Options:**
  - `.defaultToSpeaker`: without it, playAndRecord plays through the earpiece.
  - `.allowBluetoothHFP`: AirPods can be the mic.
- **Not mixable,** so music stops while you talk to Sprout, like Siri. Ducking would let
  the music leak into the mic.
- **Active only while needed.** The view model activates the session when it leaves idle
  for listening. It keeps it active through thinking and speaking, so there's no glitch
  between turns. It deactivates with `.notifyOthersOnDeactivation` when it's back to idle,
  so the user's music resumes. Typed turns never touch the session.
- **The view model owns activation.** Only it knows that listen → think → speak is one
  span, and this keeps the logic unit-tested. The client only wraps `AVAudioSession`.
- **Activation fails** (for example during a phone call) → stays idle and shows the
  "didn't catch that" notice.
- **Interruption begins** (a call, Siri, an alarm):
  - while listening: cancel, send nothing, idle;
  - while speaking: stop, idle;
  - while thinking: the reply still appears but isn't spoken.
- **Interruption ends:** nothing resumes on its own. Resuming the mic unasked would be
  creepy, and the replies are short.
- **Route change, old device unavailable** (headphones unplugged, AirPods out):
  - while speaking: stop speech, so it doesn't jump to the loudspeaker;
  - while listening: cancel, because the input changed under the audio engine.
- **Stopping speech when the user starts talking:**
  - tapping the mic while speaking stops the synthesizer and starts listening right away,
    with the session still active;
  - Sprout never listens while it speaks, since there is no echo cancellation and the mic
    would hear Sprout.
- **Silent switch:** playAndRecord ignores it. Spoken replies play in silent mode, but
  only after the user just spoke out loud to Sprout. The mute setting is the way to keep
  the voice quiet. Typed turns are always silent.
- **Leaving the screen** (back, end, or the app leaving `.active`): cancel listening,
  stop speaking, deactivate.

### 1.7 Permissions

Info.plist (`ios/TalkingPlant/TalkingPlant/Info.plist`, raw keys):

| Key | Text |
|---|---|
| `NSMicrophoneUsageDescription` | "Sprout listens only while you tap the mic, so you can talk to it out loud." |
| `NSSpeechRecognitionUsageDescription` | "What you say to Sprout is turned into text on this iPhone and never leaves it." |

**`PlantSpeechAuthorization`:** `notDetermined`, `authorized`, `denied`, `restricted`,
`unsupported`.

- The client combines the microphone (`AVAudioApplication.recordPermission`) and speech
  recognition.
- Either one denied → `denied`. Either one restricted → `restricted`.

**Flow**

- Nothing is asked when the screen opens. The first mic tap asks for the microphone, then
  for speech recognition.
- The status is read again on every `appear()` and every mic tap, so a change made in
  Settings is picked up.

**Copy per state** (in `PlantChat.strings`, `%@` = plant name):

| State | Notice | Button | Mode |
|---|---|---|---|
| `denied` | "%@ can't hear you. Allow the microphone and speech recognition in Settings." | "Open Settings" → `PlantChatAction.openSettings` | keyboard |
| `restricted` | "The microphone isn't allowed on this iPhone. You can still type to %@." | none | keyboard |
| `unsupported` | "Talking out loud isn't available on this iPhone. You can still type to %@." | none | keyboard |
| assets installing | "%@ is still getting ready to listen. Try again in a moment." | none | voice |
| failure | "%@ didn't catch that. Tap the mic to try again." | none | voice |

- The notice is a `card` row in the same place as the "unavailable" notice. It clears on
  the next mic tap.
- The app handles `.openSettings` by opening `UIApplication.openSettingsURLString`.

---

## 2. Where things go

| Piece | Target / folder | Step |
|---|---|---|
| `PlantMoodNotifier` severity ranking | PlantChat/API + app | S0 |
| `PlantChatActivity`, `PlantChatInputMode`, `PlantSpeechAuthorization`, `PlantTranscript`, `PlantSpeechStyle` (+ `PlantPersonality.speechStyle`), `PlantSpeechText` | PlantChat/Domain | S1 |
| `DefaultsClient` Bool values | PlantShared/Client | S1 |
| `PlantSpokenReplySettings` | PlantChat/Persistence | S1 |
| `PlantTranscriberClient`, `PlantSynthesizerClient`, `PlantAudioSessionClient` (protocols + events) | PlantChat/Client | S2 |
| `PlantTranscriptLoader` (protocol) | PlantChat/Domain | S2 |
| `TranscriberPlantTranscriptLoader` | PlantChat/API | S2 |
| `SpeechAnalyzerPlantTranscriberClient`, `AVSpeechPlantSynthesizerClient`, `AVAudioSessionPlantAudioSessionClient` | PlantChat/Client | S3 |
| Voice in `PlantChatViewModel`, `PlantChatMicrophoneNoticeViewModel`, strings | PlantChat/Presentation | S4, S6 |
| Voice controls, live transcript bubble, keyboard mode, "Speak replies" toggle | PlantChatiOS | S5, S6 |
| Info.plist keys, wiring, `.openSettings`, DEBUG launch argument | App target | S3–S6 |

---

## 3. Business layer

### 3.1 Client protocols (PlantChat/Client)

```swift
@MainActor public protocol PlantTranscriberClient {
    var authorization: PlantSpeechAuthorization { get }
    func requestAuthorization(completion: @escaping (PlantSpeechAuthorization) -> Void)
    /// Installs the speech model if needed, ahead of the first tap.
    func prepare()
    func start(update: @escaping (PlantTranscriberEvent) -> Void)
    /// Stops the microphone, finalizes what was heard, then sends `.finished`.
    func finish()
    /// Stops at once. Nothing more is delivered.
    func cancel()
}

public enum PlantTranscriberEvent: Equatable, Sendable {
    case volatile(String)   // replaces the previous volatile text
    case final(String)      // a finished segment, appended to the earlier ones
    case finished
    case failed(PlantTranscriberError)
}

public enum PlantTranscriberError: Error, Equatable, Sendable {
    case preparing          // the model assets are still installing
    case transcription
}

@MainActor public protocol PlantSynthesizerClient {
    /// Calls `completion` once, when the speech ends for any reason (finished or stopped).
    func speak(_ text: String, style: PlantSpeechStyle, completion: @escaping () -> Void)
    func stop()
}

@MainActor public protocol PlantAudioSessionClient {
    /// Sets the category and activates. False when the system refuses, e.g. during a call.
    func activate() -> Bool
    /// Deactivates and lets other apps' audio resume.
    func deactivate()
    func subscribe(update: @escaping (PlantAudioSessionEvent) -> Void)
}

public enum PlantAudioSessionEvent: Equatable, Sendable {
    case interruptionBegan
    case interruptionEnded
    case outputDeviceLost
}
```

### 3.2 Transcript loader

```swift
@MainActor public protocol PlantTranscriptLoader {
    typealias Result = Swift.Result<PlantTranscript, Error>
    var authorization: PlantSpeechAuthorization { get }
    func requestAuthorization(completion: @escaping (PlantSpeechAuthorization) -> Void)
    func prepare()
    /// Partial transcripts, then exactly one final transcript (empty when nothing was heard).
    func start(update: @escaping (Result) -> Void)
    /// Stops listening. The final transcript follows.
    func stop()
    /// Stops listening. Nothing more is delivered.
    func cancel()
}

public struct PlantTranscript: Equatable, Sendable {
    public let text: String
    public let isFinal: Bool
}
```

**`TranscriberPlantTranscriptLoader(client:schedule:)`** holds all the stop rules.

- `schedule: (TimeInterval, @escaping @MainActor () -> Void) -> Void` is a one-shot timer.
  The default is a `Task.sleep` on the main actor. Tests fire it themselves.
- A generation counter makes old timers do nothing, so no cancellable type is needed.
- The timeouts are static constants: `silenceTimeout = 1.5`, `noSpeechTimeout = 6`,
  `maximumDuration = 30`.

**Behavior**

- **Text:** the committed text (all final segments) plus the current volatile text,
  trimmed. Each change is delivered as a partial transcript.
- **Timers:**
  - Each new text restarts the silence timer. When it fires, the loader calls
    `client.finish()`.
  - No text within `noSpeechTimeout` → `client.cancel()` and an empty final transcript.
  - At `maximumDuration` → `client.finish()`.
- **`.finished`:** delivers the final transcript (the committed text plus any volatile
  text left) and stops all timers.
- **Errors:** `.failed(.preparing)` → `Error.preparing`; `.failed(.transcription)` →
  `Error.transcription`.
- **`stop()`** → `client.finish()`. **`cancel()`** → `client.cancel()`, and nothing more
  is delivered, even if the client still sends events.
- The client is never captured strongly in timer closures, and `self` is weak. This is
  checked by the memory leak test.

### 3.3 Speech style per personality (Domain)

`PlantSpeechStyle(language: String, rate: Float, pitch: Float)`. The rate uses
`AVSpeechUtterance`'s 0–1 scale (0.5 is normal speed), and the pitch is a multiplier
(0.5–2). These are starting values to tune on the device:

| Personality | Language | Rate | Pitch |
|---|---|---|---|
| cheerful | en-US | 0.52 | 1.15 |
| dramatic | en-US | 0.46 | 1.25 |
| grumpyGrandma | en-IE | 0.42 | 0.90 |
| chillSurfer | en-AU | 0.44 | 0.95 |
| politeButler | en-GB | 0.48 | 0.90 |

The client uses `AVSpeechSynthesisVoice(language:)` and falls back to `en-US` when that
voice isn't installed.

### 3.4 Spoken text

`PlantSpeechText.clean(_:)`:

- Removes `*`, `_` and `#`, and emoji.
- Collapses whitespace.
- An empty result means nothing is spoken.

### 3.5 Settings

- `DefaultsClient` gains `set(_: Bool, forKey:)` and `retrieveBool(forKey:) -> Bool?`.
- `UserDefaultsClient` is updated, along with the three `DefaultsSpy`s: in
  `PlantSharedXCTestCase`, `PlantChatXCTestCase` and `PlantChatiOSXCTestCase`.
- `PlantSpokenReplySettings(defaults:)`:
  - `isEnabled` is `true` when nothing is saved.
  - `save(isEnabled:)` stores under `plant.chat.spokenReplies.enabled`.

### 3.6 Chat view model

New init parameters:

- S4: `transcriptLoader: PlantTranscriptLoader`, `audioSession: PlantAudioSessionClient`.
- S6: `synthesizer: PlantSynthesizerClient`, `spokenReplies: PlantSpokenReplySettings`.

**One path.** `send(_:)` becomes `submit(_ text:, speaksReply: Bool)`, used by both inputs:

- a typed send calls `submit(text, speaksReply: false)`;
- a final transcript calls `submit(text, speaksReply: spokenReplies.isEnabled)`.

Everything after that is the existing code: trimming, the pending guard, the user bubble,
`chatLoader.send(_:facts:)`, the template fallback, and dropping replies from an old
conversation.

**New inputs**

- `micTap()`
- `keyboardTap()`
- `voiceTap()`
- `endTap()`
- `setSpokenReplies(_ isEnabled: Bool)`
- `disappear()`: called from `onDisappear` and when the scene leaves `.active`.

**New observers**

- `loadedActivity(PlantChatActivity)`
- `loadedTranscript(String)`: the live text; empty when not listening.
- `loadedInputMode(PlantChatInputMode)`: `.voice` or `.keyboard`.
- `loadedMicrophoneNotice(PlantChatMicrophoneNoticeViewModel?)`
- `loadedSpokenReplies(Bool)`

**`PlantChatMicrophoneNoticeViewModel`** takes an authorization or a failure kind. It
exposes `text: String` and `settingsLabel: String?` (only for denied), like
`PlantMonitorErrorViewModel`.

**State machine**

| From | Event | Then |
|---|---|---|
| any | first `appear()` | read the authorization; denied, restricted or unsupported → keyboard mode + notice; `prepare()`; subscribe to audio session events |
| idle | `micTap`, not determined | request; authorized → start listening; otherwise notice + keyboard mode |
| idle | `micTap`, authorized | `activate()`; false → failure notice; true → `start`, **listening** |
| listening | partial | `loadedTranscript(text)` |
| listening | `micTap` | `transcriptLoader.stop()` |
| listening | final, not empty | clear the transcript, `submit(text, speaksReply:)`, **thinking** |
| listening | final, empty | clear, `deactivate()`, **idle** |
| listening | failure | clear, `deactivate()`, notice (preparing or failure), **idle** |
| listening | interruption or output lost | `cancel()`, clear, `deactivate()`, **idle** |
| thinking | `micTap` | ignored (like sends while a reply is pending) |
| thinking | interruption | remember not to speak; `deactivate()` |
| thinking | reply, spoken | `synthesizer.speak(clean(reply), style)`, **speaking** |
| thinking | reply, not spoken | `deactivate()` if active, **idle** |
| speaking | finished | `deactivate()`, **idle** |
| speaking | `micTap` | `synthesizer.stop()`, `start`, **listening**, no deactivate in between |
| speaking | interruption, output lost, or spoken replies turned off | `stop()`, `deactivate()`, **idle** |
| any | `endTap` | cancel or stop, `deactivate()` if active, **idle**, `actionHandler(.backTap)` |
| any | `disappear` / conversation restart | cancel or stop, `deactivate()` if active, **idle** |

- A synthesizer completion from an earlier utterance is ignored (generation counter).
- Typed sends go to **thinking**, then **idle**, and never touch the audio session.

**`PlantChatAction`** gains `openSettings`.

---

## 4. UI (PlantChatiOS)

- **`PlantChatVoiceControlsView`** (DESIGN.md 6): a 56 pt keyboard button, an 84 pt mic
  button (`primary`, 6 pt `#CFE6C8` border as a new `PlantChatColor` token) and a 56 pt
  end button (`ink`).
- **Mic icon by activity:**
  - idle and speaking: `mic.fill` (while speaking, a tap interrupts);
  - listening: `stop.fill`;
  - thinking: `ellipsis`, disabled.
- **Mic accessibility labels:** "Talk to %@", "Stop listening", "Interrupt %@".
- **Live transcript:** a user bubble at 60% opacity, last in the list. It shows
  "Listening…" until the first words arrive. It goes away when the real bubble is added.
- **Keyboard mode:** the M5 `PlantChatInputView`, with a 48 pt round mic button on its left
  that returns to voice mode (`voiceTap`). Open question 4.
- **Microphone notice:** a `card` row under the Sprout, with an "Open Settings" text button
  when the notice has one.
- **"Speak replies":** a `Toggle` in the existing sliders menu, under the personalities.
  `PlantChatPersonalityMenuView` gets one more option.
- **Store:** `activity`, `liveTranscript: String?`, `inputMode`, `microphoneNotice`,
  `isSpeakingReplies`.
- **`PlantChatView`:** calls `viewModel.disappear()` from `onDisappear` and from
  `onChange(of: scenePhase)` when it isn't `.active`.
- Everything stays SwiftUI only and compiles on macOS. Opening Settings goes through the
  action to the app.

---

## 5. Platform clients (PlantChat/Client, not unit-tested)

- **`SpeechAnalyzerPlantTranscriberClient`** (`@available(iOS 26, macOS 26, *)`, iOS only):
  - `AVAudioEngine` input tap → `AVAudioConverter` to
    `SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith:)` →
    `AsyncStream<AnalyzerInput>`.
  - A main-actor `Task` reads `transcriber.results` and maps each result's `isFinal` to
    `.volatile` / `.final`.
  - `finish()` stops the engine and calls `finalizeAndFinishThroughEndOfInput()`, then
    sends `.finished`. `cancel()` calls `cancelAndFinishNow()`.
  - **Swift 6 pitfall:** a tap closure created inside a `@MainActor` method is inferred
    `@MainActor` and crashes on the audio thread. The tap must be installed from a
    `nonisolated` function and must only touch the stream continuation.
- **`AVSpeechPlantSynthesizerClient`:**
  - `usesApplicationAudioSession = true`.
  - The delegate methods (`didFinish`, `didCancel`) are `nonisolated` and hop to the main
    actor before calling the completion.
- **`AVAudioSessionPlantAudioSessionClient`** (`#if os(iOS)`):
  - Category, mode and options from 1.6, set on `activate()`.
  - Observes `interruptionNotification`, `routeChangeNotification` (reason
    `.oldDeviceUnavailable`) and `mediaServicesWereResetNotification` (treated as an
    interruption).
  - Reads the values out of the `Notification` before hopping to the main actor.

---

## 6. App wiring

- Creates the three clients, `TranscriberPlantTranscriptLoader(client:)` and
  `PlantSpokenReplySettings(defaults:)`, and passes them to `PlantChatUIComposer.composed`.
- `PlantChatAction.openSettings` opens `UIApplication.openSettingsURLString`.
- DEBUG builds accept `-PlantSpeechUnsupported`. It injects a transcriber client that
  reports `.unsupported`, to check keyboard-only mode in the simulator.

---

## 7. Docs (S7)

- **ROADMAP.md:** an M5b section linking this plan; "voice chat" is removed from Later.
- **ARCHITECTURE.md:** the dependency table row gets Speech and AVFoundation as examples of
  system frameworks inside a feature's `Client/` folder.
- **DESIGN.md section 6:** the mic states, the live transcript bubble, keyboard mode, and
  the notice.

---

## 8. Test doubles

Added to `PlantChatXCTestCase` (and copied into `PlantChatiOSXCTestCase` where needed, as
M5 did):

- `TranscriberClientSpy`: records messages, stubs the authorization, sends events on demand.
- `ScheduleSpy`: records intervals and fires timers by index.
- `TranscriptLoaderStub`: records messages, stubs the authorization, completes the
  request, sends partial and final transcripts or errors.
- `SynthesizerSpy`: records `speak(text, style)` and `stop`, finishes by index.
- `AudioSessionSpy`: records `activate` / `deactivate`, stubs the activation result, sends
  events.
- `DefaultsSpy`: gains Bool values.

---

## 9. Steps

Each step leaves `swift test` green for the targets it touches and the app building. No
commits. The human runs the iOS integration tests and the device checks.

### S0. Severity ranking injected into the notifier

The notifier is built in the composition root (`TalkingPlantApp`). That's the only place
that can see both `PlantHealthIssue` and PlantChat, so the ranking is passed in from there.

- **Files:**
  - `PlantChat/API/PlantMoodNotifier.swift`:
    - new init parameter `severityRanking: [PlantMood]` (most severe first, no default);
    - the private copied list goes away;
    - a mood missing from the ranking counts as least severe, as happy does today.
  - `TalkingPlant/TalkingPlantApp.swift`: passes `PlantHealthIssue.allCases.map(\.mood)`.
  - `Tests/PlantChatTests/PlantMoodNotifierTests.swift`: `makeSUT` and the leak test pass
    the same order as `PlantHealthIssue`.
- **Tests:**
  - `test_escalation_followsInjectedRanking`: with `[.thirsty, .veryThirsty]`, moving
    veryThirsty → thirsty inside the interval notifies, and thirsty → veryThirsty doesn't.
  - `test_moodMissingFromRanking_isNeverAnEscalation`.
  - All the existing escalation tests stay green.
- **Run:** `swift test --filter PlantChatTests`.
- **On device:** nothing new. A thirsty → very thirsty change still notifies inside the hour.

### S1. Domain types and the spoken replies setting

- **Files:**
  - Domain: `PlantChatActivity`, `PlantChatInputMode`, `PlantSpeechAuthorization`,
    `PlantTranscript`, `PlantSpeechStyle` (+ `PlantPersonality.speechStyle`),
    `PlantSpeechText`.
  - `PlantShared/Client/DefaultsClient.swift` and `UserDefaultsClient.swift`.
  - `PlantChat/Persistence/PlantSpokenReplySettings.swift`.
  - The `DefaultsClient` spies in the test targets.
- **Tests:**
  - `PlantSpeechStyleTests`: every personality has the table's values.
  - `PlantSpeechTextTests`: asterisks, underscores, hashes, emoji and whitespace; plain
    text is unchanged; an emoji-only reply becomes empty.
  - `PlantSpokenReplySettingsTests`: on by default, a saved off, the key.
  - `UserDefaultsClientTests`: a Bool round trip.
- **Run:** `swift test --filter PlantChatTests`, `--filter PlantSharedTests`.
- **On device:** nothing.

### S2. Client protocols and the transcript loader

- **Files:**
  - `PlantChat/Client/`: `PlantTranscriberClient.swift` (with the event and error),
    `PlantSynthesizerClient.swift`, `PlantAudioSessionClient.swift` (with the event).
  - `PlantChat/Domain/PlantTranscriptLoader.swift`.
  - `PlantChat/API/TranscriberPlantTranscriptLoader.swift`.
  - The spies in `PlantChatXCTestCase`.
- **Tests (`TranscriberPlantTranscriptLoaderTests`):**
  - init doesn't message the client; authorization, request and prepare are forwarded;
  - start starts the client and schedules the no-speech timer;
  - volatile text replaces volatile text; final segments append; partials carry committed
    plus volatile text;
  - the silence timer finishes the client, and a new word makes the older timer do nothing;
  - the no-speech timeout cancels and delivers an empty final transcript; it does nothing
    after the first word;
  - the maximum duration finishes the client;
  - stop finishes the client; `.finished` delivers the trimmed final text once;
  - failures map to `.preparing` and `.transcription`;
  - cancel delivers nothing more, even when the client keeps sending;
  - `test_start_doesNotCreateMemoryLeaks`.
- **Run:** `swift test --filter PlantChatTests`.
- **On device:** nothing.

### S3. Platform clients and Info.plist

- **Files:**
  - `PlantChat/Client/SpeechAnalyzerPlantTranscriberClient.swift`.
  - `PlantChat/Client/AVSpeechPlantSynthesizerClient.swift`.
  - `PlantChat/Client/AVAudioSessionPlantAudioSessionClient.swift`.
  - `TalkingPlant/Info.plist`: the two keys from 1.7.
- Not wired yet.
- **Tests:** none; these wrap system APIs (section 5).
- **Run:** `swift test --filter PlantChatTests` (still compiles on macOS); the human builds
  the app.
- **On device:** nothing yet.

### S4. View model: listening

- **Files:**
  - `PlantChatViewModel.swift`: `submit`, `micTap`, `keyboardTap`, `voiceTap`, `endTap`,
    `disappear`, the listening states, audio session events.
  - `PlantChatMicrophoneNoticeViewModel.swift`.
  - `PlantChatAction.swift`: `openSettings`.
  - `PlantChat.strings`: the notices, mic labels, "Listening…".
  - `PlantChatUIComposer.swift`: takes and passes the two new collaborators only; no UI.
  - `TalkingPlantApp.swift`: creates them; `.openSettings` handled.
- **Tests (`PlantChatViewModelTests`, plus `PlantChatMicrophoneNoticeViewModelTests`):**
  - appear with each authorization → input mode and notice; prepare is called once;
  - micTap when not determined: requests, then listens on authorized, or shows the notice
    and keyboard mode on denied;
  - micTap when authorized: activates, then starts, **listening**; activation failure →
    notice, no start;
  - a partial emits the transcript;
  - a final transcript adds your bubble and sends to the chat loader exactly like a typed
    send (same `ChatLoaderStub.sends`), **thinking**, then **idle** on the reply;
  - an empty final, a failure, an interruption or a lost output → **idle**, deactivated,
    nothing sent;
  - micTap while listening stops the loader; micTap while thinking is ignored;
  - endTap cancels, deactivates and sends `.backTap`; disappear cancels and deactivates;
  - a personality change while listening cancels;
  - a typed send goes thinking → idle without activating the session;
  - the existing tests stay green with the new `makeSUT`.
- **Run:** `swift test --filter PlantChatTests`. The human runs PlantChatiOSTests (the
  composer signature changed).
- **On device:** nothing visible yet. Chat by text still works.

### S5. Talk screen: voice controls

- **Files:**
  - `PlantChatiOS/Views/PlantChatVoiceControlsView.swift`.
  - `PlantChatView.swift`: input mode, the live transcript bubble, the notice,
    `disappear`, scene phase.
  - `PlantChatStore.swift`, `PlantChatUIComposer.swift`, `PlantChatColor` (mic border),
    `PlantChatSize`.
  - `PlantChatiOSXCTestCase.swift`, `PlantChatView+ViewInspector.swift`.
  - `TalkingPlantApp.swift`: `-PlantSpeechUnsupported`.
- **Integration tests (`PlantChatUIITests`):**
  - voice mode shows the three buttons and no text field;
  - keyboard shows the text field, and its mic returns to voice mode;
  - mic tap → start, and the live bubble shows "Listening…" and then the partial text;
  - a final transcript → your bubble, then "…";
  - the mic is disabled while thinking;
  - denied shows the notice with Open Settings, which sends `.openSettings`;
  - restricted and unsupported show the notice without a button, in keyboard mode;
  - end sends `.backTap`.
- **Run:** `swift test --filter PlantChatTests`; the human runs PlantChatiOSTests.
- **On device:**
  - the first mic tap shows the microphone prompt, and then (maybe) the speech prompt;
  - talking shows live words, it stops by itself after a pause, and the reply arrives;
  - tapping to stop early sends what was heard;
  - after denying, the notice and Open Settings work, and allowing then tapping the mic
    works without a relaunch;
  - music playing in another app stops while listening and resumes after the reply;
  - AirPods work as the mic;
  - the simulator with `-PlantSpeechUnsupported` is keyboard only.

### S6. Spoken replies and mute

- **Files:**
  - `PlantChatViewModel.swift`: the speaking states, `setSpokenReplies`, the generation
    counter.
  - `PlantChat.strings`: "Speak replies".
  - `PlantChatPersonalityMenuView.swift` (the toggle), `PlantChatUIComposer.swift`,
    `PlantChatStore.swift`, `PlantChatVoiceControlsView` (the interrupt label).
  - `TalkingPlantApp.swift`: synthesizer and settings.
  - The test base classes.
- **Tests (`PlantChatViewModelTests`):**
  - a voice turn's reply is spoken, cleaned, with the personality's style, **speaking**;
    finished → **idle** and deactivated;
  - the template fallback reply is spoken;
  - spoken replies off → not spoken; a typed turn is never spoken; the greeting is never
    spoken;
  - micTap while speaking: stop, then listen, with one activation and no deactivation in
    between; the stale completion is ignored;
  - an interruption, a lost output or turning it off while speaking → stop, **idle**;
  - an interruption while thinking → the reply is shown, not spoken;
  - `setSpokenReplies` saves and emits; endTap and a personality change while speaking stop
    the speech.
- **Integration tests:**
  - the menu shows "Speak replies" with its saved state, and toggling saves it;
  - the mic's label while speaking is the interrupt label.
- **Run:** `swift test --filter PlantChatTests`; the human runs PlantChatiOSTests.
- **On device:**
  - each personality sounds different, and a reply with `*sighs*` doesn't read asterisks;
  - it speaks in silent mode after a spoken question, and stays quiet for typed ones;
  - tapping the mic while Sprout talks cuts it off and listens;
  - pulling AirPods out stops the speech;
  - a phone call or Siri during a reply stops it and nothing resumes;
  - leaving the screen or locking the phone stops it;
  - mute is kept after a relaunch;
  - with `-PlantVoiceUnavailable`, template replies are spoken.

### S7. Docs

- **Files:** ROADMAP.md, ARCHITECTURE.md, DESIGN.md, as in section 7.
- **Tests:** none.
- **On device:** nothing.

---

## 10. Open questions

1. **Speech recognition permission.** Does SpeechAnalyzer need
   `SFSpeechRecognizer.requestAuthorization` and `NSSpeechRecognitionUsageDescription`, or
   only the microphone? I couldn't confirm it in Apple's docs. The plan asks for both to be
   safe. If S5 on the device shows SpeechAnalyzer works without it, drop the speech prompt
   and key.
2. **Greeting.** Should the greeting be spoken when Talk opens in voice mode? The plan says
   no, so opening the screen is always silent.
3. **End button.** The plan treats it as hanging up: stop everything and go back. The
   alternative is "stop what Sprout is doing" and staying on the screen.
4. **Keyboard mode layout.** DESIGN.md only describes voice mode. The plan proposes the M5
   text field with a 48 pt mic on its left. Is a design pass wanted first?
5. **Mute placement.** The plan uses a toggle in the sliders menu, with no design change. A
   header speaker button would be one tap away, but adds a third header button.
6. **Voices.** Language variants of the default voices are safe on every device. Should
   enhanced or premium voices be used when installed? They need a download in Settings.
7. **Timeouts.** 1.5 s silence, 6 s nothing heard, 30 s maximum. Tune after S5 on the
   device.
8. **VoiceOver.** When VoiceOver is running, should spoken replies be off by default, so
   the two voices don't overlap?
9. **Dark mode mic border.** DESIGN.md gives `#CFE6C8` only. Use it in both schemes?
10. **For the Rive milestone:** lip sync could later use the synthesizer's
    `willSpeakRangeOfSpeechString`. Not planned here.
11. **Unrelated, found while reading:** `Info.plist` has the literal key
    `Bluetooth Always Usage Description` instead of `NSBluetoothAlwaysUsageDescription`.
    iOS won't find it, so CoreBluetooth would crash on first use in M6. It's not fixed
    here, since it's out of scope.
