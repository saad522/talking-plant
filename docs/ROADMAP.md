# Roadmap

One milestone per Claude Code session. Each ends with passing tests and a short summary.

## M1 — PlantKit foundation
- Local Swift package `PlantKit` at `ios/PlantKit`.
- Contract types: UUID constants, `ReadingPacket` decoder, `DeviceInfo` decoder,
  `PlantCommand` encoder, decoded `SensorReading` model in physical units.
- Moisture calibration (`dryMv`, `wetMv`, clamped percentage).
- **Done when:** `swift test` passes, including the fixture in `BLE_CONTRACT.md`,
  wrong-length and wrong-version packets, flag handling, and calibration edge cases.

## M2 — Mock sensor + live dashboard
- `SensorSource` protocol (stream of raw packets, start/stop, send command).
- `MockSensorSource`: builds real 16-byte packets; soil dries over time, light follows a
  day curve, adjustable time scale (e.g. one simulated hour every 5 seconds); a
  "watered" action resets moisture.
- App dashboard showing live moisture %, light, temperature, humidity.
- **Done when:** the app runs in the simulator with live mock data.

## M3 — History
- SwiftData `ReadingRecord`; every decoded reading is stored.
- Swift Charts for the last 24 hours and 7 days.
- **Done when:** history survives an app relaunch and charts update live.

## M4 — Health engine + mood face
- `PlantProfile` with ideal ranges (start with one generic houseplant profile).
- `HealthEngine` in PlantKit: score 0–100, list of issues, one dominant mood
  (e.g. happy, thirsty, drowning, too dark, too hot, too cold, offline). Deterministic.
- Animated mood face in the app.
- **Done when:** engine is fully unit-tested and the face changes as the mock dries out.

## M5 — The plant's voice (Foundation Models)
- Personality picker: dramatic, grumpy grandma, chill surfer, polite butler.
- Notifications written in the plant's voice when the mood changes, rate-limited.
- Chat screen; a tool lets the model fetch history summaries.
- Template fallback when the model is unavailable.
- **Done when:** works on a real iPhone, and the fallback works in the simulator.

## M6 — Real Bluetooth source
- `BLESensorSource` with CoreBluetooth: scan by service UUID, connect, subscribe,
  reconnect, read Device Info, send commands.
- Device picker; mock/real toggle in Settings.
- **Done when:** builds, and the human verifies on device once the board exists.

## M7 — Firmware
- `firmware/talking_plant/talking_plant.ino` implementing `BLE_CONTRACT.md` exactly
  (NimBLE-Arduino 2.x, BH1750, Adafruit AHTX0), Mode A, Serial logging.
- **Done when:** compiles with arduino-cli. Can be done before the parts arrive.

## M8 — Hardware bring-up (when parts arrive)
- Calibration screen in the app; replace placeholder calibration defaults.
- End-to-end: real board → app → mood → voice.

## Later
Low-power Mode B, V2 parts (pump, display, battery sense), plant ID with the camera,
voice chat, widgets, multiple plants, enclosure.
