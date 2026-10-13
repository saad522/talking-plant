# M8 plan: hardware bring-up and soil calibration

Scope (ROADMAP M8):

- `PlantDeviceiOS` calibration screen + `LocalMoistureCalibrationLoader` (via `DefaultsClient`).
  Two-point calibration (dry in air, wet in water), validation, reset to defaults, applied
  in the moisture mapping. New default values with a stated source.
- Test peripheral: a soil millivolts override, so the calibration flow runs before the parts
  arrive.
- DEBUG raw-values section in Settings (soil mV, lux, temperature, humidity, flags,
  sequence), for comparing the app with the serial log on bring-up day.
- `docs/BRINGUP.md`: a step-by-step guide for bring-up day.
- After bring-up day: close the open M7/M6 decisions (soil-failure threshold, interval 300 s,
  firmware 1.0.0, default mode = real sensor, measured calibration defaults).
- End to end: real board → app → mood → voice.

Two parts:

- **Part A** (S1–S9) can be built now, against the simulated plant and the 13 Pro test
  peripheral.
- **Part B** is the bring-up day itself, written as `docs/BRINGUP.md` (S9). Section 9 below
  is its outline. S10 applies the decisions measured on that day.

**Done when:** `swift test` passes for every touched target, `make -C firmware test` and
`make -C firmware compile` pass, the S7 on-device checklist (section 7) passes against the
test peripheral, the human completes `docs/BRINGUP.md` on the real board, and S10 is applied.

Out of scope: Mode B, battery sensing, pump, display, recomputing stored history after a
recalibration, a "not calibrated" hint on the home screen (not in M8, decision 3), per-pot or
per-soil calibration profiles, any change to the BLE packet format.

---

## 1. What exists today

| Piece | State |
|---|---|
| `MoistureCalibration` (PlantShared/Domain) | `placeholder` = dry 2400 / wet 1100, `isCalibrated: false`. Failable init rejects `dry <= wet`. Clamped linear formula from `BLE_CONTRACT.md`. |
| Moisture mapping | `PlantReadingMapper` (PlantMonitor) applies the calibration while decoding. `PeripheralPlantReadingLoader` takes `calibration: () -> MoistureCalibration`, read per packet. |
| App | `AppGraph` passes `{ .placeholder }` in both modes. Nothing shows "not calibrated". |
| History | Stores `PlantReading` with moisture **%**, not soil mV. A new calibration only affects new readings. |
| Raw values | Nowhere after the mapper. `PlantReading` has no soil mV. |
| `DefaultsClient` | Double / String / Bool, no remove. `PlantDeviceSettings` clears by writing empty values. |
| `SimulatedPeripheralClient` | Soil 1100–2600 mV, built around the 2400/1100 placeholder. Writes fail (`unsupportedCharacteristic`), so READ_NOW doesn't exist in simulated mode. |
| Test peripheral (DEBUG) | Packets from its own `SimulatedPeripheralClient`, READ_NOW / SET_INTERVAL handled by the pure `PlantTestPeripheralResponder`. Screen: status, interval, log, Water. |
| Firmware | Soil on A0, 8-sample average, `analogReadMilliVolts`, 11 dB. Soil always valid (`kSoilFailureCheckEnabled = false`). fw 0.1.0, default interval 30 s. Boot order of logs: `[i2c]`, `[read] #0`, `[boot]`. |

---

## 2. Calibration defaults: new values and where they come from

Proposed (a change to the app-side part of `BLE_CONTRACT.md`, not to the packet format):

| | Old placeholder | New default | Source |
|---|---|---|---|
| `dryMv` | 2400 | **2450** | Common "Capacitive Soil Moisture Sensor v1.2" manuals give about 2.5 V in open air. The ESP32-C3 ADC at 12 dB (`ADC_11db` in our core) is rated for 0–2500 mV only (ESP-IDF ESP32-C3 ADC docs), so 2.5 V is right at the ceiling. 2450 keeps the dry point inside the rated range. |
| `wetMv` | 1100 | **1050** | The same manuals give about 1.0 V fully submerged. Other ESP32 guides report about 1.2 V in saturated soil. Water up to the line is the wettest case, so we take the low end, plus a small margin. |

Notes:

- At 3.3 V supply the board's 662K 3.3 V regulator is in dropout, so the 555 runs a little
  under 3.3 V. That lowers both points slightly. This is why we don't take the 5 V
  Arduino figures (≈ 2.5–2.9 V air).
- No manufacturer datasheet confirms these figures. They are typical values only. S10
  replaces them with the values measured on our own sensor (average of three captures
  each), so a reinstall starts close to the truth.
- Defaults keep `isCalibrated = false`. The UI shows "Not calibrated" until the user saves
  their own two points.
- **The simulated plant keeps 2400/1100.** Its soil curve (1100 → 2600 mV) was designed
  for those values. Moving it to the new defaults would change every simulated mood.
  New constant `SimulatedPeripheralClient.calibration` (2400/1100), used by the app in
  simulated mode. It still goes through the mapper, only the calibration value differs.

---

## 3. Design overview

```
PlantShared/Contract
  PlantReadingPacket            (new, promoted)  16-byte decode, no units, no calibration
PlantShared/Domain
  MoistureCalibration           (new default values)
PlantShared/Client
  SimulatedPeripheralClient     (+ static calibration 2400/1100)

PlantMonitor/API
  PlantReadingMapper            (uses PlantReadingPacket; behaviour unchanged)

PlantDevice
  Domain        PlantDeviceRawReading, PlantDeviceRawReadingLoader,
                PlantDeviceCalibrationPoint, PlantDeviceCalibrationValidator,
                PlantDeviceAction (+ .calibrationTap)
  API           PeripheralPlantDeviceRawReadingLoader, PlantDeviceRawReadingMapper
  Persistence   LocalMoistureCalibrationLoader
  Presentation  PlantDeviceCalibrationViewModel, PlantDeviceRawReadingViewModel,
                PlantDeviceViewModel (+ calibration row, + raw reading)
PlantDeviceiOS  calibration store/view, composer, Settings rows
PlantTestPeripheral  soil override in the responder
App             route .calibration, calibration closure per mode, DEBUG raw flag
```

### 3.1 Why `PlantReadingPacket` moves to PlantShared

The calibration screen and the raw-values section need **soil millivolts**, which only
exist before the mapper. `PlantReading` stores moisture %, and adding soil mV to it would
change the SwiftData history schema. So PlantDevice decodes the Readings packet itself.

That makes PlantDevice the second feature that decodes Readings packets. Per
ARCHITECTURE.md 1.5 the decoding is promoted, not copied: the private `RemoteReading`
struct of `PlantReadingMapper` becomes a public `PlantReadingPacket` in
`PlantShared/Contract`, with the raw fields (`version`, `flags`, `soilMillivolts`, `lux`,
`temperatureCenti`, `humidityCenti`, `batteryMillivolts`, `sequence`) and `init?(data:)`
(length check only). Each mapper keeps its own rules: version check, units, calibration.

`PlantReadingMapperTests` don't change. They are the regression net for the move.

### 3.2 One data path still holds

The raw loader is `client → PeripheralPlantDeviceRawReadingLoader → PlantDeviceRawReadingMapper
→ view model`, on the same client as the monitor. Both `PeripheralClient` implementations
already keep a list of Readings subscribers, so a second subscriber is fine.
`subscribe` has no unsubscribe, so each view model subscribes once per graph (guarded
`appear()`, graph rebuilt on mode change).

### 3.3 Calibration applies live

The app passes `calibration: { calibrationLoader.load() }` in sensor mode. The closure is
read per packet, so a saved calibration applies from the next reading with no graph
rebuild. After Save, the calibration view model sends `READ_NOW` so the home screen
updates right away (failure ignored).

---

## 4. PlantDevice (business)

### 4.1 Domain

| Type | Content |
|---|---|
| `PlantDeviceRawReading` | `soilMillivolts: Int?`, `lux: Int?`, `temperature: Double?`, `humidity: Double?`, `flags: UInt8`, `sequence: UInt32`, `receivedAt: Date`. Fields `nil` when the flag bit is clear. |
| `PlantDeviceRawReadingLoader` | `load(completion:)`, `subscribe(update:)`, `Result = Swift.Result<PlantDeviceRawReading, Error>` |
| `PlantDeviceCalibrationPoint` | `.dry`, `.wet` |
| `PlantDeviceCalibrationValidator` | Pure. `validate(dry: Int?, wet: Int?) -> Result<MoistureCalibration, PlantDeviceCalibrationError>`. `isNearADCLimit(dry:) -> Bool`. |
| `PlantDeviceCalibrationError` | `.missingDry`, `.missingWet`, `.wetNotBelowDry`, `.rangeTooSmall` |
| `PlantDeviceAction` | `+ .calibrationTap` |

Validation rules:

1. Both points captured in this session (no mixing one capture with a default).
2. `wet < dry`.
3. `dry - wet >= 300 mV` (`minimumRangeMillivolts`). The expected span is about 1,200–1,500
   mV. Under 300 mV one of the two steps went wrong (sensor not in air, not in water, or a
   saturated / dead sensor). 300 mV also keeps at least 3 mV per percent, so ±15 mV of
   noise stays within about ±5 %.
4. Warning only, not blocking: `dry >= 2480 mV` → "near the top of the board's range"
   (M7 check 12: the sensor may be saturating; check it's on 3V3, not 5V).

### 4.2 API

- **`PeripheralPlantDeviceRawReadingLoader(client:currentDate:)`** — `load` reads
  `.readings`, `subscribe` subscribes to `.readings`; both → `PlantDeviceRawReadingMapper`.
  Errors `.connectivity`, `.invalidData` (wrong length or version ≠ 1).
- **`PlantDeviceRawReadingMapper`** — `PlantReadingPacket` → `PlantDeviceRawReading`
  (temperature / humidity ÷ 100, flags kept as-is for the debug row).

### 4.3 Persistence

**`LocalMoistureCalibrationLoader(defaults: DefaultsClient)`**, synchronous like
`PlantDeviceSettings`:

- `load() -> MoistureCalibration` — reads `plant.device.calibration.dryMillivolts` and
  `plant.device.calibration.wetMillivolts` (Double). A missing or invalid pair
  (`MoistureCalibration(dry:wet:)` returns `nil`) → `.placeholder` (the new defaults).
- `save(_ calibration: MoistureCalibration)` — writes both.
- `reset()` — writes 0 / 0, which `load()` treats as nothing saved (no `remove(forKey:)`
  needed, same as M6 decision 9).

Validation is not repeated here. `save` takes a `MoistureCalibration`, which can only exist
with `dry > wet`.

### 4.4 Presentation

**`PlantDeviceCalibrationViewModel`** (calibration screen). Dependencies:
`calibrationLoader`, `rawReadingLoader`, `connectionLoader`, `commandSender`,
`schedule` (one-shot, like `PeripheralPlantDeviceConnectionLoader`), `captureTimeout = 10`.

- `appear()` (guarded): emits the saved calibration, subscribes to connection and raw
  readings. Live soil row: latest soil mV, or "–" when the soil flag is clear.
- `captureTap(_ point:)`:
  1. remembers the last seen sequence, emits `loadedCapturing(point)`;
  2. sends `READ_NOW`; a write error → message "Couldn't reach the sensor.", capture ends;
  3. the first raw reading delivered after the tap with a different sequence is the
     capture. Soil flag clear → message "The soil sensor isn't reading." Otherwise the
     draft for that point is set and shown;
  4. no reading within 10 s → message "No reading from the sensor. Try again."
     A late reading after the timeout is ignored (generation counter).
  A capture always reads a fresh value, because with a 300 s interval the live row can be
  minutes old. Capturing the same point again replaces the draft: "capture again until two
  captures agree within about 20 mV" is the stability check.
- `saveTap()`: validator → `calibrationLoader.save`, emit the new status, clear drafts,
  send `READ_NOW` (result ignored). Validation error → message.
- `resetTap()`: `calibrationLoader.reset()`, emit status, clear drafts. No confirmation
  (same as Forget, M6 decision 10).
- Capture buttons enabled only while `.connected`. Save enabled only when both drafts exist.
- Observers: `loadedStatus(PlantDeviceCalibrationStatusViewModel)` (status label,
  dry text, wet text, `isCalibrated`), `loadedLiveSoil(String)`,
  `loadedDraft(PlantDeviceCalibrationPoint, String?)`, `loadedCapturing(PlantDeviceCalibrationPoint?)`,
  `loadedCanCapture(Bool)`, `loadedCanSave(Bool)`, `loadedMessage(String?)`,
  `loadedWarning(String?)`.

**`PlantDeviceViewModel`** (Settings) gets:

- `calibrationLoader` → `loadedCalibrationStatus(String)` ("Calibrated" / "Not calibrated").
  Emitted on **every** `appear()` (subscriptions stay guarded), so the row is right after
  coming back from the calibration screen.
- `calibrationTap()` → `.calibrationTap`.
- `rawReadingLoader` → `loadedRawReading(PlantDeviceRawReadingViewModel)`: loaded on each
  transition into `.connected` (like Device Info) and on every notify.

**`PlantDeviceRawReadingViewModel`**: soil `"2,431 mV"`, light `"312 lx"`, temperature
`"23.41 °C"`, humidity `"48.20 %"`, flags `"0x07"`, sequence `"#42"`, received `"14:03:15"`.
Two decimals on purpose: the debug row must match the serial log digit for digit.
`"–"` for a field whose flag is clear. Fixed `en_US` locale, like `PlantReadingFormatter`.

Strings: `plant.device.calibration.*`, `plant.device.raw.*` in `PlantDevice.strings`.

---

## 5. UI (PlantDeviceiOS)

**Settings (`PlantDeviceView`)**, sensor mode only:

- Section *Sensor*: new row *Moisture calibration* → "Calibrated" / "Not calibrated", as a
  button → `calibrationTap`. Shown even when not connected (the values are useful offline).
- Section *Raw reading* (only when the composer's `showsRawReading` is `true`; the app passes
  `true` in DEBUG): soil, light, temperature, humidity, flags, sequence, received.

**Calibration (`PlantDeviceCalibrationView`)**, plain `Form` like Settings (M6 decision 5):

```
Moisture calibration
  Status            Not calibrated
  Dry               2,450 mV
  Wet               1,050 mV
Sensor now
  Soil              2,431 mV
1 · Dry
  [Capture dry]     2,447 mV        (ProgressView while capturing)
  footer: Wipe the sensor dry and hold it in the air by its top edge.
2 · Wet
  [Capture wet]     1,062 mV
  footer: Stand it in a glass of water up to the line. Keep the top dry.
  warning / error text
[Save calibration]
[Reset to defaults]                 (destructive, only when calibrated)
footer when not connected: Connect the sensor to calibrate.
```

Composer: `PlantDeviceUIComposer.composedCalibration(calibrationLoader:rawReadingLoader:connectionLoader:commandSender:schedule:)`.
No UIKit, no iOS-only styles (keeps `swift test` on macOS).

---

## 6. Test peripheral: soil override

- `PlantTestPeripheralResponder` gets `soilOverride: UInt16?` and a pure
  `func readings(_ packet: Data) -> Data`: with an override, bytes 2–3 become the override
  (little-endian) and flag bit0 is set; without one, the packet is unchanged.
  `CoreBluetoothPlantTestPeripheral.publish` and the Readings read go through it.
- An override replaces the soil value completely, so the simulated drying (+18 mV per test
  tick) doesn't move a captured value.
- `CoreBluetoothPlantTestPeripheral`: `@Published soilOverride`, `setSoilOverride(_:)`,
  logs "soil override 2450 mV" / "soil override off".
- `TestPeripheralView` (app, DEBUG): a section *Soil*: toggle *Override*, slider 0–3000 mV
  (step 10) with the value, buttons *Air 2450* and *Water 1050*.
- `SimulatedPeripheralClient` is not touched.

---

## 7. Steps (one session each)

Every step: run only the affected targets (`swift test --filter <Target>`), leave changes
uncommitted, short summary. When a composer or init signature changes, the same step
updates `AppGraph.swift` so the app keeps building (the human builds in Xcode). "On
device" lists what the human checks.

### S1 — Shared packet and new defaults (PlantShared, PlantMonitor)

- Files: `PlantShared/Contract/PlantReadingPacket.swift` (new),
  `PlantMonitor/API/PlantReadingMapper.swift` (uses it, behaviour unchanged),
  `PlantShared/Domain/MoistureCalibration.swift` (2450/1050, doc comment with the source),
  `SimulatedPeripheralClient.swift` (`static let calibration`), `AppGraph.swift`
  (simulated mode uses `SimulatedPeripheralClient.calibration`, sensor mode keeps
  `.placeholder` until S7), `docs/BLE_CONTRACT.md` (calibration section: new defaults,
  their source, simulated plant note).
- Tests: `PlantReadingPacketTests` (contract fixture fields, wrong length → nil, `E6 FB`
  = −1050 centi, sequence `04 03 02 01`, flags kept raw); `MoistureCalibrationTests`
  updated for 2450/1050 (endpoints, midpoint 1750 → 50 %, clamps); `SimulatedPeripheralClientTests`:
  calibration is 2400/1100. `PlantReadingMapperTests` and `PeripheralPlantReadingLoaderTests`
  pass unchanged.
- Run: `--filter PlantSharedTests`, `--filter PlantMonitorTests`.
- On device: simulated mode looks exactly as before (same moisture for the same saved soil).

### S2 — Calibration persistence and validation (PlantDevice)

- Files: `PlantDevice/Persistence/LocalMoistureCalibrationLoader.swift`,
  `PlantDevice/Domain/PlantDeviceCalibrationPoint.swift`, `PlantDeviceCalibrationValidator.swift`
  (with `PlantDeviceCalibrationError`). `DefaultsSpy` in `PlantDeviceXCTestCase` stores Doubles.
- Tests: loader — nothing saved → placeholder; save/load round trip; invalid saved pair
  (dry ≤ wet, zeros) → placeholder; reset → placeholder; keys. Validator — missing dry,
  missing wet, wet = dry, wet > dry, range 299 → error, 300 → ok, warning at 2479 / 2480.
- On device: none.

### S3 — Raw reading loader (PlantDevice)

- Files: `PlantDevice/Domain/PlantDeviceRawReading.swift`, `PlantDeviceRawReadingLoader.swift`,
  `PlantDevice/API/PeripheralPlantDeviceRawReadingLoader.swift`, `PlantDeviceRawReadingMapper.swift`.
- Tests: init sends nothing; `load` reads `.readings`; `subscribe` subscribes once; contract
  fixture → soil 2500, lux 1000, 23.50 °C, 55.20 %, flags 0x07, sequence 42, `receivedAt`
  from `currentDate`; flags 0x00 → all fields nil; wrong length / version 2 → `.invalidData`;
  client error → `.connectivity`; no leak.
- On device: none.

### S4 — Calibration and raw view models (PlantDevice/Presentation)

- Files: `PlantDeviceCalibrationViewModel.swift`, `PlantDeviceCalibrationStatusViewModel.swift`,
  `PlantDeviceRawReadingViewModel.swift`, `PlantDeviceViewModel.swift` (calibration status,
  `calibrationTap`, raw reading), `PlantDeviceAction` (`.calibrationTap`), strings.
- Tests (with `ScheduleSpy`, `ClientSpy`, `ConnectionClientSpy`):
  - calibration: `appear` emits saved status and subscribes once; capture sends `READ_NOW`
    and takes the next reading with a new sequence (same sequence ignored); soil flag
    clear → message; write error → message; timeout → message, late reading ignored;
    recapture replaces the draft; capture disabled when not connected; save writes,
    clears drafts, sends `READ_NOW`; each validation error → its message; warning at 2480;
    reset; no leak.
  - Settings: status emitted on every `appear`, subscriptions once; `calibrationTap` action;
    raw reading on `.connected` and on notify.
  - raw formatting: each field, nil fields → "–", flags hex, two decimals.
  - strings table has every new key.
- On device: none.

### S5 — Calibration screen and Settings rows (PlantDeviceiOS)

- Files: `PlantDeviceCalibrationStore.swift`, `PlantDeviceCalibrationView.swift`,
  `PlantDeviceStore` / `PlantDeviceView` (calibration row, raw section),
  `PlantDeviceUIComposer` (`composedCalibration`, `showsRawReading` on `composed`),
  `AppGraph.swift` (new arguments only; route in S7).
- Tests (`PlantDeviceiOSTests`, ViewInspector, from the composer): calibration row text and
  tap action; raw section hidden by default, shown with the flag and filled on a reading;
  calibration screen shows status and defaults, capture buttons disabled when offline,
  capture → spinner → value, Save disabled until both captured, error text, Reset only when
  calibrated.
- On device: none yet (S7).

### S6 — Test peripheral soil override

- Files: `PlantTestPeripheralResponder.swift`, `CoreBluetoothPlantTestPeripheral.swift`,
  app `TestPeripheralView.swift`.
- Tests (`PlantTestPeripheralTests`): no override → same bytes; override 2450 → bytes 2–3
  `92 09`, other bytes unchanged; override sets bit0 when it was clear; override 0 →
  `00 00` with bit0 set; clearing the override restores the original.
- On device (13 Pro with `-PlantTestPeripheral`, nRF Connect on the 17 Pro): override Air →
  Readings read shows `… 92 09 …`; Water → `1A 04`; toggle off → simulated value again.

### S7 — Composition root and on-device checks

- Files: `AppGraph.swift` (sensor mode: `LocalMoistureCalibrationLoader`, `calibration:
  { calibrationLoader.load() }`, `composedCalibration`, `showsRawReading` in DEBUG),
  `TalkingPlantApp.swift` (`Route.calibration`, `.calibrationTap` → push).
- Decision 11.5, DEBUG "Clear sensor history": `PlantReadingStore.deleteAll` (SwiftData store,
  notifies subscribers, unit tests); button with a confirmation alert in the Settings raw
  section (sensor mode, DEBUG); `PlantDeviceAction.clearSensorHistory`, handled in
  `AppGraphStore` by clearing only the sensor store (`PlantHistory-Sensor.store`).
- On device (17 Pro app in sensor mode, 13 Pro test peripheral, optional
  `-PlantReadingInterval 30`):
  1. Settings shows *Moisture calibration · Not calibrated*. The raw section fills; sequence
     goes up each interval; values match the test peripheral.
  2. Calibration screen shows Not calibrated, 2,450 / 1,050 mV.
  3. Test peripheral Air → *Capture dry*: the peripheral logs `READ_NOW`, dry shows 2,450 mV
     and the near-limit warning does **not** show. Slider 2,490 → capture again → warning shows.
  4. Water → *Capture wet* → 1,050 mV. *Save* → Calibrated; home moisture updates within
     a second (soil 1,050 → 100 %).
  5. Slider 1,750 → *Read now* in Settings → home shows 50 %.
  6. Dry 1,500 / wet 1,400 → "too close" message, not saved. Wet above dry → its message.
  7. Kill and relaunch → still Calibrated with the saved values. *Reset to defaults* → Not
     calibrated, 2,450 / 1,050.
  8. Bluetooth off on the 13 Pro → capture buttons disabled. Turn it off during a capture →
     "No reading from the sensor" after 10 s.
  9. Switch to Simulated → calibration row hidden, simulated moisture unchanged from before
     M8. Switch back → calibration kept.
  10. *Clear sensor history* → confirm → home and History empty out for the sensor; switch
      to Simulated → its history is unchanged.
  11. Test peripheral: Bluetooth off and on on the 13 Pro → status follows (off, then
      Advertising again), nRF Connect sees it again, no relaunch needed.
  12. No crash and no `Incorrect actor executor` / `dispatch_assert_queue` in the console.

### S8 — Firmware: full I2C scan in the boot log (yes, decision 1)

- Files: `firmware/talking_plant/talking_plant.ino` (after the existing `[i2c]` line, scan
  0x08–0x77 and log `[i2c] found: 0x23 0x38`, or `[i2c] found: none`),
  `docs/plans/M7-firmware.md` section 7 (log example).
- Why: modules bought locally may differ. A BH1750 with ADDR high answers at 0x5C, an
  AHT20+BMP280 combo adds 0x77. Today the log only says "missing", which can't tell a wiring
  fault from a different address.
- Verify: `make -C firmware test`, `make -C firmware compile`.
- On device: in BRINGUP.md.

### S9 — Docs

- `docs/BRINGUP.md` (new, section 9 outline).
- `ARCHITECTURE.md`: `PlantReadingPacket` in the section 2 tree and the 4.4 mapper example
  note; `LocalMoistureCalibrationLoader` in 4.5 is now real; M8 row in section 11.
- `SETUP.md` section 4: the soil override. `ROADMAP.md`: M8 status note (Part A done).
  `CLAUDE.md`: `Contract/` comment lists `PlantReadingPacket`.

### S10 — Close-out (after bring-up day, with the measured numbers)

The human brings the filled-in tables from `BRINGUP.md`. Then:

- Firmware: `kFirmwareVersion{1, 0, 0}`, `kDefaultIntervalSeconds = 300`, the soil-failure
  decision (`kSoilFailureCheckEnabled` + `kSoilFailureMillivolts`, or stays off with a
  comment saying why). `make -C firmware test` + `compile`, then the human flashes.
- App: `MoistureCalibration.placeholder` = measured defaults (`MoistureCalibrationTests`
  updated); `PlantDeviceSettings.loadMode()` default `.sensor` (`PlantDeviceSettingsTests`).
- Docs: `BLE_CONTRACT.md` (calibration defaults from the measured sensor; "default 300 s"
  becomes the only default), M7 plan section 11 decisions 1, 2 and 4 marked closed, M6
  plan section 11 decision 1 closed, `ROADMAP.md` M8 status, `SETUP.md` (first launch now
  asks for Bluetooth).
- On device: fresh install → Bluetooth prompt, "No sensor paired"; pair → interval
  "Every 5 min"; the serial log shows `fw 1.0.0 … interval 300 s`.

---

## 8. Decisions to close in M8 and how to measure them

| Decision | What to measure (BRINGUP.md) | Rule |
|---|---|---|
| **Soil-failure threshold** (M7 decision 4) | 10 readings each: (a) bare board, nothing on A0 (floating); (b) soil sensor with AOUT unplugged; (c) soil sensor with VCC unplugged, AOUT still on A0; (d) sensor in water (lowest real value). | If (a)–(c) all stay below a value X and (d) stays at least 300 mV above X: enable the check with `kSoilFailureMillivolts` = halfway between max(a–c) and min(d), rounded down to 50 mV. If a floating pin wanders into the real range, keep the check off and note it (decision 2). |
| **Interval 300 s** (M7 decision 2) | Overnight run at 30 s: no `[boot]` line after the first, sequence continuous. Then a day with the app at 300 s. | Overnight clean → firmware default 300 s. |
| **Firmware 1.0.0** (M7 decision 1) | All checks in BRINGUP.md sections 4–7 pass. | Pass → 1.0.0. |
| **Default mode = real sensor** (M6 decision 1) | 24 h on the real board: reconnects by itself after range loss and relaunch, mood follows the soil. | Pass → default `.sensor`. |
| **Calibration defaults** | Three dry and three wet captures from the calibration screen (and the matching serial `[read]` mV). | Defaults = the averages, rounded to 10 mV. |

---

## 9. Part B: `docs/BRINGUP.md` outline (written in S9)

Audience: the human, on the day, step by step, with checkboxes and fill-in tables. Plain
language. Each section ends with "If it fails → see troubleshooting row N".

### 9.0 Before you start

- Parts: XIAO ESP32-C3 ×2 (one spare), its U.FL antenna, capacitive soil sensor, BH1750,
  AHT20, breadboard, female-female and male-female Dupont wires, USB-C **data** cable
  (charge-only cables are the most common "no port" cause).
- Tools: soldering iron (XIAO and many breakouts ship with loose headers), multimeter
  (optional but helpful), glass of water, paper towel, a potted plant, tape.
- Phones: 17 Pro with the app (DEBUG build, `-PlantReadingInterval 30` ticked for the day);
  13 Pro **not** running the test peripheral (avoid two `TalkingPlant-*` devices). In the app:
  Settings → *Forget sensor* if `TalkingPlant-TEST` is paired.
- Mac: `make -C firmware test` and `make -C firmware compile` pass (proves the toolchain
  before the board is plugged in).

### 9.1 On arrival: check what you actually got

Fill-in table: part, marking found, expected, OK?

| Part | Look for | Expected |
|---|---|---|
| XIAO ESP32-C3 | "XIAO ESP32C3" silkscreen, antenna in the bag | Antenna present. **Always attach it** before powering: without it, BLE range is a few cm. |
| Soil sensor | Version on the PCB (v1.2 / v2.0), the 8-pin chip marking, the 3-pin regulator, the line on the probe | Chip **TLC555** / **TLC555I** / **7555** / **LMC555** (CMOS, runs at 3.3 V). **NE555** won't run at 3.3 V → board unusable at 3V3. Regulator "662K". Pin order VCC / GND / AOUT (check the label, it varies). |
| BH1750 | "GY-302", chip "BH1750FVI", pins VCC GND SCL SDA ADDR | ADDR left unconnected → 0x23 (ADDR high → 0x5C). |
| AHT20 | "AHT20" (or "AHT10", or an "AHT20+BMP280" combo) | 0x38. The Adafruit AHTX0 library handles AHT10 and AHT20; a BMP280 at 0x76/0x77 is ignored. |
| Both I2C boards | Supply range printed, two small resistors near SDA/SCL (pull-ups, often marked 472 or 103) | Works at 3.3 V; pull-ups present (power off, multimeter SDA→VCC ≈ 2–10 kΩ). |

### 9.2 Wiring

Rules: **USB unplugged while wiring.** Everything on **3V3**, never 5V. One sensor at a time,
flash and check between each.

Order: (0) bare board → (1) soil sensor → (2) BH1750 → (3) AHT20.

Wiring table: the one from `BLE_CONTRACT.md` / M7 section 2 (soil VCC/GND/AOUT → 3V3/GND/A0;
both I2C boards VCC/GND/SDA/SCL → 3V3/GND/D4/D5; BH1750 ADDR unconnected).

Text diagram (top view, USB-C at the top; check against the silkscreen):

```
                    ┌──────[ USB-C ]──────┐
 soil AOUT ──── D0 / A0  GPIO2      5V     (unused, never)
                D1 / A1  GPIO3      GND  ── GND rail ── soil GND, BH1750 GND, AHT20 GND
                D2 / A2  GPIO4      3V3  ── 3V3 rail ── soil VCC, BH1750 VCC, AHT20 VCC
                D3       GPIO5      D10
 SDA bus ────── D4 / SDA GPIO6      D9     (BOOT button pin, leave free)
 SCL bus ────── D5 / SCL GPIO7      D8     (strapping pin, leave free)
                D6 / TX  GPIO21     D7 / RX
                    └─────────────────────┘
 Antenna on the U.FL connector. A2 reserved for battery sense (V2). Fallback soil pin: A1.
```

Optional multimeter check, USB plugged in: 3V3 pin ≈ 3.3 V; soil AOUT in air ≈ 2.2–2.6 V.
Compare with the `[read]` soil mV (should agree within about 50 mV).

### 9.3 Flashing

```bash
arduino-cli board list          # XIAO shows as /dev/cu.usbmodemXXXX (board name may be "Unknown")
ls /dev/cu.usbmodem*            # same thing without arduino-cli
make -C firmware compile
arduino-cli compile --upload -p /dev/cu.usbmodemXXXX firmware/talking_plant
```

- The C3 uses its built-in USB (USB Serial/JTAG): no driver on macOS. USB CDC On Boot is on
  by default in core 3.3.12 (SETUP.md).
- "Port busy" → close any open monitor (arduino-cli monitor or the Arduino IDE).
- **Board won't flash / port disappeared:** hold **BOOT**, tap **RESET** (or plug in USB while
  holding BOOT), release BOOT. The board is now in download mode; the port name can change,
  so run `arduino-cli board list` again, upload, then tap RESET to run the sketch.
- Flash the spare board too, once, to know it works. It will have its own `TalkingPlant-XXXX`.

### 9.4 Serial monitor, stage by stage

```bash
arduino-cli monitor -p /dev/cu.usbmodemXXXX -c baudrate=115200
```

Logs printed before the monitor attaches are lost. RESET re-enumerates the USB port, which
can close the monitor. To catch boot lines, run it in a loop (the sketch waits up to 2 s
for USB): `while true; do arduino-cli monitor -p /dev/cu.usbmodemXXXX -c baudrate=115200; sleep 0.3; done`.
(Or the Arduino IDE 2 Serial Monitor, which reconnects by itself.) Note: confirm on the day
which one works best and update this paragraph.

Expected at boot, in this order (`[read] #0` comes **before** `[boot]`):

```
[i2c] 0x23 BH1750 ok, 0x38 AHT20 ok
[i2c] found: 0x23 0x38                                   (S8)
[read] #0 soil 2431 mV, lux 312, env 23.41 C 48.20 %, flags 0x07 | 01 07 7F 09 38 01 25 09 D4 12 00 00 00 00 00 00
[boot] TalkingPlant-0EF1 fw 0.1.0 addr aa:bb:cc:dd:0e:f1 interval 30 s
[read] #1 …                                              (every 30 s)
```

Per stage, what you should see and what a failure looks like:

| Stage | Expected | Failure looks like |
|---|---|---|
| 0 bare board | `missing` for both, `lux --, env --`, `flags 0x01`, soil = some floating value. **Write down 10 soil values (table A, for the threshold).** | No output at all → troubleshooting "no log". |
| 1 soil | `flags 0x01`; air ≈ 2.2–2.5 V; water to the line ≈ 1.0–1.3 V; changes within one reading. Measure (b) and (c) for table A. | Flat ~2500+ in air and water, flat ~0, or very slow → "soil stuck". Board won't boot only with the sensor → "strapping pin". |
| 2 + BH1750 | `0x23 BH1750 ok`, `flags 0x03`; hand over it → lux drops; phone torch → lux rises. | `missing` → "I2C not found". |
| 3 + AHT20 | `0x38 AHT20 ok`, `flags 0x07`; room-like values; breathe on it → humidity up. | `missing` → "I2C not found". Temperature 2–3 °C high → it's next to the board or in sun. |

Unplug SDA while running → next readings `flags 0x01`, fields 0; plug back → recovers
without reboot (M7 check 10).

### 9.5 First connection: nRF Connect smoke test

The checks of M7 section 10 in phone terms: Scanner → name `TalkingPlant-XXXX` where
XXXX = last 4 hex digits of `addr` in the boot line; service `7697A001-…`; Readings read =
the latest `[read]` hex; notify ticks every 30 s, sequence +1; Device Info
`01 00 01 00 00 00 1E 00`; Command writes (byte array, write request): `01` → immediate
`[cmd] READ_NOW`; `02 0A 00` → 10 s; `02 05 00` → clamped to 10; `10 10 27` and `03` → logged
and ignored. Disconnect → `[ble] disconnected, reason 0x13, advertising`.

### 9.6 The app

1. Settings → *Real sensor* → *Pair a sensor* → `TalkingPlant-XXXX` with signal bars.
2. Connected, firmware 0.1.0, readings "Every 30 s" (DEBUG argument) or "Every 5 min".
   Serial: `[ble] connected …`, `[ble] readings subscribed`, `[cmd] SET_INTERVAL 30 s`,
   `[cmd] interval 30 s -> 30 s`, `[cmd] READ_NOW`, `[read] #n`.
3. Home chips fill at once. DEBUG raw section in Settings: soil mV, lux, temp, humidity and
   sequence equal the last `[read]` line.
4. *Read now* → a new `[read]` line, raw section updates.
5. Range: walk away → "Connecting…", after 20 s "Sensor offline"; come back → Connected,
   `SET_INTERVAL` re-sent. Kill and relaunch → reconnects without the picker.
6. USB charger instead of the Mac (M7 check 11): readings keep coming.

### 9.7 Calibration session

1. Wipe the sensor dry. Hold it in the air by its top edge (a hand near the probe changes
   the value). Settings → *Moisture calibration* → *Capture dry*. Capture three times; write
   the values in table B. They should agree within about 20 mV. A near-limit warning means
   the sensor is close to the ADC ceiling: check it's on 3V3.
2. Glass of water up to the line, top part dry. Wait 30 s. *Capture wet* three times
   (table B).
3. *Save*. Status: Calibrated. Home moisture ≈ 100 % in water, ≈ 0 % in air.
4. Real pot: push the sensor in up to the line, about halfway between stem and edge. Moist
   soil typically reads 40–80 % (never 100 %: water is the wettest case). Water the plant,
   *Read now* after a minute → moisture rises. Write before/after in table B.
5. Readings taken during calibration (0 % and 100 %) stay in the sensor history and may
   trigger a mood notification. Expected; ignore them.

### 9.8 End to end and the overnight run

- Sensor in air → next reading → thirsty mood, Sprout changes, speech bubble in the plant's
  voice; *Talk* → "how are you?" → it mentions thirst (or the template line if Apple
  Intelligence is off). Back in the pot → mood recovers.
- Cover the BH1750 for a while → mood / scene follows the low light.
- Leave it running overnight at 30 s with the monitor logging to a file
  (`… | tee bringup-night.log`). Morning: one `[boot]` line only, sequence continuous.

### 9.9 Results to bring back (for S10)

- Table A (soil-failure measurements a–d).
- Table B (dry ×3, wet ×3, pot before/after watering).
- Module markings from 9.1.
- Overnight result, disconnect reasons seen, anything that needed a fix.

### 9.10 Troubleshooting

| # | Symptom | Likely cause | Fix |
|---|---|---|---|
| 1 | No port in `board list` | Charge-only cable; board in a crash loop | Data cable; BOOT + RESET download mode, re-flash |
| 2 | Upload: "port busy" / "No serial data received" | Monitor still open; not in download mode | Close monitor; BOOT + RESET, upload, RESET |
| 3 | No log at all | Monitor attached after the boot lines; firmware not running | Monitor loop (9.4); wait 30 s for the next `[read]`; re-flash |
| 4 | Board boots without the soil sensor, not with it | A0 = GPIO2 strapping pin held at boot | Move AOUT to A1 and change `kSoilPin` (a wiring change → propose a `BLE_CONTRACT.md` update first) |
| 5 | Not advertising (not in nRF Connect) | No `[boot]` line → sketch not running; antenna missing; already connected to another phone (`[ble] connected` in the log); name filter in the scanner | Re-flash; attach antenna; disconnect the other phone; clear the filter |
| 6 | `[i2c] … missing` | SDA/SCL swapped; no 3V3/GND; loose Dupont; other address (see `found:`, e.g. BH1750 at 0x5C); no pull-ups | Check wiring one wire at a time; ADDR to GND or change `kLightAddress`; add 4.7 kΩ pull-ups to 3V3 |
| 7 | Probe `ok` but the flag clears later | Intermittent contact | Reseat wires, solder headers |
| 8 | `flags` not `0x07` | Bit0 soil, bit1 light, bit2 env. `0x01` → both I2C missing; `0x03` → AHT20; `0x05` → BH1750 | See 6 |
| 9 | Soil flat ≈ 2500 mV+ in air and water | Saturating: powered from 5V; NE555 instead of TLC555 | 3V3 only; replace the sensor |
| 10 | Soil ≈ 0 mV | VCC not connected; AOUT not on A0 | Check wiring |
| 11 | Soil changes very slowly after leaving water | Known v1.2 defect: the 1 MΩ discharge resistor isn't connected to GND | Different sensor, or bridge the resistor to GND (only if comfortable soldering) |
| 12 | Soil drifts over days | Water reaching the unprotected PCB edge / top electronics | Keep soil below the line; seal edges (nail polish / heat shrink) |
| 13 | App: moisture always 0 % or 100 % | Not calibrated, or calibrated wrong | Compare raw soil mV with the calibration values; recalibrate |
| 14 | Disconnects, reason `0x08` | Supervision timeout: range, antenna, noisy USB power | Antenna, closer, different power |
| 15 | Disconnects, reason `0x13` | The phone closed the link (Forget, mode switch, iOS) | Usually fine |
| 16 | App stuck on "Connecting…" | Stale identifier | M6 reconnects by name; else *Forget* + pair |
| 17 | App: "Sensor not compatible" | Service missing → wrong firmware on the board | Re-flash |
| 18 | Random reboots (`[boot]` again, sequence back to 0) | Brown-out from weak USB power | Other cable / port / charger |

Sources for the defaults (cited in BRINGUP.md and BLE_CONTRACT.md): ESP-IDF ESP32-C3 ADC
documentation (12 dB range 0–2500 mV); "Capacitive Soil Moisture Sensor v1.2" manuals
(≈ 2.5 V air, ≈ 1.0 V water).

---

## 10. Decisions taken in this plan

1. Readings decoding is promoted to `PlantShared/Contract/PlantReadingPacket` (second
   feature needs it), instead of adding soil mV to `PlantReading` / history.
2. Calibration only exists in sensor mode. The simulated plant keeps a fixed 2400/1100.
3. A capture always asks for a fresh reading (`READ_NOW`, next new sequence, 10 s timeout),
   never the possibly old live value.
4. Both points must be captured in the same session to save.
5. Validation: wet < dry and a range of at least 300 mV; dry ≥ 2480 mV only warns.
6. Reset writes 0/0 instead of adding `remove(forKey:)` (same as M6 decision 9).
7. Recalibrating doesn't rewrite stored history (it stores %, not mV).
8. Raw-values section is DEBUG only, via a composer flag set by the app.
9. Defaults 2450/1050 from typical published values now; measured values in S10.

---

## 11. Decisions

1. **I2C scan in the firmware (S8):** yes, add it.
2. **Soil failure if a floating A0 reads in the real range:** keep the check off, no
   pull-down. Decide on bring-up day from table A.
3. **"Not calibrated" outside Settings:** not on the home chip. Settings and the
   calibration screen only.
4. **Live soil value on the calibration screen:** no interval switch while calibrating.
   Capture uses `READ_NOW`.
5. **Bring-up readings in history:** yes, add a DEBUG "Clear sensor history" button.
6. **Default mode = real sensor (S10):** the Bluetooth prompt on first launch is OK for
   now. Revisit with onboarding.
7. **Multimeter:** no, but one will be bought. BRINGUP.md keeps the voltage and pull-up
   checks, marked optional until then.
8. **Headers:** probably not soldered. BRINGUP.md adds a short soldering step before 9.2.
