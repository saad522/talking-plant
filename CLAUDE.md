# Talking Plant

A plant monitor with a personality. A small ESP32 board reads soil moisture, light,
temperature, and humidity, and sends readings over Bluetooth LE to an iOS app. The app
stores history, computes the plant's health and mood with deterministic rules, and uses
Apple's on-device Foundation Models framework to give the plant a voice.

## Current phase

Parts are still shipping. Build the software first against a **mock sensor** that speaks
the exact same BLE packet format as the real board. Work milestone by milestone from
`docs/ROADMAP.md`. Only work on the milestone you were asked for.

## Docs (read before starting any milestone)

- `docs/BLE_CONTRACT.md` — the single source of truth for the board ↔ app protocol.
  Never change it silently. If a change is needed, propose it first, then update the
  doc, the Swift decoder, the firmware, and the tests in the same change.
- `docs/ROADMAP.md` — milestones and their acceptance criteria.
- `docs/SETUP.md` — tools and manual setup steps (for the human).

## Repo layout

```
talking-plant/
├── CLAUDE.md
├── docs/
├── firmware/talking_plant/talking_plant.ino   # Arduino sketch (XIAO ESP32-C3)
└── ios/
    ├── TalkingPlant/                           # created manually in Xcode
    │   ├── TalkingPlant.xcodeproj
    │   ├── TalkingPlant/                       # app target sources
    │   │   ├── App/                            # app entry, dependency setup
    │   │   ├── Bluetooth/                      # CoreBluetooth SensorSource
    │   │   ├── Persistence/                    # SwiftData models
    │   │   ├── Brain/                          # Foundation Models: voice, chat, tools
    │   │   └── Features/                       # Dashboard, History, Chat, Settings
    │   ├── TalkingPlantTests/
    │   └── TalkingPlantUITests/
    └── PlantKit/                               # local Swift package, pure logic
        ├── Package.swift
        ├── Sources/PlantKit/
        │   ├── Contract/                       # UUIDs, packet decode, command encode
        │   ├── Calibration/                    # soil mV -> moisture %
        │   ├── Health/                         # profiles, HealthEngine, Mood
        │   └── Sensor/                         # SensorSource protocol, MockSensorSource
        └── Tests/PlantKitTests/
```

## Architecture rules

- **PlantKit holds all pure logic** (contract, calibration, health engine, mock source)
  and has no UI, no SwiftData, no CoreBluetooth. It must build and test on macOS with
  `swift test`.
- **One data path.** Both `MockSensorSource` and `BLESensorSource` produce raw 16-byte
  packets that go through the same decoder. The mock must not bypass the decoder.
- **The AI never does the math.** Health score, mood, and alerts come from
  `HealthEngine` (deterministic, unit-tested). Foundation Models only turns an
  already-computed state into words.
- **Always have a fallback.** Check `SystemLanguageModel.default.availability`; when the
  model is unavailable, use template messages so the app still works.
- Swift 6 language mode, strict concurrency, SwiftUI, `@Observable`, async/await.
  iOS 26 deployment target (required by Foundation Models).
- Timestamps come from the phone when a packet is received. The board has no clock.

## Working rules

- Stay strictly inside the requested milestone's acceptance criteria.
- Prefer minimal diffs. Don't refactor or restyle code you weren't asked to touch.
- Avoid over-engineering: no extra abstraction layers, frameworks, or dependencies
  without asking first. No third-party Swift packages unless approved.
- Before writing code for a milestone, give a short plan and wait for approval.
- Add or update unit tests for every PlantKit change.
- Commit messages and summaries: short and plain.

## Commands

```bash
# PlantKit tests (fast, no simulator needed)
cd ios/PlantKit && swift test

# App build (list simulators with: xcrun simctl list devices available)
cd ios/TalkingPlant && xcodebuild -project TalkingPlant.xcodeproj -scheme TalkingPlant \
  -destination 'platform=iOS Simulator,name=<available iPhone simulator>' build

# Firmware compile (see docs/SETUP.md for arduino-cli setup)
arduino-cli compile --fqbn esp32:esp32:XIAO_ESP32C3 firmware/talking_plant
```

Foundation Models and Bluetooth must be tested on a real iPhone; the simulator has no
Bluetooth. Ask the human to run on-device checks.
