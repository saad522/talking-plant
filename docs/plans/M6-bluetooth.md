# M6 plan: the real Bluetooth client

Scope (ROADMAP M6):

- `CoreBluetoothPeripheralClient` in PlantShared: scan by service UUID, connect, discover,
  subscribe to Readings, read Device Info, write Command, reconnect after a disconnect or
  going out of range, and report Bluetooth off / unauthorized / unsupported.
- Pairing: a device picker (scan list with `TalkingPlant-XXXX` names and signal), remember
  the chosen peripheral, forget it.
- Device Info loader and commands (`READ_NOW`, `SET_INTERVAL`). The app re-sends the
  interval on every connect (M7 plan, decision 3).
- Simulated vs real chosen in the composition root and toggled in Settings, with one
  history store file per mode.
- Connection state in the UI: connecting, connected, offline.
- A DEBUG test peripheral to run the app end to end before the parts arrive (section 7).

**Done when:** `swift test` passes for every touched target, the app builds, the end-to-end
checklist (section 9) passes against the test peripheral, and the human verifies on the
board in M8.

Out of scope: calibration screen and `LocalMoistureCalibrationLoader` (M8), pump commands
in the UI, Mode B, CoreBluetooth state restoration, bonding/encryption, multiple plants,
any change to `BLE_CONTRACT.md`.

Implementation is split into steps S1–S10, one session each (section 8).

---

## 1. What exists today

| Piece | State |
|---|---|
| `PeripheralClient` (read, subscribe, write) | PlantShared. Only `SimulatedPeripheralClient` implements it. |
| `PlantBluetoothContract`, `PlantCharacteristic` | Service UUID, name prefix, lengths, characteristic UUIDs. |
| `PeripheralPlantReadingLoader` + `PlantReadingMapper` | Done (M2). Client failures → `.connectivity`, bad packets → `.invalidData`. |
| `LocalPlantReadingDecorator` | Saves readings, skips a repeated sequence. |
| `PlantDeviceInfoMapper`, `PlantDeviceCommandMapper` | Done (M1), with an interim `PlantDeviceInfoMapper.Error` to be replaced by the loader's error. The Device Info mapper doesn't reject `protocolVersion != 1` yet (M7 plan, section 8). |
| Offline mood | `PlantHealthEvaluator`: no reading for `offlineAfter` (15 min) → `.offline`. |
| Home header | Name + `"<room> · <mood>"`. DESIGN.md section 4 also has a 44 pt settings button; not built yet. |
| Settings screen | None. Personality lives in the chat header menu. |
| App target | `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, Mac (Designed for iPad) off, iPhone + iPad. `NSBluetoothAlwaysUsageDescription` is set (fixed in M5b S0). |
| Firmware (M7) | Advertises `TalkingPlant-XXXX` + service UUID (name in the scan response), one connection, advertises again on disconnect, default interval 30 s, interval not persisted. |

---

## 2. Design overview

```
PlantShared/Client
  PeripheralClient              (unchanged)  read / subscribe / write  → raw Data
  PeripheralConnectionClient    (new)        state, scan, connect, disconnect → raw values
  CoreBluetoothPeripheralClient (new)        implements both
  SimulatedPeripheralClient     (+ conformance: always connected, finds nothing)
PlantShared/Domain
  PlantConnection               (new)        what the user sees; used by PlantMonitor + PlantDevice

PlantDevice   (business)   loaders for connection, Device Info, commands, scan, pairing;
                           settings (mode + paired device); connection setup on connect
PlantDeviceiOS (new UI)    Settings screen ("Plant sensor") + device picker
PlantMonitor  (+)          connection in the header subtitle, settings button → action
App                        picks the client + store file per mode, rebuilds on mode change
PlantTestPeripheral (new, DEBUG)  CBPeripheralManager serving contract packets
```

Rules carried over:

- One data path. Both modes go client → loader → mapper → view model. Nothing in PlantDevice
  or PlantMonitor knows which client is used.
- The CoreBluetooth client stays thin: no timers, no interval, no version check, no
  persistence. Every rule that can be wrong lives in a unit-tested loader.
- Disconnects are not reading errors. A Readings subscription lives as long as the client and
  survives reconnects; connection changes go through `PeripheralConnectionClient`. That keeps
  the full-screen error overlay for real errors only.
- PlantMonitor never imports PlantDevice. It declares its own small `PlantConnectionLoader`
  protocol, and the app adapts the PlantDevice loader to it (same pattern as
  `PlantHealthMoodLoaderAdapter`). `PlantConnection` moves to PlantShared because both
  features use it.

---

## 3. PlantShared

### 3.1 `PeripheralConnectionClient` (Client/)

```swift
public struct PeripheralAdvertisement: Equatable, Sendable {
    public let identifier: UUID
    public let localName: String?
    public let rssi: Int
}

public enum PeripheralConnectionState: Equatable, Sendable {
    case unsupported      // no BLE on this device
    case unauthorized     // permission denied or restricted
    case poweredOff
    case idle             // nothing to connect to
    case connecting       // pending connect, or connected but still discovering
    case connected        // service + 3 characteristics ready, Readings notify on
    case incompatible     // connected but the Plant Service or a characteristic is missing
}

@MainActor
public protocol PeripheralConnectionClient {
    /// Delivers the current state immediately, then every change.
    func subscribe(state update: @escaping (PeripheralConnectionState) -> Void)
    /// Advertisements of the Plant Service, repeated (RSSI updates) until `stopScan()`.
    func scan(update: @escaping (PeripheralAdvertisement) -> Void)
    func stopScan()
    /// Connects and keeps reconnecting until `disconnect()`. `name` is the fallback
    /// when the identifier is unknown to this phone (section 4.3).
    func connect(to identifier: UUID, name: String)
    /// Cancels the connection and stops reconnecting.
    func disconnect()
}
```

Doc comment on `PeripheralClient.subscribe` (no signature change): "Real client: the
handler stays registered for the client's lifetime and notifications are re-enabled on
every connection. Disconnects are reported by `PeripheralConnectionClient`, not here."

### 3.2 `PlantConnection` (Domain/)

```swift
public enum PlantConnection: Equatable, Sendable {
    case notPaired
    case connecting
    case connected
    case offline                // still connecting after the grace period
    case bluetoothOff
    case bluetoothUnauthorized
    case bluetoothUnsupported
    case incompatible
}
```

### 3.3 Small additions

- `PlantCharacteristic.init?(uuid: UUID)` — the client needs the reverse lookup.
- `SimulatedPeripheralClient: PeripheralConnectionClient` — state `.connected` delivered
  immediately; `scan` delivers nothing; `connect`, `disconnect`, `stopScan` do nothing. The
  simulated plant then composes exactly like the real one.

---

## 4. `CoreBluetoothPeripheralClient`

`@MainActor public final class CoreBluetoothPeripheralClient: NSObject, PeripheralClient,
PeripheralConnectionClient`, in `PlantShared/Client/`. iOS and macOS both have
CoreBluetooth, so `swift build` keeps working.

### 4.1 Concurrency rules (the M5b lesson)

The M5b crash was a closure created inside a `@MainActor` method, so inferred `@MainActor`,
then called by the system on a background queue. Rules for this client:

1. `CBCentralManager(delegate: self, queue: nil, options: [CBCentralManagerOptionShowPowerAlertKey: false])`.
   `queue: nil` = every delegate callback arrives on the main queue (ARCHITECTURE.md 3.2).
2. All `CBCentralManagerDelegate` / `CBPeripheralDelegate` methods are `nonisolated`. Each
   first copies out Sendable values (`peripheral.identifier`, `characteristic.uuid`,
   `characteristic.value` as `Data`, RSSI as `Int`, the local name, the error), then calls
   `MainActor.assumeIsolated { ... }` with only those values. CB objects are looked up again on
   the main actor from the client's own stored properties, not passed across.
3. No `Task { @MainActor in }` hops in delegate methods (they could reorder events).
4. No closure-based system API in this client. If one is ever needed, call it from a
   `nonisolated static` function, as in `SpeechAnalyzerPlantTranscriberClient`.
5. All CoreBluetooth code lives in PlantKit, never in the app target, whose default
   isolation is `MainActor`.
6. The `CBCentralManager` is created only in sensor mode. Creating it shows the Bluetooth
   permission prompt, so simulated mode must never instantiate this client.

### 4.2 State

Main-actor stored properties: `central`, `target: (identifier, name)?`, `peripheral:
CBPeripheral?`, `characteristics: [PlantCharacteristic: CBCharacteristic]`,
`pendingReads` / `pendingWrites` (FIFO per characteristic), `subscriptions` per
characteristic, `stateSubscriptions`, scan handlers, and `state` (notifies subscribers on
change only). Logging through `os.Logger` (category `Bluetooth`) for every state change,
connect, discovery result, and error, which helps a lot in the on-device checks.

`centralManagerDidUpdateState` → `.unsupported` / `.unauthorized` / `.poweredOff`;
`.poweredOn` → `.connecting` if a target is set (and start connecting), else `.idle`.
`.unknown` / `.resetting` → `.connecting` with a target, `.idle` without.

### 4.3 Connect and reconnect

1. `connect(to:name:)` saves the target. When powered on: `retrievePeripherals(withIdentifiers:)`
   → `central.connect(peripheral)`. A pending connect never times out, so this also covers
   "out of range": iOS connects as soon as the board advertises again.
2. Identifier unknown to this phone (`retrievePeripherals` empty): scan with the service
   filter and connect to the first advertisement whose identifier **or** local name matches
   the target.
3. `didConnect` → `discoverServices([plant service])` → `discoverCharacteristics([readings,
   deviceInfo, command])` → keep the three → `setNotifyValue(true)` on Readings → after
   `didUpdateNotificationStateFor` (success or logged failure) → `.connected`.
4. Service or characteristic missing → `.incompatible`, `cancelPeripheralConnection`, no
   automatic retry until the next `connect(to:name:)`. Retrying would loop at once, since
   the device is in range.
5. `didDisconnect` / `didFailToConnect` → clear characteristics, fail pending reads/writes with
   `Error.disconnected`, `.connecting`, `central.connect(peripheral)` again (target still set).
6. `.poweredOff` drops everything; the next `.poweredOn` starts again at step 1.
7. `disconnect()` → target `nil`, cancel the connection, fail pending requests, `.idle`.

The board accepts one connection and stops advertising while connected, so the picker
never shows the connected board. That's expected.

### 4.4 Read, write, subscribe

- `read` while not `.connected` → `.failure(Error.notConnected)` immediately. No queueing; the
  callers that matter (setup, Settings screen) wait for `.connected`.
- `write` → `.withResponse` (contract), same not-connected rule; completes from
  `didWriteValueFor`.
- `didUpdateValueFor` (both read responses and notifications): complete every pending read of
  that characteristic, then deliver to its subscribers. A Readings read therefore also
  reaches the Readings subscribers; `LocalPlantReadingDecorator` already drops the repeated
  sequence.
- `subscribe(to:)` stores the handler; if already connected, enables notify at once. A value
  update with an error is delivered as `.failure` (rare; the loader maps it to
  `.connectivity`).
- 16-byte Readings fit the default ATT MTU (20-byte payload), so there's no MTU handling.

### 4.5 Scan

`scan(update:)` starts `scanForPeripherals(withServices: [service], options:
[CBCentralManagerScanOptionAllowDuplicatesKey: true])` (live RSSI for the picker), or waits
for `.poweredOn`. Local name from `CBAdvertisementDataLocalNameKey`, else `peripheral.name`.
The central keeps scanning while either the picker or the reconnect fallback (4.3 step 2)
needs it.

### 4.6 Not unit-tested

Same as the PlantChat platform clients: CoreBluetooth objects can't be faked without an
extra wrapper layer, which we don't add. Coverage comes from the thin design (4.1–4.5), the
`PlantCharacteristic(uuid:)` test, the test peripheral (section 7), and the on-device
checklist (section 9).

---

## 5. PlantDevice (business)

New folders: `Persistence/`, `Presentation/`, `Resources/en.lproj/PlantDevice.strings`
(Package.swift gets `resources: [.process("Resources")]` and `PlantDeviceBundle`).

### 5.1 Domain

| Type | Content |
|---|---|
| `PlantDeviceMode` | `.simulated`, `.sensor` (String raw values) |
| `PlantPairedDevice` | `identifier: UUID`, `name: String` |
| `PlantDeviceCandidate` | `identifier: UUID`, `name: String`, `rssi: Int` |
| `PlantDeviceAction` | `.pairTap`, `.paired`, `.modeChanged(PlantDeviceMode)`, `.openSettings` |
| `PlantDeviceConnectionLoader` | `subscribe(update: (PlantConnection) -> Void)` |
| `PlantDeviceInfoLoader` | `load(completion: (Result<PlantDeviceInfo, Error>) -> Void)` |
| `PlantDeviceCommandSender` | `send(_: PlantDeviceCommand, completion: (Error?) -> Void)` |
| `PlantDeviceScanLoader` | `start(update: (PlantDeviceCandidate) -> Void)`, `stop()` |
| `PlantDevicePairingLoader` | `subscribe(update: (PlantPairedDevice?) -> Void)` (current value first), `pair(_: PlantDeviceCandidate)`, `forget()`, `connectSaved()` |

Commands use a "sender", not a "loader", since they write. Same style otherwise.

### 5.2 API

- **`PeripheralPlantDeviceInfoLoader(client: PeripheralClient)`** — `read(.deviceInfo)` →
  `PlantDeviceInfoMapper`. Errors `.connectivity`, `.invalidData`. The mapper's interim
  `Error` is removed and it now also rejects `protocolVersion != 1` (like the Readings
  mapper).
- **`PeripheralPlantDeviceCommandSender(client: PeripheralClient)`** —
  `PlantDeviceCommandMapper.map` → `write(_, to: .command)`; failure → `.connectivity`.
- **`PeripheralPlantDeviceConnectionLoader(client: PeripheralConnectionClient, offlineAfter: TimeInterval = 20, schedule: Schedule)`**
  — maps the client state 1:1 (`idle` → `.notPaired`, `poweredOff` → `.bluetoothOff`, …).
  On `.connecting` it schedules a one-shot tick (`Schedule` as in `LocalPlantHealthLoader`,
  returning `false`); if the state is still `.connecting` when it fires → `.offline`. A
  newer state cancels the pending tick (generation counter). Delivers only changes.
- **`PeripheralPlantDeviceScanLoader(client: PeripheralConnectionClient)`** →
  `PlantDeviceCandidateMapper`: keeps advertisements whose name starts with
  `PlantBluetoothContract.localNamePrefix`; drops a missing name (the scan response with the
  name arrives on a later callback) and RSSI 127 ("unavailable" in CoreBluetooth).
- **`PeripheralPlantDevicePairingLoader(client: PeripheralConnectionClient, settings: PlantDeviceSettings)`**
  — `pair` saves and calls `client.connect(to:name:)`; `forget` clears and calls
  `client.disconnect()`; `connectSaved` connects when something is saved; subscribers get
  every change.
- **`PlantDeviceConnectionSetup(connection:infoLoader:commands:readingInterval:)`** with
  `start()` (precedent: `PlantMoodNotifier`). On every transition into `.connected`:
  1. load Device Info;
  2. success → `send(.setInterval(readingInterval))`, then on success `send(.readNow)`, so
     the home screen gets a fresh reading right away instead of after a full interval;
  3. failure (`.invalidData` includes an unsupported protocol version) → no commands.
  Repeated `.connected` without a transition in between runs nothing. Captures nothing
  strongly in callbacks.

### 5.3 Persistence

`PlantDeviceSettings(defaults: DefaultsClient)`, like `PlantPersonalitySettings`:

- `loadMode()` (default `.simulated`, decision 1) / `saveMode(_:)` — key `plant.device.mode`.
- `loadPairedDevice()` / `savePairedDevice(_:)` / `clearPairedDevice()` — keys
  `plant.device.paired.identifier` and `plant.device.paired.name`. `DefaultsClient` has no
  remove, so clearing writes empty strings and loading treats an invalid UUID as nothing
  paired. No protocol change, no spy churn in three test targets.

### 5.4 Presentation

- **`PlantDeviceViewModel`** (the Settings screen). Inputs: `appear()` (guarded),
  `modeSelect(_:)`, `pairTap()`, `forgetTap()`, `readNowTap()`, `openSettingsTap()`.
  Observers: `loadedMode`, `loadedConnection(PlantDeviceConnectionViewModel)`,
  `loadedPairedDevice(PlantPairedDevice?)`, `loadedInfo(PlantDeviceInfoViewModel)`,
  `loadedCommandError`. On `appear` it subscribes to connection and pairing; on each
  transition into `.connected` it loads Device Info. `modeSelect` saves the mode, then sends
  `.modeChanged` (no action if the mode didn't change).
- **`PlantDevicePickerViewModel`**. `appear()` starts the scan, `disappear()` stops it.
  Merges candidates by identifier (latest RSSI wins), sorted by name so rows don't jump.
  `select(_:)` stops the scan, pairs, sends `.paired`. Also subscribes to the connection
  loader for the empty state (Bluetooth off / not allowed vs "Looking for your plant…").
- **Small view models:** `PlantDeviceConnectionViewModel` (label, `showsOpenSettings` for
  unauthorized, `isConnected`), `PlantDeviceCandidateViewModel` (name, `signalBars` 1–3:
  ≥ −60 dBm → 3, ≥ −75 → 2, else 1), `PlantDeviceInfoViewModel` (firmware `"0.1.0"`,
  interval `"Every 30 s"` / `"Every 5 min"` via `PlantDeviceFormatter`).
- Strings: `plant.device.*` (screen title, mode labels, connection labels, buttons, picker
  empty states). Copy confirmed (decision 6), plus an Open Settings button for "Bluetooth not allowed".

---

## 6. UI

### 6.1 PlantDeviceiOS (new target + `PlantDeviceiOSTests`)

- **`PlantDeviceView`** ("Plant sensor"): a plain SwiftUI `Form` (decision 5).
  - Section *Plant*: segmented picker *Simulated plant / Real sensor*.
  - Section *Sensor* (sensor mode only): status row; paired name or "No sensor paired";
    firmware and interval rows when connected; buttons *Read now* (connected only),
    *Pair a sensor* / *Change sensor* (→ `.pairTap`), *Forget sensor*; *Open Settings*
    when Bluetooth isn't allowed.
- **`PlantDevicePickerView`**: list rows (name + `cellularbars` symbol with variable value
  for the bars), empty state text, `onAppear` / `onDisappear` to the view model.
- Stores, `PlantDeviceUIComposer.composed(...)` and `.composedPicker(...)`, styles with
  system colors. No `UIKit`, no iOS-only list styles (keeps `swift test` on macOS).

### 6.2 PlantMonitor / PlantMonitoriOS (small changes)

- `PlantMonitorAction.settingsTap`; `PlantMonitorViewModel.settingsTap()`.
- `PlantConnectionLoader` protocol (`subscribe(update: (PlantConnection) -> Void)`) in
  `PlantMonitor/Domain`, a new `connectionLoader` init parameter on the view model and the
  composer.
- `PlantMonitorHeaderViewModel` gets `connection: PlantConnection?`. Subtitle: `.connected`
  or `nil` → today's `"<room> · <mood>"`; any other case → `"<room> · <connection label>"`
  ("Connecting…", "Sensor offline", "Bluetooth is off", "Bluetooth not allowed",
  "No sensor paired", …). The view model keeps the latest connection and re-emits the
  scene/header on change; the composer updates the subtitle even before a mood loads.
- The mood is unchanged: it still turns `.offline` after 15 min without readings
  (decision 2).
- `PlantMonitorHeaderView`: 44 pt round settings button on the right (DESIGN.md section 4,
  `slider.horizontal.3`), tap → `viewModel.settingsTap`.
- Existing tests: `LoaderStub` also implements `PlantConnectionLoader`; `makeSUT` passes it.

### 6.3 App target (composition root)

- `AppNavigation.Route` gets `.device` and `.devicePicker`. `.settingsTap` → push `.device`;
  `.pairTap` → push `.devicePicker`; `.paired` → pop; `.openSettings` → system Settings URL.
- **One graph per mode.** `init` moves into `AppGraph.make(mode:)` (app target only), returning
  the views and the long-lived objects (client, notifier, setup). An `ObservableObject`
  holds the current graph. `.modeChanged(mode)` → `disconnect()` the old real client →
  build the new graph → swap. The root gets `.id(graph.id)` so `onAppear` runs on the new
  view models; the navigation path stays on `.device`.
- **Simulated mode:** today's wiring, store file `PlantHistory.store` (keeps the existing
  history), simulated clock as `currentDate`, Water toolbar button. The setup isn't started.
- **Sensor mode:** `CoreBluetoothPeripheralClient()`, store file `PlantHistory-Sensor.store`,
  `currentDate = Date.init`, calibration `.placeholder` (M8), `pairing.connectSaved()`,
  `setup.start()` with `readingInterval` 300 s (DEBUG: `-PlantReadingInterval <s>`).
- Adapters (app): `PlantDeviceConnectionLoaderAdapter: PlantConnectionLoader`.
- DEBUG `-PlantTestPeripheral`: show the test peripheral screen instead of the app (7.2).
- Known leftover: the old graph's health recheck timer keeps firing as a no-op after a
  switch. Mode switches are rare, so it's accepted rather than reworking
  `LocalPlantHealthLoader`.
- Human step in Xcode: add the `PlantDevice`, `PlantDeviceiOS` and `PlantTestPeripheral`
  products to the app target.

---

## 7. DEBUG test peripheral — recommendation: **yes**

### 7.1 What it gives us

The app runs against a peripheral that speaks the real contract over real radio before the
board arrives: scan with names and RSSI, connect, discovery, notify, read, write with
response, Device Info, `SET_INTERVAL` / `READ_NOW` handling, Bluetooth off / unauthorized on
the phone, short out-of-range reconnects, and above all every delegate callback running
through the Swift 6 isolation rules on a device. That's the class of bug that crashed M5b,
and the simulator can't catch it (it has no Bluetooth). Without it, the first time
`CoreBluetoothPeripheralClient` runs at all is M8, mixed with wiring and sensor problems.

### 7.2 Shape

- **Host:** inside the existing app, DEBUG only, started with the launch argument
  `-PlantTestPeripheral`. It runs on any second iPhone or iPad, or on this Mac if the human
  turns on the *Mac (Designed for iPad)* destination (currently `NO`). No macOS command-line
  tool: a CLI needs its own Info.plist/TCC handling for Bluetooth and its own signing, for
  no gain.
- **Code:** new PlantKit target `PlantTestPeripheral` (depends on PlantShared, sources wrapped
  in `#if DEBUG`), so the CoreBluetooth code compiles with PlantKit's nonisolated default
  and not the app's `MainActor` default.
  - `PlantTestPeripheralResponder` (pure, unit-tested in `PlantTestPeripheralTests`):
    Device Info bytes for firmware 0.1.0 and the current interval; command bytes → effect
    (`READ_NOW`, `SET_INTERVAL` clamped 10–3600, unknown / short ignored), mirroring the
    contract and `PlantCommandParser`.
  - `CoreBluetoothPlantTestPeripheral`: `CBPeripheralManager(queue: nil)`, same rules as 4.1.
    Adds the Plant Service with the three characteristics, advertises `TalkingPlant-TEST` +
    the service UUID. Packets come from a `SimulatedPeripheralClient` (so a real 16-byte
    packet with the simulated drying); notifies the latest packet every interval (default
    30 s) and on `READ_NOW`; answers reads; logs every command.
  - App (DEBUG): a small screen with state, interval, last commands, and a Water button.

### 7.3 Cost and limits

- Cost: one session (S5), about 200 lines plus a handful of tests, and ~15 minutes of human
  setup (second device or the Mac destination). Nothing ships in release builds.
- Limits: Apple devices rotate their advertising address and share the link with the
  system, so long disconnects or toggling the peripheral's Bluetooth can make the identifier
  change. Then use Forget + pair again; the board's identifier is stable. Real sensor values,
  range, NimBLE timing and power stay for M8.

---

## 8. Steps (one session each)

Every step: run only the affected test targets (`swift test --filter <Target>`), leave
changes uncommitted, short summary. "On device" lists what the human checks; most steps
have none until S9 wires everything.

### S1 — Shared connection types

- Files: `PlantShared/Client/PeripheralConnectionClient.swift`,
  `PlantShared/Domain/PlantConnection.swift`, `PlantCharacteristic.swift` (`init?(uuid:)`),
  `SimulatedPeripheralClient.swift` (conformance), `PeripheralClient.swift` (doc comment).
- Tests (`PlantSharedTests`): `PlantCharacteristic(uuid:)` for the three UUIDs and an
  unknown one; simulated client delivers `.connected` on `subscribe(state:)`, delivers
  nothing on `scan`, and `connect`/`disconnect` don't disturb readings.
- On device: none.

### S2 — Device Info, commands, connection loader

- Files: `PlantDevice/Domain/` (protocols for info, commands, connection),
  `PlantDevice/API/PeripheralPlantDeviceInfoLoader.swift`, `PeripheralPlantDeviceCommandSender.swift`,
  `PeripheralPlantDeviceConnectionLoader.swift`, `PlantDeviceInfoMapper.swift` (version check,
  interim error removed). Test base: `ClientSpy`, `ConnectionClientSpy`, `ScheduleSpy`.
- Tests: info loader — init sends nothing, reads `.deviceInfo`, `.connectivity` on failure,
  `.invalidData` on wrong length and on versions 0 and 2, delivers the M7 fixture
  `01 01 02 03 00 00 2C 01`, no leak. Command sender — writes the mapped bytes to `.command`,
  `.connectivity` on failure, `nil` on success, no leak. Connection loader — each client
  state maps to its case; `.connecting` → `.offline` only after the tick; a newer state
  before the tick wins; duplicate states not re-delivered; no leak.
- On device: none.

### S3 — Settings, pairing, scan, connection setup

- Files: `PlantDevice/Domain/` (mode, paired device, candidate, action, scan + pairing
  protocols), `PlantDevice/Persistence/PlantDeviceSettings.swift`,
  `PlantDevice/API/PeripheralPlantDevicePairingLoader.swift`,
  `PeripheralPlantDeviceScanLoader.swift`, `PlantDeviceCandidateMapper.swift`,
  `PlantDeviceConnectionSetup.swift`.
- Tests: settings — default mode, round trips, clear, empty/invalid identifier = nothing.
  Pairing — `pair` saves + connects + notifies, `forget` clears + disconnects + notifies,
  `connectSaved` with and without a saved device. Scan — prefix filter, nil name, RSSI 127,
  `stop`. Setup — reads info on `.connected`, then `setInterval(n)` then `readNow` in that
  order, nothing on info failure / unsupported version / failed `setInterval`, runs again
  after `.connecting → .connected`, not twice for repeated `.connected`, no leak.
- On device: none.

### S4 — `CoreBluetoothPeripheralClient`

- Files: `PlantShared/Client/CoreBluetoothPeripheralClient.swift`.
- Work: section 4, with the 4.1 rules written as the type's doc comment.
- Verify: `swift build`; `swift test --filter PlantSharedTests`; review every delegate method
  against 4.1 rule 2.
- On device: none yet (S9).

### S5 — Test peripheral

- Files: `Package.swift` (`PlantTestPeripheral` + tests), `PlantTestPeripheral/`
  (responder + CB peripheral), `Tests/PlantTestPeripheralTests/`, app: DEBUG screen and the
  `-PlantTestPeripheral` launch argument.
- Tests: Device Info bytes for 30 s and 300 s; `01` → read now; `02 2C 01` → 300; `02 05 00`
  → 10; `02 FF FF` → 3600; `02 2C` and `7F` ignored; trailing bytes ignored.
- On device (second device or Mac): start with `-PlantTestPeripheral`; with nRF Connect or
  LightBlue on the main iPhone: `TalkingPlant-TEST` shows with the service UUID; Readings
  read gives 16 bytes starting `01 07`; notify ticks every 30 s; writing `01` notifies at
  once; writing `02 0A 00` changes the tick to 10 s and Device Info reads `… 0A 00`.

### S6 — Settings screen

- Files: `PlantDevice/Presentation/` (`PlantDeviceViewModel`, connection + info view models,
  formatter, bundle), `Resources/en.lproj/PlantDevice.strings`, `Package.swift`
  (`PlantDeviceiOS`, `PlantDeviceiOSTests`), `PlantDeviceiOS/` (store, view, styles, composer).
- Tests: view model (subscriptions once, info loaded on each `.connected`, read now, forget,
  mode select saves + action only on change, open settings), formatter, strings table has
  every key; integration from the composer — sensor section hidden in simulated mode,
  status text per connection, firmware/interval rows after info, buttons send the right
  loader messages and actions.
- On device: none yet (S9).

### S7 — Device picker

- Files: `PlantDevicePickerViewModel`, `PlantDeviceCandidateViewModel`, picker store/view,
  `PlantDeviceUIComposer.composedPicker`.
- Tests: scan start/stop with appear/disappear, merge by identifier, name order, signal
  bars at the thresholds, empty-state text per connection, select → stop + pair + `.paired`;
  integration rows and tap.
- On device: none yet (S9).

### S8 — Home header

- Files: `PlantMonitorAction`, `PlantMonitor/Domain/PlantConnectionLoader.swift`,
  `PlantMonitorViewModel`, `PlantMonitorHeaderViewModel`, `PlantMonitorSceneViewModel`
  (passes the connection to the header), strings, `PlantMonitorHeaderView`, composer, the
  existing test bases and stubs.
- Tests: subtitle per connection case (with and without mood, sleeping), view model
  subscribes to the connection once on appear, `settingsTap` action; integration: the
  settings button sends `.settingsTap`, subtitle shows "Connecting…" before any reading.
- On device: none yet (S9).

### S9 — Composition root

- Files: `TalkingPlantApp.swift` (graph per mode, routes, adapters, DEBUG arguments),
  `Info.plist` (decision 4: yes). Human adds the package products in Xcode.
- Water in sensor mode (decision 7): the `.waterTap` route sends `READ_NOW` after about
  10 s through the command loader (injected `Schedule`, so it's unit-testable); the
  simulated mode keeps watering the simulated plant.
- Verify: the human builds in Xcode (per CLAUDE.md I don't run simulator builds unless
  asked); `swift test` for PlantMonitor, PlantDevice, PlantShared.
- On device: the full checklist in section 9.

### S10 — Docs

- `ARCHITECTURE.md`: `PeripheralConnectionClient` in the 4.3 table, `PlantDeviceiOS` and
  `PlantTestPeripheral` in section 2, the 4.1 concurrency rules in section 3, M6 row in 11.
  `ROADMAP.md`: M6 status note. `SETUP.md`: how to run the test peripheral.
  `CLAUDE.md`: repo layout. `M7-firmware.md` section 8: the Device Info mapper now rejects
  version ≠ 1.

---

## 9. End-to-end checklist (S9, main iPhone + test peripheral)

1. Fresh install starts in simulated mode; no Bluetooth prompt.
2. Settings → Real sensor: the Bluetooth prompt shows once. Deny → header "Bluetooth not
   allowed", Settings shows *Open Settings*; allow it → after returning (or a relaunch, if
   iOS restarts the app) it moves on to "No sensor paired".
3. Pair: the picker shows `TalkingPlant-TEST` with bars that change as you move the phone.
   Tap → back on Settings: Connecting… → Connected within a few seconds, firmware 0.1.0,
   interval = the app's interval. The peripheral log shows `SET_INTERVAL` then `READ_NOW`.
4. Home: chips fill right away (READ_NOW); new readings come at the interval.
5. *Read now* → the peripheral logs `READ_NOW`, a new reading arrives.
6. Water on the peripheral → moisture jumps on the next reading.
7. Bluetooth off on the main iPhone (Settings app, not Control Center) → "Bluetooth is off";
   on again → reconnects, `SET_INTERVAL` re-sent.
8. Out of range (walk away, or the peripheral device in a metal box) → Connecting…, after
   20 s "Sensor offline"; back in range → Connected, interval re-sent.
9. Kill and relaunch → reconnects to the remembered device without the picker.
10. Forget → "No sensor paired", no reconnect; the peripheral shows up in the picker again.
11. Switch to Simulated → the simulated history is intact and has no real readings; switch
    back → the real history is intact.
12. During all of the above: no crash and no `Incorrect actor executor` /
    `dispatch_assert_queue` in the console.

---

## 10. Decisions taken in this plan

1. Disconnects go through connection state, never as reading failures (no error overlay
   for a plant that's just out of range).
2. The CB client has no queue: reads/writes while not connected fail immediately.
3. On every connect: Device Info → `SET_INTERVAL` → `READ_NOW`; commands only for protocol 1.
4. "Offline" in the header after 20 s of trying to connect; the mood's offline rule stays.
5. Out-of-range reconnect = pending `connect` by identifier; scan by name only when the
   identifier is unknown to the phone.
6. Missing service/characteristic → `.incompatible`, no retry loop.
7. Mode switch rebuilds the graph at runtime (no "restart the app").
8. Simulated history keeps `PlantHistory.store`; sensor history uses `PlantHistory-Sensor.store`.
9. Forget clears with empty strings instead of adding `remove(forKey:)` to `DefaultsClient`.
10. Forget has no confirmation dialog: pairing again takes a few seconds.

---

## 11. Decisions

Answers to the open questions of the first draft.

1. **Default mode on first launch:** simulated until M8, then switch the default to the real
   sensor.
2. **Offline mood:** keep the 15-minute offline rule (data-driven). The header shows the
   connection state right away.
3. **Interval the app sends:** fixed 300 s, `-PlantReadingInterval <s>` in DEBUG only. Not
   user-adjustable.
4. **Background Bluetooth:** add the `bluetooth-central` background mode in S9.
5. **Settings screen design:** plain `Form` now, design pass later.
6. **Connection copy:** OK as written. Add an *Open Settings* button for "Bluetooth not
   allowed".
7. **Water button in sensor mode:** sends `READ_NOW` after about 10 s so moisture updates
   soon after watering.
8. **Test peripheral host:** iPhone 13 Pro (second phone) runs the test peripheral; the main
   app runs on iPhone 17 Pro. No Mac destination needed.
