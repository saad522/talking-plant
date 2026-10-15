# P1 plan: Sprout feels alive

Haptics, reward sounds, Sprout speaking on home, a sun and moon that follow the clock, a shake
reaction, and a slightly longer intro. Sources: `docs/ARCHITECTURE.md`, `docs/DESIGN.md`,
`docs/plans/D1.md`, `docs/plans/intro.md`, `docs/plans/M5c-kokoro.md` (section 11 follow-ups),
and the PlantMonitor, PlantChat, PlantDevice, PlantFace and PlantIntro code.

Steps S1–S9 are in section 5, ordered from lowest to highest risk. Each step is one session,
ends with passing tests, and has a short on-device checklist.

---

## 0. Open decisions

**Status: approved as recommended, with one change to D5 (a tap on Sprout is always audible).**
The changed rule is reflected in D5, D7, section 3 and S8.

**D1. How the sun and moon fit the scene logic.**
Today the scene (day / thirsty / night) comes from the readings (lux < 10 or offline means
night), and the first frame uses the remembered scene. The real clock and the readings can disagree:
a dark room at 14:00, a lamp at 23:00, or the simulated clock, which runs ahead.
- **Recommended:** the scene still picks the body (sun for day and thirsty, moon for night) and
  the palette, exactly as today. The real clock only picks *where* the body sits on its arc. The
  sun's arc runs 06:00 → 18:00 and the moon's 18:00 → 06:00, the same hours as the simulator's
  light curve. Outside its own hours, a body waits at the nearest end of its arc. For example, a
  moon in a dark room at 14:00 sits low on the right, and a sun under a lamp at 22:00 sits low on
  the right too. The data stays in charge (DESIGN 1, "the world reacts to real data"), and the
  first frame still uses the remembered scene, now with the position for the current time.
- Alternative: the clock picks sun or moon too. Rejected: a moon in a day palette, and it breaks
  the night rule in DESIGN 2.
- The real clock (`Date()`) is used in both modes. In simulated mode the scene follows the
  simulated light, so the body often waits at an arc end. That is accepted.

**D2. What "watered" means for the success feedback.** The code has no "watered" event. Water
calls `water()` in simulated mode and asks the sensor for a reading in sensor mode.
- **Recommended:** after a Water tap, the first reading within **10 minutes** (real clock) whose
  moisture is at least **10 points** above the last moisture before the tap counts as watered. It
  fires once, then success haptic + chime. Watering without tapping Water gets no feedback (not
  in scope).

**D3. Where the "Sound effects" toggle lives.** The only menu with toggles is the Talk screen's
sliders menu, which has "Speak replies". The home sliders button opens the sensor settings
(PlantDevice), which is about the sensor.
- **Recommended:** in the Talk sliders menu, right under "Speak replies", so both audio
  preferences sit together. The setting is `PlantSoundEffectSettings` in `PlantChat/Persistence`
  (same shape as `PlantSpokenReplySettings`). The app reads it to gate sounds everywhere.
- Note: "Speak replies" now also controls home speech, and it is still only reachable from Talk.

**D4. Which sound plays when.** You gave three sounds but not all their moments.
- **Recommended:**
  - `chime`: watered (D2) and calibration saved, together with the success haptic.
  - `pop`: the shake reaction.
  - `greet`: cold-launch intro, when the greeting text starts to rise (0.4 s). Not played with
    Reduce Motion, which shows no text, and not played if a tap skips the intro before 0.4 s.
  - Button taps get a haptic only, no sound.

**D5. Audio session for Sprout speaking on home.** Chat uses `.playAndRecord` (mic). Home has no
mic. **Approved with a change:** the session depends on what started the line.
- **Automatic lines** (mood change, first open of the day) and **shake lines** use `.ambient`, like
  the sounds. The silent switch mutes them, and the user's music keeps playing, mixed. A shake is
  not a request to hear Sprout, so its line follows the switch too.
- **A tap on Sprout** is an explicit request, like tapping play on a video, so it is always
  audible. That one utterance uses `.playback` with `.duckOthers`: it plays with the silent switch
  on, and music ducks under it. When the line ends or stops, the session deactivates with
  `.notifyOthersOnDeactivation`, so music comes back to full volume.
- The trigger travels with the request: `PlantMonitorVoice.speak(_:mood:trigger:completion:)`
  with `PlantMonitorSpeechTrigger` (`automatic`, `tap`). The app adapter picks the session. The
  next sound or automatic line switches back to `.ambient`.
- Chat keeps its own session and activates it as today.

**D6. How "wait for Kokoro up to 8 s" is built.** `FallbackPlantSynthesizerClient` switches to
the Apple voice when the primary has produced no audio after `startTimeout` (3 s). Today, while
Kokoro loads, that is why the first chat greeting uses the Apple voice.
- **Recommended:** `FallbackPlantSynthesizerClient` gets `isPrimaryLoading: () -> Bool` and
  `loadingStartTimeout = 8`. When the model is loading at `speak`, the timeout is 8 s. Otherwise
  it stays 3 s. The app passes `{ generator.state == .loading }`. One change covers home lines,
  the chat greeting, and chat replies. It closes the M5c follow-up. When the model is not loaded
  and not loading (just unloaded), `generate` throws at once, and the Apple voice speaks
  immediately, as today.

**D7. Rules for speaking on home.**
- **Recommended:**
  - The line spoken is the bubble's *final* line: the generated line, or the template when
    generation fails. It is never the template followed later by the generated line.
  - "Mood changes" means the `PlantMood` differs from the last mood spoken on home. Scene and
    sleeping changes alone don't count. The last mood and day are saved, so a relaunch on the
    same day with the same mood stays quiet.
  - "First open of the day" uses the phone's local calendar day.
  - Home "open" means the home is on screen and the app is active. The view reports `onAppear`,
    `onDisappear` and `scenePhase`. Coming back from the background fires no `onAppear`, so
    `scenePhase` is needed for the morning case.
  - **Settle delay of 2.5 s** after home becomes visible, before an automatic line. This clears
    the intro (2.2 s after S1), which runs over the home that is built underneath. It also lets
    the first reading and mood arrive (in sensor mode the plant starts offline).
  - Automatic lines skip the `offline` mood, so sensor mode doesn't say "I can't feel my sensor"
    and then a second line once it connects. A tap still speaks it.
  - At most one automatic line every 60 s. A mood change inside that window is spoken when the
    window ends, if home is still visible and the mood still differs.
  - Tapping Sprout speaks the current final line with the `tap` trigger (always audible, D5). A
    tap also counts as "spoken today".
  - A tap while an automatic or shake line is playing stops it and speaks the line again with
    the `tap` trigger, because that line may be muted by the silent switch. A tap while a tapped
    line is playing is ignored (no stutter).
  - Leaving home (Talk, History, Settings, background) stops a home line at once. Home only stops
    speech it started, so it never cuts the chat greeting.

**D8. Surprised face.** PlantFace has no surprised expression.
- **Recommended:** surprised = the mood's own pose (colors, leaves, tilt, soil, effects) with the
  overwatered eyes (open, ry 11), brows and filled "o" mouth from DESIGN 5.2. No blink while
  surprised. Asleep wakes up with open eyes. Added to DESIGN 5.2 as a reaction row.

**D9. The shake bridge.** SwiftUI has no shake event.
- **Recommended:** a single app-target file overrides `motionEnded(_:with:)` on `UIWindow` in an
  extension. On `.motionShake` it posts a notification. An app adapter turns that into a
  `PlantShakeLoader` (`subscribe(update:)`), the same pattern as the other loaders.
- Alternative: a hidden first-responder view controller. Rejected: it is fragile when focus
  moves.

**D10. Where the concrete haptics and sound clients live.**
- **Recommended:** `PlantShared/Client`, behind `#if os(iOS)` (`UIKitPlantHapticsClient`,
  `AVAudioPlayerPlantSoundEffectsClient`), because three features need them (PlantMonitor,
  PlantDevice, PlantIntro). The ARCHITECTURE section 2 table then allows UIKit feedback
  generators and AVFoundation in `PlantShared/Client`.
- The intro's direct `UIImpactFeedbackGenerator` call moves onto the seam, so there is one
  haptics path.

---

## 1. Notes against the code and Apple guidelines

- **Haptics on every home button** is fine if kept to taps (HIG: use haptics sparingly and
  consistently). Nothing plays on appear, on data updates or on scene changes. UIKit feedback
  generators already respect Settings › Sounds & Haptics › System Haptics.
- **Sounds:** `.ambient` respects the silent switch and mixes with other audio, as the HIG asks
  for non-essential sounds. Automatic home lines follow the same rule. A tapped line is
  user-started playback, so `.playback` is appropriate (D5).
- **Intro vs home speech:** home appears under the intro on a cold launch, so without the settle
  delay (D7) Sprout could talk during the intro.
- **Voice timeout:** the 3 s start timeout would cut Kokoro off long before 8 s (D6).
- **Shake** is also iOS's "Shake to Undo". Home has no text input, and shake is ignored on every
  other screen, so the two never meet.
- **Kokoro engine and the category switch:** `AVAudioEnginePlantSpeechPlayerClient` stops its
  engine after every utterance and starts it again on the next, so it picks up the current
  session. Kokoro lines on home, switching between `.ambient` and `.playback` and after a chat
  turn (`.playAndRecord`), still need a device check (S8).
- **Sprout tap and accessibility:** the character is hidden from accessibility today. The new tap
  target gets a button trait and the label "Hear Sprout".

---

## 2. Where things go

No new targets and no new dependencies. Composer parameters are appended without defaults. Each
step updates the app and the iOS test base class's `makeSUT`.

| Type | Target / folder | Step |
|---|---|---|
| `PlantHaptic` (`tap` = light impact, `success` = success notification, `bump` = soft impact), `PlantHapticsClient` | PlantShared/Client | S2 |
| `UIKitPlantHapticsClient` (`#if os(iOS)`) | PlantShared/Client | S2 |
| `PlantDeviceCalibrationViewModel.loadedSaved` | PlantDevice/Presentation | S2 |
| `PlantMonitorSkyViewModel` (body + arc progress) | PlantMonitor/Presentation | S3 |
| `PlantWateringCheck` (pure: rise ≥ 10 points) | PlantMonitor/Domain | S4 |
| `PlantFaceViewModel(mood:isSurprised:)`, `PlantFaceUIComposer.composed(mood:isSurprised:)` | PlantFace / PlantFaceiOS | S5 |
| `FallbackPlantSynthesizerClient.loadingStartTimeout`, `isPrimaryLoading` | PlantChat/API | S6 |
| `TrackingPlantSynthesizerClient` (decorator with `isSpeaking`) | PlantChat/API | S6 |
| `PlantSoundEffect` (`chime`, `pop`, `greet`), `PlantSoundEffectsClient` | PlantShared/Client | S7 |
| `GatedPlantSoundEffectsClient` (decorator: setting on, voice not speaking) | PlantShared/Client | S7 |
| `AVAudioPlayerPlantSoundEffectsClient`, `PlantHomeAudioSession` (`#if os(iOS)`; `activateAmbient()` in S7, `activatePlayback()` and `deactivate()` in S8) | PlantShared/Client | S7, S8 |
| `PlantSoundEffectSettings` | PlantChat/Persistence | S7 |
| `PlantMonitorVoice` (protocol: `speak(_:mood:trigger:completion:)`, `stop()`), `PlantMonitorSpeechTrigger` (`automatic`, `tap`), `PlantMonitorSpokenLine` | PlantMonitor/Domain | S8 |
| `PlantMonitorSpeechPolicy` (pure: speak or not) | PlantMonitor/Domain | S8 |
| `PlantSpokenLineStore` (last spoken mood and day) | PlantMonitor/Persistence | S8 |
| `PlantMonitorSproutViewModel` (home voice, tap, later shake) | PlantMonitor/Presentation | S8, S9 |
| `PlantShakeLoader` (protocol) | PlantMonitor/Domain | S9 |
| `PlantMonitorShakeLines` (+ strings) | PlantMonitor/Presentation | S9 |
| `PlantMonitorVoiceAdapter`, `NotificationPlantShakeLoader`, `DeviceShake.swift` | App target | S8, S9 |

**Sound assets** (you supply them): `ios/TalkingPlant/TalkingPlant/Sounds/`
- `sprout_chime.caf`: success, ≤ 0.8 s
- `sprout_pop.caf`: shake, ≤ 0.25 s
- `sprout_greet.caf`: intro, ≤ 1.2 s

The project uses synchronized folders, so dropping files there adds them to the app bundle. The
client looks for `.caf` first, then `.wav`. A missing file is logged and skipped, so every step
works before the files exist. Format: mono, 44.1 or 48 kHz, 16-bit PCM (or IMA4 in `.caf`). No
leading silence. Peaks at or below −3 dBFS, quieter than Sprout's voice (around −20 LUFS).
Licensed for distribution.

---

## 3. Behavior specs

**Haptics** (one `PlantHapticsClient` instance per app, a spy in tests)

| Moment | Haptic |
|---|---|
| Talk, Water, History buttons, home sliders button | `tap` |
| Watered (D2), calibration saved | `success` |
| Intro bounce (moved from the view) | `bump` |
| Shake reaction | `bump` (once) |

**Sounds** (D4): played through `GatedPlantSoundEffectsClient`. Nothing plays when "Sound
effects" is off or while Sprout's voice is speaking (`TrackingPlantSynthesizerClient.isSpeaking`).

**Sky** (D1): `PlantMonitorSkyViewModel(scene:date:calendar:)` gives
- `body`: moon for night, sun otherwise
- `progress` (0…1): sun `(minutes − 360) / 720`, moon `((minutes − 1080 + 1440) % 1440) / 720`,
  both clamped to 0…1

`PlantMonitorViewModel` emits `loadedSky` on every scene and every 60 s (repeating schedule), with
`isGradual` true only for the same body and |Δprogress| ≤ 0.01. The window places the body's
center on an arc inside the glass:
- x goes from the left inset to the right inset
- y = horizon − sin(π · progress) · rise
- the panes draw over the body
- stars stay fixed

A gradual change animates `.linear(duration: 60)`, so it moves continuously at about 0.3 pt a
minute. A jump (new scene, back from background) doesn't animate. With Reduce Motion there is no
animation. The minute steps are far below 1 pt, so the body reads as static in the right place.

**Home speech** (D5, D7): `PlantMonitorViewModel` emits `loadedSpokenLine`
(`PlantMonitorSpokenLine`: text, mood, isSleeping) once per speech key, when the line is final.
`PlantMonitorSproutViewModel` holds the rules in D7.

The app's `PlantMonitorVoiceAdapter` does three things:
- activates `PlantHomeAudioSession` for the trigger: `activateAmbient()` for `automatic`,
  `activatePlayback()` (`.playback`, `.duckOthers`) for `tap`. After a tapped line ends or stops,
  it calls `deactivate()` (`.notifyOthersOnDeactivation`), so music returns to full volume
- cleans the text with `PlantSpeechText.clean`
- calls `voice.synthesizer.speak(text, style: personality.speechStyle.adjusted(for: mood))` on
  the one `SproutVoice`

Shake lines use the `automatic` trigger.

"Speak replies" (`PlantSpokenReplySettings.isEnabled`) gates both automatic lines and taps.

**Shake** (D8, D9): accepted only when all of these hold:
- home is visible (so never in chat or while recording)
- a mood is known
- at least 10 s since the last accepted shake (real clock)

Then, in order:
1. a playing home line stops
2. `loadedSurprised(true)`: the composer plays `bump` + `pop`, swaps in the surprised face and
   bumps `shakeCount` for the wobble
3. after 0.4 s, if speech is enabled and home is still visible, the shake line is spoken
4. after 1.0 s, `loadedSurprised(false)`

The shake line doesn't change the bubble or the spoken-line memory.

Wobble: a `keyframeAnimator` on the Sprout (anchor bottom) triggered by `shakeCount`: 0 → −8° →
7° → −5° → 3° → 0 over about 0.8 s. With Reduce Motion there is no wobble, only the face change.

Shake lines (two to three per mood; never the same line twice in a row for that mood; the random
index is injected):

| Mood | Lines |
|---|---|
| happy | "Whoa! What was that?" · "Hey, easy! I'm growing here." · "Wheee! Okay, that's enough." |
| thirsty, veryThirsty | "Careful! I'm too thirsty for rides." · "Shaking won't water me!" · "Whoa! Maybe a drink instead?" |
| drowning | "Whoa, I'm sloshing around in here!" · "Easy! My soil is soggy enough." |
| tooDark | "Huh? Who's there? It's so dark!" · "Whoa! I can't see a thing." |
| tooHot | "Whoa! Too hot for dancing." · "Careful, I'm already sweating!" |
| tooCold | "Brr! Shaking won't warm me up." · "Whoa! My leaves are chattering." |
| dryAir | "Whoa! My leaves feel crispy." · "Easy! The air's dry enough." |
| offline | "Huh? I still can't feel my sensor." · "Whoa! Is my sensor awake?" |
| sleeping | "Huh? I was dreaming!" · "Whoa! Is it morning already?" |

**Intro** (S1):
- The text is fully in at 1.0 s and held until the hand-off at 1.6 s.
- The glow keeps its 0.2–1.0 s window.
- Particles spread over 0.2–1.6 s, so the held moment still moves.
- Total: 1.6 + 0.6 = **2.2 s**. Skip and Reduce Motion are unchanged (0.3 s).

---

## 4. What is testable and how

**Approach in every step:** write the tests listed under "Tests first", add only the empty API
they need to compile, run them, and see them fail on assertions. Then implement until they pass.
Naming, base classes, `makeSUT`, spies and memory-leak tracking follow ARCHITECTURE 7.

**New test doubles** (in each target's base class, as needed):
- `HapticsSpy` and `SoundEffectsSpy` record what was played
- `VoiceSpy` records `speak` / `stop` and keeps the completions
- `ShakeLoaderStub` with `shake()`
- `ScheduleSpy` holds one-shot and repeating actions, so tests fire them by hand
- `DefaultsSpy` already exists

| Unit tests (macOS, `swift test`) | Integration tests (from the composer, ViewInspector) |
|---|---|
| Intro timeline constants and curves | Button taps → `HapticsSpy` gets `tap`, the action still fires |
| Calibration `loadedSaved` | Calibration save → `success` (+ `chime` in S7) |
| Sky progress table, `loadedSky` ticks and `isGradual` | Window gets the body and progress for a stubbed clock; a tick updates it |
| Watering check and the 10-minute window | Watered → `success` (+ `chime`) once |
| Surprised face view model | Surprised face renders wide eyes and the "o" mouth for every mood |
| Fallback timeout 8 s / 3 s, tracking decorator | Talk menu shows "Sound effects" and saves it |
| Sound gate, sound settings, chat toggle | Sprout tap → `VoiceSpy` speaks the bubble line |
| Speech policy, spoken-line store, Sprout view model rules | Shake → `FaceStub` surprised, `bump` + `pop`; reverts after the scheduled 1 s |
| Shake lines (coverage, no back-to-back repeat) | |

**Not unit-testable, checked on device:**
- real haptics and sounds
- the audio session category and its interplay with music and the silent switch
- the Kokoro engine across category switches
- `motionEnded` delivery
- wobble and sky animation
- timing feel

---

## 5. Steps

The rules for every step:
- Run only the listed test targets: `cd ios/PlantKit && swift test --filter <Target>`.
- When the app target changes, also build the app (CLAUDE.md "App build", `build` only, no
  simulator run).
- Update the docs listed in the step.
- Leave everything uncommitted.

### S1. Intro to 2.2 s (lowest risk)

- `PlantIntroTimeline`:
  - adds `textEnd = 1.0` and `glowEnd = 1.0`
  - `handoffStart` 1.0 → 1.6
  - `glow` uses `glowStart…glowEnd`; `textProgress` uses `textStart…textEnd`
  - particles keep using `handoffStart`, so they spread to 1.6
- Tests first (PlantIntroTests):
  - `textProgress` is 1 at 1.0 and at 1.5
  - `glow` is 0 at 1.0 and at 1.3
  - `handoffStart + handoffDuration == 2.2`
  - every particle has finished by `handoffStart`
  - `PlantIntroViewModel.handoffDelay == 1.6`
- Docs: `docs/plans/intro.md` timeline (2.2 s), `docs/ROADMAP.md` P1 entry pointing to this plan.
- Run: `PlantIntroTests`.
- On device:
  - [ ] Cold launch: Sprout bounces, the greeting rises, stays fully visible for about half a
    second, then hands off. The whole intro takes about 2.2 s.
  - [ ] A tap during the intro hands off in about 0.3 s.
  - [ ] Reduce Motion: only a 0.3 s crossfade.
  - [ ] Back from background: no intro.

### S2. Haptics seam

- PlantShared/Client: `PlantHaptic`, `PlantHapticsClient`, `UIKitPlantHapticsClient` (one light,
  one soft and one notification generator, created once).
- PlantMonitoriOS composer:
  - new `haptics` parameter
  - the Talk, Water and History actions play `tap` before calling the view model
  - `PlantMonitorView` gets the settings action from the composer, which plays `tap` and then
    calls `settingsTap()`
- PlantDevice: `PlantDeviceCalibrationViewModel.loadedSaved` fires after a valid save.
  `PlantDeviceUIComposer.composedCalibration(... haptics:)` plays `success` on it.
- PlantIntroiOS: `PlantIntroUIComposer.composed(... haptics:)`. The view plays `bump` at
  `hapticTime` and drops its UIKit import.
- App: one `UIKitPlantHapticsClient`, created in `TalkingPlantApp` and passed to `AppGraphStore`,
  the graphs and the intro.
- Tests first:
  - PlantMonitoriOSTests: each of Talk, Water, History and settings records `[.tap]` and still
    sends its action. Loading a reading, a mood and a scene records nothing.
  - PlantDeviceTests: a valid save fires `loadedSaved` once. An invalid save and a reset don't.
  - PlantDeviceiOSTests: save → `[.success]`, reset → `[]`.
- Docs:
  - ARCHITECTURE section 2 table (PlantShared/Client may use UIKit feedback generators and
    AVFoundation, iOS only) and 4.3 clients table
  - DESIGN new section 7 "Feedback" with the haptics table (sounds added in S7)
- Run: `PlantMonitoriOSTests`, `PlantDeviceTests`, `PlantDeviceiOSTests`, `PlantIntroTests`. Build
  the app.
- On device:
  - [ ] Talk, Water, History and the sliders button each give one light tick.
  - [ ] Saving a valid calibration gives a success buzz. An invalid one gives none.
  - [ ] The intro bounce still has its soft tap.
  - [ ] With System Haptics off, none of these play.
  - [ ] Scrolling or data updates never buzz.

### S3. Sun and moon on the real clock

- PlantMonitor: `PlantMonitorSkyViewModel`. `PlantMonitorViewModel` gets:
  - `clock: () -> Date` (real clock)
  - `calendar`
  - `schedule` (repeating, `SimulatedPeripheralClient.repeatingTimer` shape)
  - the `loadedSky` observer: emitted on every scene and every 60 s; the timer starts in
    `appear()` and stops once the view model is gone
- PlantMonitoriOS:
  - `PlantMonitorWindowView(body:progress:isGradual:)` places the body on the arc
  - new sizes in `PlantMonitorSize` (horizon, rise, insets)
  - the store starts with the sky for the remembered scene at the current time
  - the composer gets `clock` and `schedule`
- App: `clock: Date.init` in both modes, `schedule: SimulatedPeripheralClient.repeatingTimer`.
- Tests first:
  - PlantMonitorTests sky progress: sun at 06:00 / 12:00 / 18:00 / 03:00 / 22:00 → 0 / 0.5 / 1
    / 0 / 1; moon at 18:00 / 00:00 / 06:00 / 12:00 → 0 / 0.5 / 1 / 1; body per scene
  - PlantMonitorTests view model: `appear` emits a sky; a tick 60 s later emits
    `isGradual == true`; a scene change sun → moon gives `isGradual == false`; a 3 h jump gives
    false; a released view model stops ticking
  - PlantMonitoriOSTests: at 12:00 the window shows the sun at 0.5; a night reading shows the
    moon; a tick updates the progress
- Docs: DESIGN 4 (window: the body on an arc by local time, the panes over it) and DESIGN 2
  (the scene still picks the body).
- Run: `PlantMonitorTests`, `PlantMonitoriOSTests`. Build the app.
- On device:
  - [ ] Around 09:00, the sun sits a quarter of the way along the arc, low left. Around noon it
    is at the top, partly behind the vertical pane.
  - [ ] Watch for a few minutes: no visible jumps. An hour later it has clearly moved.
  - [ ] Night scene (covered sensor or simulated night): the moon is at its clock position.
  - [ ] Reduce Motion: right position, no sliding.
  - [ ] Back from background after an hour: the body is in its new place without sliding there.
  - [ ] Cold launch: the first frame already shows the body in place (no slide from the corner).

### S4. Watered detection and success feedback

- PlantMonitor:
  - `PlantWateringCheck` (`minimumRise = 10`)
  - `PlantMonitorViewModel.waterTap()` opens a 10-minute window (real clock) with the latest
    moisture as the baseline; a second tap extends the window and keeps the baseline
  - the first reading in the window that rises by ≥ 10 points fires `loadedWatered` once and
    closes the window
- Composer: `loadedWatered` → `success`.
- Tests first:
  - PlantMonitorTests:
    - tap, then +10 → watered once
    - +9 → nothing
    - +10 after 10 min → nothing
    - no reading before the tap → nothing
    - a second rise → no second event
    - a rise without a tap → nothing
  - PlantMonitoriOSTests: tap Water, then a rising reading → `[.tap, .success]`
- Docs: DESIGN 7 (watered rule).
- Run: `PlantMonitorTests`, `PlantMonitoriOSTests`.
- On device:
  - [ ] Simulated, thirsty: tap Water → a light tick, and within a few seconds one success buzz.
  - [ ] Tap Water again while already wet → only the light tick.
  - [ ] Sensor: put the probe in water and tap Water → a success buzz after the read-now reading.

### S5. Surprised face

- PlantFace: `PlantFaceViewModel(mood:isSurprised: = false)` adds `isSurprised`. `blinks` is false
  while surprised. `state`, `drySoil` and `extraTilt` are unchanged.
- PlantFaceiOS:
  - `composed(mood:isSurprised:)` overload; `composed(mood:)` stays for chat
  - eyes, brows and mouth are keyed by an expression (the state, or surprised), so the existing
    cross-fade covers the swap
- Tests first:
  - PlantFaceTests: surprised for every mood keeps the state, soil and tilt, with `blinks` false
  - PlantFaceiOSTests: surprised renders open eyes (ry 11) and the filled mouth for every mood,
    and the mood's effects still show
- Docs: DESIGN 5.2 surprised reaction row (D8).
- Run: `PlantFaceTests`, `PlantFaceiOSTests`.
- On device:
  - [ ] Nothing new is visible yet (used in S9).
  - [ ] Home and Talk faces look and blink as before in each mood.

### S6. Voice chain: wait up to 8 s for Kokoro, speaking state

- PlantChat:
  - `FallbackPlantSynthesizerClient(primary:fallback:isPrimaryLoading:schedule:)` with
    `loadingStartTimeout = 8` (D6)
  - `TrackingPlantSynthesizerClient(decoratee:)` with `isSpeaking`, true from `speak` until that
    call's completion or `stop()`
- App (`SproutVoice`): passes `isPrimaryLoading: { generator.state == .loading }`, wraps the
  synthesizer in the tracking decorator, and exposes `isSpeaking`. Below the RAM gate it wraps
  the Apple voice the same way.
- Tests first (PlantChatTests):
  - Fallback: speaking while loading schedules 8 s; not loading schedules 3 s; loading with no
    audio by 8 s → the fallback speaks once; `.generated` before 8 s → no fallback
  - Tracking: `speak` → true; completion → false; `stop` → false; a second `speak` stays true
    until its own completion; an old completion doesn't clear it
- Docs: `docs/plans/M5c-kokoro.md` section 11 (mark the greeting follow-up done, with a link
  here).
- Run: `PlantChatTests`. Build the app.
- On device (Release, no debugger):
  - [ ] 13 Pro or 12 Pro: cold launch, open Talk right away. The greeting waits (at most 8 s)
    and is spoken in Sprout's Kokoro voice.
  - [ ] First launch after install on the 12 Pro: if Kokoro isn't ready within 8 s, the Apple
    voice speaks it.
  - [ ] Later replies sound as before.
  - [ ] A device under the RAM gate: the Apple voice right away.

### S7. Sound effects

- PlantShared/Client:
  - `PlantSoundEffect` with a `fileName`
  - `PlantSoundEffectsClient`
  - `GatedPlantSoundEffectsClient(decoratee:isEnabled:isVoiceSpeaking:)`
  - `PlantHomeAudioSession.activateAmbient()` (`.ambient`, active). S8 adds the playback side
  - `AVAudioPlayerPlantSoundEffectsClient(bundle:)`: lazy, cached players; activates the ambient
    session before playing; a missing file is logged and skipped
- PlantChat:
  - `PlantSoundEffectSettings` (key `plant.chat.soundEffects.enabled`, default on)
  - view model `setSoundEffects(_:)` and `loadedSoundEffects`
  - the menu gets a "Sound effects" toggle under "Speak replies"
  - string `plant.chat.soundEffects.label`
  - composer gets a `soundEffects` parameter
- Composers:
  - PlantMonitor `sounds`: watered → `chime`
  - PlantDevice calibration `sounds`: saved → `chime`
  - PlantIntro `sounds`: `greet` at `textStart`, only while playing with motion
- App: one `GatedPlantSoundEffectsClient` (`AVAudioPlayer…(bundle: .main)`, the setting,
  `voice.isSpeaking`), shared like the haptics client. Create the `Sounds/` folder.
- Tests first:
  - PlantSharedTests gate: plays when enabled and silent; not when disabled; not while the voice
    speaks
  - PlantChatTests: settings default on, saving; the view model toggle saves and emits
  - PlantChatiOSTests: the menu shows the toggle with its state, and toggling saves it
  - PlantMonitoriOSTests: watered → `[.chime]`
  - PlantDeviceiOSTests: save → `[.chime]`
- Docs: DESIGN 7 sounds table and the D4 mapping; DESIGN 6 (menu toggle); ARCHITECTURE 4.3
  clients table.
- Run: `PlantSharedTests`, `PlantChatTests`, `PlantChatiOSTests`, `PlantMonitoriOSTests`,
  `PlantDeviceiOSTests`. Build the app.
- On device (with your files in `Sounds/`):
  - [ ] Watered and calibration saved: chime together with the success buzz.
  - [ ] Cold launch: greet sound as the greeting rises. None with Reduce Motion.
  - [ ] Silent switch on: no sounds, haptics still work.
  - [ ] Music playing: it keeps playing, and the sounds mix on top.
  - [ ] "Sound effects" off in the Talk menu: no sounds anywhere. It stays off after a relaunch.
  - [ ] Without the files: everything works silently.

### S8. Sprout speaks on home

- PlantShared/Client: `PlantHomeAudioSession` gets `activatePlayback()` (`.playback`,
  `.duckOthers`, active) and `deactivate()` (`.notifyOthersOnDeactivation`).
- PlantMonitor:
  - `PlantMonitorVoice`, `PlantMonitorSpeechTrigger`, `PlantMonitorSpokenLine`,
    `PlantMonitorSpeechPolicy`, `PlantSpokenLineStore` (keys `plant.monitor.spoken.mood`,
    `plant.monitor.spoken.day`)
  - `PlantMonitorViewModel.loadedSpokenLine`
  - `PlantMonitorSproutViewModel`:
    - init: `voice`, `spokenLines`, `isEnabled`, `clock`, `calendar`, `schedule` (one-shot)
    - inputs: `appear()`, `disappear()`, `setActive(_:)`, `lineSettled(_:)`, `sproutTap()`
    - constants: `settleDelay = 2.5`, `minimumGap = 60`
    - rules as in D7
- PlantMonitoriOS:
  - `PlantMonitorView` holds the Sprout view model too: `onAppear` → both `appear()`;
    `onDisappear` → `disappear()`; `scenePhase` → `setActive`
  - the Sprout area is a plain button (button trait, label `plant.monitor.sprout.hear.label`
    "Hear %@") calling `sproutTap()`
  - composer: `voice`, `spokenLines`, `speaksLines`, `schedule`
- App:
  - `PlantMonitorVoiceAdapter`: the session per trigger (D5), the personality style and the one
    `SproutVoice`. It deactivates after a tapped line's completion, which also fires on `stop()`
  - `speaksLines: { PlantSpokenReplySettings(defaults:).isEnabled }`
  - DEBUG `-PlantSpokenLineReset` clears the memory at launch, for the checks below
- Tests first:
  - PlantMonitorTests policy: offline → no; same mood and day → no; new day → yes; new mood →
    yes; nothing saved → yes
  - PlantMonitorTests store: save and load, nothing saved
  - PlantMonitorTests main view model: `loadedSpokenLine` once per key with the generated line;
    the template on failure; an old key's result dropped
  - PlantMonitorTests Sprout view model:
    - nothing before 2.5 s, speaks after
    - disappear during the delay → silent
    - mood change while visible → speaks
    - a second change within 60 s → spoken when the gap ends
    - disabled → never, a tap included
    - offline → no automatic line, a tap speaks it
    - automatic lines use the `automatic` trigger; a tap uses `tap`
    - a tap while an automatic line plays → `stop`, then the same line with `tap`
    - a tap while a tapped line plays → ignored
    - disappear or inactive while speaking → `stop` once
    - disappear while silent → no `stop`
    - memory saved on speaking, by tap too
    - no leaks
  - PlantMonitoriOSTests: a tap on Sprout → `VoiceSpy` speaks the bubble text with `tap`; appear
    plus the settle timer → speaks with `automatic`; the Sprout button has its accessibility label
- Docs: DESIGN 4 (Sprout tap, speaking on home), DESIGN 7 (automatic home audio is `.ambient`, a
  tapped line is `.playback` with ducking).
- Run: `PlantMonitorTests`, `PlantMonitoriOSTests`. Build the app.
- On device (launch with `-PlantSpokenLineReset` the first time):
  - [ ] Cold launch: about 2.5 s after the intro, Sprout says the bubble line, in the Kokoro voice
    if it was ready within 8 s.
  - [ ] Relaunch, same day, same mood: silent.
  - [ ] Simulated plant drying to thirsty: the new line is spoken once.
  - [ ] Tap Sprout: the line again. Tap again while that tapped line plays: nothing.
  - [ ] "Speak replies" off: home is silent, taps too.
  - [ ] Open Talk while Sprout speaks: home speech stops at once. The chat greeting and the mic
    work as before.
  - [ ] Back on home: silent unless the mood changed.
  - [ ] Silent switch on: automatic lines are silent. Tap Sprout: the line is audible.
  - [ ] Silent switch on, tap Sprout while an automatic line is (silently) playing: it restarts,
    audible.
  - [ ] Music playing: during an automatic line the music keeps its volume, mixed. During a tapped
    line the music ducks, then returns to full volume when the line ends, or when you leave home
    mid-line.
  - [ ] After a tapped line, a sound effect with the silent switch on stays silent (back to
    `.ambient`).
  - [ ] After a Kokoro chat reply, back on home, tap Sprout, then wait for an automatic line:
    both in the Kokoro voice (the engine survives `.playAndRecord` → `.playback` → `.ambient`).
  - [ ] Background overnight, open in the morning: Sprout speaks.
  - [ ] Sensor mode before connecting: no "can't feel my sensor" line. It speaks once connected.
  - [ ] VoiceOver: "Hear Sprout, button".

### S9. Shake reaction (highest risk)

- PlantMonitor:
  - `PlantShakeLoader`
  - `PlantMonitorShakeLines` and strings `plant.monitor.shake.<group>.<n>`
  - `PlantMonitorSproutViewModel` gets `shakeLoader` and `randomIndex`, subscribes once in
    `appear()`, and emits `loadedSurprised` as in section 3 (cooldown 10 s, line after 0.4 s,
    face back after 1.0 s)
- PlantMonitoriOS:
  - the face closure becomes `(PlantMood, _ isSurprised: Bool) -> Face`
  - the store keeps the face mood and `shakeCount`
  - the composer plays `bump` + `pop` and swaps the face
  - the scene view wobbles on `shakeCount` unless Reduce Motion is on
- App:
  - `DeviceShake.swift` (D9)
  - `NotificationPlantShakeLoader`
  - `face: PlantFaceUIComposer.composed(mood:isSurprised:)`
- Tests first:
  - PlantMonitorTests lines: every mood and sleeping has at least 2 lines; with a random index
    stuck at 0, 20 picks never repeat back to back; sleeping uses the sleeping lines
  - PlantMonitorTests Sprout view model:
    - shake while visible → surprised true, false after 1 s, the line spoken after 0.4 s
    - a shake within 10 s → ignored; after 10 s → accepted
    - hidden → ignored
    - before a mood is known → ignored
    - speech disabled → surprised, no line
    - shake while a home line plays → `stop`, then the shake line
    - the shake line uses the `automatic` trigger
    - the memory is unchanged
  - PlantMonitoriOSTests: shake → `FaceStub` surprised, `[.bump]` and `[.pop]`; after the
    scheduled 1 s → not surprised; a scene update during the surprise keeps it surprised
- Docs: DESIGN 5.4 (wobble), DESIGN 7 (shake row).
- Run: `PlantMonitorTests`, `PlantMonitoriOSTests`. Build the app.
- On device:
  - [ ] Shake on home: Sprout wobbles, looks surprised for about 1 s, one soft tap, a pop, then a
    short line that fits the mood.
  - [ ] Shake again at once: nothing. After 10 s: works, with a different line from last time.
  - [ ] Reduce Motion: no wobble, only the face change.
  - [ ] Talk screen, while recording, History, Settings, intro: shaking does nothing.
  - [ ] "Speak replies" off: wobble, face, tap and pop, no line.
  - [ ] Shake while Sprout is speaking a home line: it stops, and the shake line follows.
  - [ ] Silent switch on: wobble, face and haptic, but the pop and the line are silent.
  - [ ] Sleeping at night: "Huh? I was dreaming!" (or its sibling) with open eyes, then asleep
    again.

---

## 5b. Follow-ups

- [x] Watering thank-you: on `loadedWatered`, `PlantMonitorSproutViewModel.watered()` speaks one of
  5 `PlantMonitorThanksLines` after 0.6 s (automatic trigger, `Speak replies` respected, home only,
  no back-to-back repeat), regardless of the once-per-mood-per-day rule. The mood-change line that
  follows within 30 s is suppressed and marked said for today. DESIGN 7.
  - On device:
    - [ ] Thirsty, tap Water: tick, buzz and chime, then about 0.6 s later a thank-you, and no
      "happy" line after it.
    - [ ] Water again later: a different thank-you.
    - [ ] "Speak replies" off, or silent switch on: no spoken line.

## 6. Out of scope

- Haptics or sounds in the Talk screen.
- Watering detection without a Water tap.
- Real sunrise and sunset times (no location).
- A home toggle for "Speak replies".
- Generated shake lines.
- Rive.
