# M5 fixes plan: after testing on a real iPhone

Scope: four fixes found while testing M5 on a device. Nothing else.

Out of scope: new features, restyling, and anything not listed below.

## 1. Home screen layout jumping

**What was checked**

- The breathing animation uses `scaleEffect` on the head (`PlantFaceView.head`), so it never
  changes layout size.
- The speech bubble sits inside the scene, which has a fixed height of 440 pt
  (`PlantMonitorSize.sceneHeight`), so a bubble change can't change any layout height.
- Nothing resets the scroll position or the safe-area layout on updates.

**Likely cause** (found by reading the code; can only be confirmed on a device)

- `PlantFaceView.onAppear` starts breathing and sway with `withAnimation(.repeatForever)`.
- The face first appears in the same update as the first `loadedScene`. That update also:
  - changes the palette, which changes `.toolbarColorScheme` and the nav bar;
  - swaps the loading skeleton for the chips;
  - adds the buttons.
- The never-ending animation can pick up those layout and safe-area changes, so the whole
  scroll content keeps moving up and down. This is a known SwiftUI problem with
  `repeatForever` started in `onAppear` inside a `NavigationStack`.
- A second problem: `.animation(value: store.palette)` in `PlantMonitorView` wraps the
  `ScrollView` itself. Any layout or inset change that happens during a scene change slides
  over 1 second.

**Fix**

- `PlantFaceView`: start breathing and sway by setting the state without `withAnimation`.
  - Breathing: scope it with `.animation(_:body:)`, so the repeating animation only drives
    the head's `scaleEffect`.
  - Sway: put a value-based `.animation(PlantFaceAnimation.sway, value: isSwayingForward)`
    on the top leaves only.
- `PlantMonitorView`: move the palette fade from the `ScrollView` onto the scroll content
  and the background. It can then no longer animate the scroll view's geometry or the
  toolbar.

**Tests**

- No unit test can catch an animation transaction. Check on the device.

## 2. Speech bubble

- `PlantSpeechBubbleView`: a fixed height that fits 3 lines of `PlantMonitorFont.bubble`
  plus padding, with `lineLimit(3)` and the text top-aligned. Width and position stay the
  same, so the bubble can never cover the Sprout's head. The height goes in
  `PlantMonitorSize`.
- `PlantVoicePrompt.cleanLine` also rejects, so the caller uses the template:
  - lines with more than 12 words;
  - lines longer than 70 characters (`maximumLineLength` goes from 100 to 70);
  - lines containing "your plant", in any case.
- Tests in `PlantVoicePromptTests`: accepts 12 words and rejects 13; accepts 70 characters
  and rejects 71; rejects "your plant" and "Your Plant".

## 3. AI accuracy

Every prompt change gets a test in `PlantVoicePromptTests`.

### 3a. All current problems, not just the top mood

Per-sensor negatives need every current issue. With the mood alone, "too hot and thirsty"
would wrongly say "you do NOT need water".

- `PlantMoodLoader` returns a new `PlantMoodState`: the mood plus
  `problems: [PlantMood]` (every current issue, in priority order).
- `PlantHealthMoodLoaderAdapter` in the app fills it from `health.issues.map(\.mood)`.
- `PlantVoiceFacts` gets two new fields, both with default values so existing call sites
  keep working:
  - `problems: [PlantMood] = []`
  - `wateredMinutesAgo: Int? = nil`
- `LocalPlantVoiceFactsLoader` passes the problems through. The home speech adapter passes
  `[mood]`.

### 3b. Facts wording

- Chat turns (`PlantVoicePrompt.message`) start with:
  "Right now (always trust this over anything said earlier in the conversation):"
- Each sensor with no problem gets an explicit negative:
  - Soil: "your soil moisture is fine: you do NOT need water"
  - Light: "your light is fine: you do NOT need more light"
  - Temperature: "your temperature is fine: you are NOT too hot or too cold"
  - Air: "the air humidity is fine: the air is NOT too dry"
- Dry soil and dry air stay clearly separate:
  - Thirsty: "your SOIL is dry (this is about water in the pot, not the air)"
  - Dry air: "the AIR in the room is dry (this is about humidity, not your soil; you do NOT
    need water)"
- Tests: a negative for each in-range sensor; no negative for a sensor with a problem;
  "too hot and thirsty" has no soil negative; the dry-soil and dry-air wordings; the chat
  header.

### 3c. Recent watering

- `LocalPlantVoiceFactsLoader` checks the stored readings from the last hour. When moisture
  rose more than 20 points over an earlier reading in that hour, it sets `wateredMinutesAgo`.
  N is the minutes from the first reading of that rise to now.
- The facts text then adds: "you were watered N minutes ago".
- Loader tests:
  - a rise of 21 points → fact set, with the right minutes;
  - a rise of exactly 20 points → no fact;
  - a rise that started more than an hour ago → no fact;
  - readings without moisture are skipped.
- Prompt test: the line is there when set, and missing when nil.

### 3d. Chat greeting and reopening Chat

- `greet()` always loads fresh facts first, both on appear and on a personality change. It
  only asks for the line after the facts load.
- If the mood changes while the line is being generated, the greeting falls back to the
  neutral template ("Hi! Ask me anything.").
- Reopening Chat keeps the conversation, but starts a fresh one (session reset, messages
  cleared, new greeting) when either:
  - the mood changed since the last message, or
  - more than 30 minutes passed since the last message, on the real clock.
- How it works:
  - `PlantChatViewModel` gets `currentDate: () -> Date` (default `Date.init`). The app passes
    the real clock, not the simulated one.
  - It records the date and the mood of the last message.
  - The first `appear()` sets things up as now. Each later `appear()` reloads the facts and
    checks the two conditions.
- Tests in `PlantChatViewModelTests`:
  - the greeting is requested only after the facts load, using those facts;
  - the template greeting is used when the mood changes during generation;
  - reopening with the same mood within 30 minutes keeps the messages and doesn't greet;
  - reopening after the mood changed starts fresh;
  - reopening after 30 minutes and 1 second starts fresh; at exactly 30 minutes it keeps
    the conversation;
  - starting fresh drops a reply that is still in flight.

### 3e. Home and notification lines

`PlantVoicePrompt.line` for `.home` and `.notification`:

- first person, as the plant;
- never "your plant";
- never thank or reply to the person;
- at most 10 words;
- when sleeping: sound sleepy.

`.greeting` keeps its own wording, with the 12-word limit.

Tests: each rule appears for home and notification; the sleepy rule appears only when
sleeping; the greeting has no 10-word rule.

## 4. Buttons

- Water is the primary button whenever the mood is thirsty or very thirsty, in every scene,
  including night.
- New `PlantMonitorSceneViewModel.isWaterPrimary` (mood is thirsty or very thirsty). It
  replaces `scene == .thirsty` in `PlantMonitorUIComposer.makeButtons`.
- Tests:
  - `PlantMonitorSceneViewModelTests`: true for thirsty and very thirsty in day and at
    night; false for other moods.
  - `PlantMonitorUIITests`: thirsty at night shows Water as the primary button.

## 5. Checks

- Run only the affected targets: `swift test --filter PlantChatTests`,
  `--filter PlantMonitorTests`, and `--filter PlantMonitoriOSTests` if it builds on macOS
  (otherwise the human runs it).
- No simulator. No commit.
- On-device checks for the human:
  - the layout no longer jumps, including at scene changes and when the face first appears;
  - the bubble stays at most 3 lines and clear of the head;
  - generated lines follow the new rules;
  - the chat says it was just watered after watering;
  - reopening Chat after a mood change or 30 minutes starts fresh.
