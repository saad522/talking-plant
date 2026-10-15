# Roadmap

One milestone per Claude Code session. Each ends with passing tests and a short summary.

## M1 — PlantKit foundation
- Local Swift package `PlantKit` at `ios/PlantKit`.
- Contract types: UUID constants, `ReadingPacket` decoder, `DeviceInfo` decoder,
  `PlantCommand` encoder, decoded `SensorReading` model in physical units.
- Moisture calibration (`dryMv`, `wetMv`, clamped percentage).
- **Done when:** `swift test` passes, including the fixture in `BLE_CONTRACT.md`,
  wrong-length and wrong-version packets, flag handling, and calibration edge cases.

## M2 — Simulated plant + PlantMonitor slice
- `PeripheralClient` protocol and `SimulatedPeripheralClient` in PlantShared. The simulator
  builds real 16-byte packets per `BLE_CONTRACT.md`: soil dries over time, light follows a
  day curve, adjustable time scale (e.g. one simulated hour every 5 seconds); a "watered"
  action resets moisture.
- `PlantMonitor`: `PlantReadingLoader`, `PeripheralPlantReadingLoader` (replaces the
  mapper's interim error), view model, sensor card view models, formatter, strings.
- `PlantMonitoriOS`: store, views (sensor cards, loading, error), styles, `PlantMonitorUIComposer`.
- Composition root in the app target using the simulated client.
- **Done when:** loader and view model unit tests and composer integration tests pass, and
  the app runs in the simulator with live simulated data.

## M3 — History
- `PlantHistory` / `PlantHistoryiOS` slices.
- `LocalPlantReadingDecorator` stores every reading through a SwiftData-backed store client.
- Swift Charts for the last 24 hours and 7 days.
- **Done when:** history survives an app relaunch and charts update live.

## M4 — Health and mood
- Health and mood in `PlantMonitor`: a generic houseplant profile with ideal ranges,
  score 0–100, list of issues, one dominant mood (e.g. happy, thirsty, drowning, too
  dark, too hot, too cold, offline). Deterministic.
- Animated mood face as an embedded component (factory closure, ARCHITECTURE.md 5.4).
- **Done when:** health and mood are fully unit-tested and the face changes as the
  simulated plant dries out.

## D1 — v2 visual design
- Sprout character (`docs/DESIGN.md` section 5) replaces the mood face: six visual states,
  morphing between moods, idle blink and breathing (off with Reduce Motion).
- Home screen restyled to `DESIGN.md` section 4: header, scene card, speech bubble with a
  template line per mood, sensor chips, Talk and History buttons; day, thirsty and night scenes.
- Plan: `docs/plans/D1.md`.
- **Done when:** the scene and face mapping are unit-tested, the composer integration tests
  pass, and the character morphs as the simulated plant dries out and night falls.

## M5 — The plant's voice (Foundation Models)
- `PlantChat` / `PlantChatiOS` slices.
- Plan: `docs/plans/M5.md`.
- Personality picker: cheerful (default), dramatic, grumpy grandma, chill surfer, polite butler.
- Notifications written in the plant's voice when the mood changes, rate-limited.
- Chat screen; a tool lets the model fetch history summaries.
- Template fallback when the model is unavailable.
- **Done when:** works on a real iPhone, and the fallback works in the simulator.
- **Status notes:**
  - The grumpy grandma and dramatic personalities are hidden for now.
  - Chat quality guards were added: reply guard, status intent, mood check, repetition.

## M5b — Voice chat
- Part of `PlantChat` / `PlantChatiOS`. Plan: `docs/plans/M5b-voice.md`.
- Tap the mic to talk (on-device speech recognition, auto-stop on silence); voice-in
  replies are spoken back, with a "Speak replies" mute.
- Keyboard mode, microphone notices, and the template fallback still work.
- **Done when:** talking and spoken replies work on a real iPhone.

## M5c — Sprout's own voice (Kokoro)
- Plan: `docs/plans/M5c-kokoro.md` (spike: `docs/spikes/kokoro.md`).
- One on-device Kokoro voice ("sprout") in the `PlantKokoro` package, behind
  `PlantSynthesizerClient`; the Apple voice is always the fallback. Cheerful only, picker hidden.
- Kokoro runs on devices with at least 6 GB of RAM.
- **Done when:** Sprout speaks with Kokoro on a real iPhone, with the fallback working. Done (K0–K12).

## M6 — Real Bluetooth client
- `CoreBluetoothPeripheralClient` in PlantShared: scan by service UUID, connect,
  subscribe, reconnect, read, write.
- `PlantDevice` pairing and Device Info loader (uses `PlantDeviceInfoMapper`), commands
  (uses `PlantDeviceCommandMapper`).
- Device picker; simulated/real choice made in the composition root, toggled in Settings.
- Simulated readings are stamped with the simulated clock (ahead of real time), so keep
  them apart from real history, e.g. one store file per mode.
- **Done when:** builds, and the human verifies on device once the board exists.
- **Status:** implemented (plan `docs/plans/M6-bluetooth.md`, S1–S10). The on-device
  checklist (plan section 9) passed against the DEBUG test peripheral (`PlantTestPeripheral`,
  see `docs/SETUP.md`). Not yet run against the real board; see M8.

## M7 — Firmware (unchanged)
- `firmware/talking_plant/talking_plant.ino` implementing `BLE_CONTRACT.md` exactly
  (NimBLE-Arduino 2.x, BH1750, Adafruit AHTX0), Mode A, Serial logging.
- **Done when:** compiles with arduino-cli. Can be done before the parts arrive.
- **Status:** sketch (sensors, schedule, BLE service, commands, logs) compiles and the host
  tests pass (plan `docs/plans/M7-firmware.md`, S1–S5). Not yet run on a board; see M8.

## M8 — Hardware bring-up (when parts arrive)
- `PlantDeviceiOS` calibration screen + `LocalMoistureCalibrationLoader` (via
  `DefaultsClient`); replace placeholder calibration defaults.
- End-to-end: real board → app → mood → voice.
- **Status:** Part A done (plan `docs/plans/M8-bringup.md`, S1–S9): calibration screen and
  loader, raw-reading section, test peripheral soil override, firmware I2C scan, and
  `docs/BRINGUP.md`. Waiting for the board: bring-up day, then S10 applies the measured
  values and closes the open M6/M7 decisions.

## M9 — Leaf check-up
- `PlantCheckup` / `PlantCheckupiOS` slices.
- Take a photo of the plant in the app.
- Vision separates the plant from the background; deterministic color analysis measures
  green, yellow, and brown ratios and dark spots, tracked over time.
- Diagnosis rules combine the photo result with sensor history:
  - yellow leaves + soil wet for days → overwatering
  - brown crispy tips + dry soil or low humidity → underwatering or dry air
  - pale growth + low light all week → too dark
  - burnt patches + very high light → too much sun
  - dead brown leaves → time to prune
- Foundation Models only phrases the result in the plant's voice. Wording is always
  "this might be…" with a suggestion, never a definite diagnosis.
- Later (not part of M9): a Create ML image classifier trained on our own labeled photos,
  and an optional camera on the pot (XIAO ESP32S3 Sense).
- **Done when:** the diagnosis rules are fully unit-tested, the photo-to-result flow works
  on a real iPhone, and past check-ups are saved.

## Later
Low-power Mode B, V2 parts (pump, display, battery sense), species identification with
the camera, widgets, multiple plants, enclosure.

## P1 — Sprout feels alive
- Plan: `docs/plans/P1-alive.md` (steps S1–S9). S1: intro lengthened to 2.2 s.
