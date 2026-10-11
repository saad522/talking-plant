# Talking Plant

A plant monitor with a personality. A small ESP32 board reads soil moisture, light,
temperature, and humidity, and sends readings over Bluetooth LE to an iOS app. The app
stores history, computes the plant's health and mood with deterministic rules, and uses
Apple's on-device Foundation Models framework to give the plant a voice.

## Current phase

Parts are still shipping. Build the software first against a **simulated plant**
(`SimulatedPeripheralClient`) that speaks the exact same BLE packet format as the real board. Work milestone by milestone from
`docs/ROADMAP.md`. Only work on the milestone you were asked for.

## Docs (read before starting any milestone)

- `docs/ARCHITECTURE.md` — the source of truth for code structure, naming, and testing.
  When it conflicts with anything else in the repo, it wins.
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
    │   └── TalkingPlant/
    │       └── TalkingPlantApp.swift           # composition root: clients, loaders, composers, actions
    └── PlantKit/                               # local Swift package, one slice per feature
        ├── Package.swift
        ├── Sources/
        │   ├── PlantShared/                    # used by more than one feature
        │   │   ├── Contract/                   # PlantBluetoothContract, PlantCharacteristic
        │   │   ├── Client/                     # PeripheralClient + implementations, PlantReadingStore
        │   │   ├── Domain/                     # MoistureCalibration, PlantReading
        │   │   └── Presentation/               # PlantReadingFormatter
        │   ├── PlantMonitor/                   # Feature: live readings, health, mood
        │   │   ├── Domain/                     # PlantReadingLoader, PlantMonitorAction
        │   │   ├── API/                        # PeripheralPlantReadingLoader, PlantReadingMapper
        │   │   ├── Persistence/                # LocalPlantReadingDecorator
        │   │   ├── Presentation/
        │   │   └── Resources/en.lproj/PlantMonitor.strings
        │   ├── PlantMonitoriOS/                # UI: Stores, Views, Composers, Styles
        │   ├── PlantDevice/                    # Feature: device info, commands, calibration, pairing
        │   │   ├── Domain/                     # PlantDeviceInfo, PlantDeviceCommand
        │   │   └── API/                        # PlantDeviceInfoMapper, PlantDeviceCommandMapper
        │   ├── PlantHistory/                   # Feature: stored readings, downsampling
        │   └── PlantHistoryiOS/                # UI: Swift Charts
        └── Tests/
            ├── PlantSharedTests/
            ├── PlantMonitorTests/              # unit tests, macOS
            ├── PlantMonitoriOSTests/           # integration tests from the UIComposer
            ├── PlantDeviceTests/
            ├── PlantHistoryTests/
            └── PlantHistoryiOSTests/
```

Later features follow the same pattern (`PlantChat` / `PlantChatiOS`, `PlantDeviceiOS`). Folders appear when their first file does.

## Architecture rules

Follow `docs/ARCHITECTURE.md`. The short version:

- **Vertical slices.** Each feature is a business target (`PlantX`: Foundation +
  `PlantShared` only, no SwiftUI) and a UI target (`PlantXiOS`). A feature never imports
  another feature. Code moves into `PlantShared` only when a second feature needs it.
- **One data path.** The real sensor and the simulated plant are both
  `PeripheralClient`s producing raw 16-byte packets: client → loader → mapper → view
  model. The simulated plant must not bypass the mapper.
- **The app target is the composition root.** Only it knows concrete types and handles
  feature actions.
- **The AI never does the math.** Health score, mood, and alerts are deterministic,
  unit-tested business logic. Foundation Models only turns an already-computed state
  into words.
- **Always have a fallback.** Check `SystemLanguageModel.default.availability`; when the
  model is unavailable, use template messages so the app still works.
- Swift 6 language mode, strict concurrency, `@MainActor` instead of dispatch
  decorators (ARCHITECTURE.md section 3). iOS 26 deployment target (required by
  Foundation Models). PlantKit must keep building and testing on macOS with `swift test`.
- Timestamps come from the phone when a packet is received. The board has no clock.

## Testing

- All tests use **XCTest**, following ARCHITECTURE.md section 7 (naming, base class per
  test target, `makeSUT`, spies, memory-leak tracking).
- **ViewInspector** is allowed in the `PlantXiOSTests` targets only. It is the only
  approved third-party package.
- `PlantXTests` are unit tests and run on macOS. `PlantXiOSTests` are integration tests
  starting from the UIComposer.

## Working rules

- Stay strictly inside the requested milestone's acceptance criteria.
- Prefer minimal diffs. Don't refactor or restyle code you weren't asked to touch.
- Avoid over-engineering: no extra abstraction layers, frameworks, or dependencies
  without asking first. No third-party Swift packages unless approved (ViewInspector is
  approved for iOS test targets).
- Before writing code for a milestone, give a short plan and wait for approval.
- Add or update unit tests for every PlantKit change.
- Commit messages and summaries: short and plain.
- Never commit or push. Leave all changes uncommitted so I can review them in Xcode,
  then I commit myself.

## Commands

```bash
# PlantKit tests (fast, no simulator needed)
cd ios/PlantKit && swift test

# PlantKit tests on the iOS simulator (all package test targets)
cd ios/PlantKit && xcodebuild test -scheme PlantKit-Package \
  -destination 'platform=iOS Simulator,name=<available iPhone simulator>'

# App build (list simulators with: xcrun simctl list devices available)
cd ios/TalkingPlant && xcodebuild -project TalkingPlant.xcodeproj -scheme TalkingPlant \
  -destination 'platform=iOS Simulator,name=<available iPhone simulator>' build

# Firmware compile (see docs/SETUP.md for arduino-cli setup)
arduino-cli compile --fqbn esp32:esp32:XIAO_ESP32C3 firmware/talking_plant
```

Foundation Models and Bluetooth must be tested on a real iPhone; the simulator has no
Bluetooth. Ask the human to run on-device checks.
