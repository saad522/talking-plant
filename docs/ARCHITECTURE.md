# Architecture

The Talking Plant follows a **composable architecture with vertical slicing**. Every
feature is self-contained, independently testable, and split into a platform-agnostic
business target and a UI target. Dependencies are injected manually by **UIComposers**,
and the app target is the only place that knows which concrete implementations are used.

Read this document before starting any milestone. When it conflicts with anything else in
the repo, this document wins.

---

## 1. Principles

1. **Vertical slicing.** A slice is a *feature* (e.g. `PlantMonitor`), not a technical
   layer. A feature contains its models, loaders, mappers, view models, stores, views,
   and composers.
2. **Two targets per feature.**
   - `Feature` (e.g. `PlantMonitor`): business logic only. No SwiftUI, no UIKit.
     Folders: `Domain`, `API`, `Persistence`, `Presentation`.
   - `FeatureiOS` (e.g. `PlantMonitoriOS`): UI only. Folders: `Stores`, `Views`,
     `Composers`, `Styles`.
3. **Same protocol, different implementations.** Every data source sits behind a loader
   protocol. The real Bluetooth sensor, the simulated plant, and local storage all
   implement the same protocols, and the composition decides which one is used.
4. **The AI never does the math.** Health, mood, and alerts are deterministic business
   logic with unit tests. Foundation Models only turns an already-computed state into words.
5. **Shared code is promoted, not planned.** Something moves into `PlantShared` only when a
   second feature needs it. Until then it lives in the feature that uses it.

---

## 2. Package and folder structure

```
ios/
├── TalkingPlant/                      # Xcode project: the app target = composition root
│   ├── TalkingPlant.xcodeproj
│   └── TalkingPlant/
│       └── TalkingPlantApp.swift      # creates clients/loaders, composes features, handles Actions
└── PlantKit/                          # local Swift package
    ├── Package.swift
    ├── Sources/
    │   ├── PlantShared/               # used by more than one feature
    │   │   ├── Contract/              # PlantBluetoothContract, PlantCharacteristic
    │   │   ├── Client/                # PeripheralClient, SimulatedPeripheralClient, CoreBluetoothPeripheralClient,
    │   │   │                          # PlantReadingStore, SwiftDataPlantReadingStore
    │   │   ├── Domain/                # MoistureCalibration, PlantReading
    │   │   └── Presentation/          # PlantReadingFormatter
    │   ├── PlantMonitor/              # Feature: live readings, health, mood
    │   │   ├── Domain/
    │   │   ├── API/
    │   │   ├── Persistence/
    │   │   ├── Presentation/
    │   │   └── Resources/en.lproj/PlantMonitor.strings
    │   ├── PlantMonitoriOS/           # FeatureiOS
    │   │   ├── Stores/
    │   │   ├── Views/
    │   │   ├── Composers/
    │   │   └── Styles/                # PlantMonitorFont, PlantMonitorColor
    │   ├── PlantDevice/               # Feature: device info, commands, calibration, pairing
    │   │   ├── Domain/
    │   │   └── API/
    │   ├── PlantHistory/              # Feature: stored readings, downsampled for charts
    │   │   ├── Domain/
    │   │   ├── API/
    │   │   ├── Presentation/
    │   │   └── Resources/en.lproj/PlantHistory.strings
    │   └── PlantHistoryiOS/           # FeatureiOS: Swift Charts
    │       ├── Stores/
    │       ├── Views/
    │       ├── Composers/
    │       └── Styles/
    └── Tests/
        ├── PlantSharedTests/
        ├── PlantMonitorTests/         # unit tests, run on macOS
        ├── PlantMonitoriOSTests/      # integration tests from the UIComposer
        ├── PlantDeviceTests/
        ├── PlantHistoryTests/
        └── PlantHistoryiOSTests/
```

Later features follow the same pattern: `PlantChat` / `PlantChatiOS`, `PlantDeviceiOS`.

### Target dependency rules

| Target | May import |
|---|---|
| `PlantShared` | Foundation (and CoreBluetooth / SwiftData inside `Client/` only) |
| `PlantX` (Feature) | Foundation, `PlantShared` (and a system framework such as FoundationModels, UserNotifications, Speech or AVFoundation inside its own `Client/` folder only) |
| `PlantXiOS` | SwiftUI, `PlantX`, `PlantShared` |
| `PlantXTests` | XCTest, `PlantX`, `PlantShared` |
| `PlantXiOSTests` | XCTest, ViewInspector, `PlantXiOS`, `PlantX`, `PlantShared` |
| App target | everything; it is the composition root |

A Feature target never imports another Feature target. When one feature needs another
feature's view, it receives it as a generic view through a factory closure (section 5.4).

### Package.swift outline

```swift
// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "PlantKit",
    defaultLocalization: "en",
    platforms: [.iOS(.v26), .macOS(.v15)],
    products: [
        .library(name: "PlantShared", targets: ["PlantShared"]),
        .library(name: "PlantMonitor", targets: ["PlantMonitor"]),
        .library(name: "PlantMonitoriOS", targets: ["PlantMonitoriOS"]),
        .library(name: "PlantDevice", targets: ["PlantDevice"])
    ],
    dependencies: [
        .package(url: "https://github.com/nalexn/ViewInspector", from: "0.10.0")
    ],
    targets: [
        .target(name: "PlantShared"),
        .target(name: "PlantMonitor", dependencies: ["PlantShared"], resources: [.process("Resources")]),
        .target(name: "PlantMonitoriOS", dependencies: ["PlantMonitor", "PlantShared"]),
        .target(name: "PlantDevice", dependencies: ["PlantShared"]),
        .testTarget(name: "PlantSharedTests", dependencies: ["PlantShared"]),
        .testTarget(name: "PlantMonitorTests", dependencies: ["PlantMonitor", "PlantShared"]),
        .testTarget(
            name: "PlantMonitoriOSTests",
            dependencies: ["PlantMonitoriOS", "PlantMonitor", "PlantShared", "ViewInspector"]
        ),
        .testTarget(name: "PlantDeviceTests", dependencies: ["PlantDevice", "PlantShared"])
    ]
)
```

ViewInspector is the only third-party dependency, and only test targets use it.

`FeatureiOS` targets must keep compiling on macOS (SwiftUI only, no UIKit), so
`swift test` keeps working. If an iOS-only API is ever needed, wrap it in `#if os(iOS)`.

---

## 3. Swift 6 adaptations

The project builds in Swift 6 language mode with strict concurrency. The architecture
stays the same; these are the only deliberate differences from a Swift 5 codebase:

1. **`@MainActor` replaces `MainQueueDispatchDecorator`.** Loader protocols, clients,
   loaders, view models, stores, and composers are `@MainActor`. The compiler then
   guarantees what the dispatch decorator used to guarantee at runtime: every completion
   reaches the view model and store on the main thread. The decorator pattern itself stays
   (calibration, storage, in-memory caching are decorators), only the threading decorator
   is gone.
2. **Platform clients deliver on the main actor.** `CoreBluetoothPeripheralClient` creates
   its `CBCentralManager` with `queue: nil` (main queue). Its delegate methods are
   `nonisolated` and forward with `MainActor.assumeIsolated { ... }`.
3. **Domain models are `Sendable`** in addition to `Equatable`. Structs of value types get
   this for free.
4. **Completion handlers stay.** Loaders keep the `completion: @escaping (Result) -> Void`
   style. Because everything involved is on the main actor, these closures don't need
   `@Sendable`.
5. **Resources use `Bundle.module`.** Each Feature target exposes a public bundle accessor
   (e.g. `PlantMonitorBundle.bundle`) so test targets can read the same strings table,
   replacing the `BundleClass` trick used in Xcode framework targets.
6. **Test classes are `@MainActor`.** If the compiler complains about the capture in
   `trackMemoryLeak`, use the `@MainActor` teardown block overload; keep the behavior.

---

## 4. Business layer (Feature target)

### 4.1 Domain models

Plain structs, `Equatable` + `Sendable` (and `Identifiable` / `Hashable` when needed),
explicit public inits, every type prefixed with the feature name. No UI types, no
Bluetooth types.

```swift
public struct PlantReading: Equatable, Sendable {
    public let moisture: Double?          // %, already calibrated
    public let lux: Int?
    public let temperature: Double?       // °C
    public let humidity: Double?          // %RH
    public let batteryMillivolts: Int?
    public let sequence: UInt32
    public let receivedAt: Date

    public init(
        moisture: Double?,
        lux: Int?,
        temperature: Double?,
        humidity: Double?,
        batteryMillivolts: Int?,
        sequence: UInt32,
        receivedAt: Date
    ) {
        self.moisture = moisture
        self.lux = lux
        self.temperature = temperature
        self.humidity = humidity
        self.batteryMillivolts = batteryMillivolts
        self.sequence = sequence
        self.receivedAt = receivedAt
    }
}
```

Each feature also has an **Action enum** for everything that leaves the feature
(navigation, dismissal, events the app reacts to):

```swift
public enum PlantMonitorAction: Equatable {
    case historyTap
    case dismissed
}
```

### 4.2 Loader protocols

Loader protocols define data access with `typealias` result types and completion
handlers. One-shot loads use `load(completion:)`; continuous data uses
`subscribe(update:)`, which can be called back many times.

```swift
@MainActor
public protocol PlantReadingLoader {
    typealias Result = Swift.Result<PlantReading, Error>

    func load(completion: @escaping (Result) -> Void)
    func subscribe(update: @escaping (Result) -> Void)
}
```

### 4.3 Clients (in PlantShared)

Clients are the boundary to the outside world, the equivalent of an `HTTPClient`. Loaders
depend on the client protocol, never on CoreBluetooth or `UserDefaults` directly.

```swift
@MainActor
public protocol PeripheralClient {
    typealias Result = Swift.Result<Data, Error>
    typealias WriteResult = Error?

    func read(_ characteristic: PlantCharacteristic, completion: @escaping (Result) -> Void)
    func subscribe(to characteristic: PlantCharacteristic, update: @escaping (Result) -> Void)
    func write(_ data: Data, to characteristic: PlantCharacteristic, completion: @escaping (WriteResult) -> Void)
}
```

Implementations:

| Client | Role |
|---|---|
| `CoreBluetoothPeripheralClient` | The real sensor over Bluetooth (M6). |
| `SimulatedPeripheralClient` | The fake plant used until the hardware arrives and as a demo mode. It produces **real 16-byte packets** per `BLE_CONTRACT.md`, so everything above it runs the exact production path. |
| `DefaultsClient` (+ `UserDefaultsClient`) | Small key-value storage (calibration, preferences, the simulated plant's soil value). |
| `PlantReadingStore` (+ `SwiftDataPlantReadingStore`) | Reading history: insert, retrieve a date range, and notify subscribers after each insert. Keeps 30 days, measured from the newest reading (M3). |

Because the simulated plant is a *client*, not a loader, there is one data path:
client → loader → mapper → view model, for both the simulated and the real sensor.

### 4.4 API: loaders and mappers

The loader talks to the client and hands raw data to a mapper. It maps client failures to
`.connectivity` and uses closures for values read at call time (calibration, current date).

```swift
@MainActor
public final class PeripheralPlantReadingLoader: PlantReadingLoader {
    private let client: PeripheralClient
    private let calibration: () -> MoistureCalibration
    private let currentDate: () -> Date

    public enum Error: Swift.Error, Equatable {
        case connectivity
        case invalidData
    }

    public init(
        client: PeripheralClient,
        calibration: @escaping () -> MoistureCalibration,
        currentDate: @escaping () -> Date = Date.init
    ) {
        self.client = client
        self.calibration = calibration
        self.currentDate = currentDate
    }

    public func load(completion: @escaping (PlantReadingLoader.Result) -> Void) {
        client.read(.readings) { [calibration, currentDate] result in
            completion(Self.map(result, receivedAt: currentDate(), calibration: calibration()))
        }
    }

    public func subscribe(update: @escaping (PlantReadingLoader.Result) -> Void) {
        client.subscribe(to: .readings) { [calibration, currentDate] result in
            update(Self.map(result, receivedAt: currentDate(), calibration: calibration()))
        }
    }

    private static func map(
        _ result: PeripheralClient.Result,
        receivedAt: Date,
        calibration: MoistureCalibration
    ) -> PlantReadingLoader.Result {
        switch result {
        case .success(let data):
            return PlantReadingLoader.Result(catching: {
                try PlantReadingMapper.map(data, receivedAt: receivedAt, calibration: calibration)
            })
        case .failure:
            return .failure(Error.connectivity)
        }
    }
}
```

Loaders never capture `self` in client callbacks, so a released loader is never kept alive
by its client (verified by the memory leak tests).

**Mappers** are internal `enum` namespaces with a private `Remote…` type mirroring the raw
format exactly, a conversion to the domain model, and one static `map(...) throws` entry
point. Mappers are pure: no state, no side effects.

```swift
enum PlantReadingMapper {
    private struct RemoteReading {
        private enum Flag: UInt8 {
            case soil = 0b0001
            case light = 0b0010
            case environment = 0b0100
            case battery = 0b1000
        }

        let version: UInt8
        private let flags: UInt8
        private let soilMillivolts: UInt16
        private let lux: UInt16
        private let temperatureCenti: Int16
        private let humidityCenti: UInt16
        private let batteryMillivolts: UInt16
        private let sequence: UInt32

        init?(data: Data) {
            guard data.count == PlantBluetoothContract.readingLength else { return nil }
            let bytes = [UInt8](data)
            version = bytes[0]
            flags = bytes[1]
            soilMillivolts = bytes.uint16(at: 2)
            lux = bytes.uint16(at: 4)
            temperatureCenti = Int16(bitPattern: bytes.uint16(at: 6))
            humidityCenti = bytes.uint16(at: 8)
            batteryMillivolts = bytes.uint16(at: 10)
            sequence = bytes.uint32(at: 12)
        }

        func local(receivedAt: Date, calibration: MoistureCalibration) -> PlantReading {
            PlantReading(
                moisture: has(.soil) ? calibration.moisturePercent(soilMillivolts: Int(soilMillivolts)) : nil,
                lux: has(.light) ? Int(lux) : nil,
                temperature: has(.environment) ? Double(temperatureCenti) / 100 : nil,
                humidity: has(.environment) ? Double(humidityCenti) / 100 : nil,
                batteryMillivolts: has(.battery) ? Int(batteryMillivolts) : nil,
                sequence: sequence,
                receivedAt: receivedAt
            )
        }

        private func has(_ flag: Flag) -> Bool {
            flags & flag.rawValue != 0
        }
    }

    static func map(_ data: Data, receivedAt: Date, calibration: MoistureCalibration) throws -> PlantReading {
        guard let reading = RemoteReading(data: data),
              reading.version == PlantBluetoothContract.protocolVersion else {
            throw PeripheralPlantReadingLoader.Error.invalidData
        }

        return reading.local(receivedAt: receivedAt, calibration: calibration)
    }
}

private extension Array where Element == UInt8 {
    func uint16(at offset: Int) -> UInt16 {
        UInt16(self[offset]) | UInt16(self[offset + 1]) << 8
    }

    func uint32(at offset: Int) -> UInt32 {
        (0..<4).reduce(UInt32(0)) { value, index in
            value | UInt32(self[offset + index]) << (8 * index)
        }
    }
}
```

Adjust `moisturePercent(soilMillivolts:)` to the parameter type of the existing
`MoistureCalibration`; don't change the calibration's behavior.

### 4.5 Persistence: decorators

Local storage is added by **decorating** a loader that implements the same protocol, with
storage behind a client protocol and private `Local…` types plus `toLocal()` / `toModel()`
conversions. Examples planned:

- `LocalPlantReadingDecorator` (M3): forwards readings and stores each one in the history
  store.
- `LocalMoistureCalibrationLoader` (M8): reads and saves calibration through `DefaultsClient`.

Other decorators follow the same idea: `InMemory…Decorator` for caching, `…Composite`
for "try primary, then fall back to secondary".

### 4.6 Presentation: view models

View models live in the Feature target and never import SwiftUI.

- `@MainActor public final class`, with `typealias Observer<T> = (T) -> Void`.
- Many **small, specific observers** named after what happened: `loadedReading`,
  `loadedError`, `loadedMood`…
- Inputs are verbs: `appear()`, `historyTap()`, `retryTap()`. Guard repeated `appear()`.
- Leaving the feature goes through `actionHandler: (PlantMonitorAction) -> Void`.
- Error handling: specific errors map to specific observers or actions.

```swift
@MainActor
public final class PlantMonitorViewModel {
    public typealias Observer<T> = (T) -> Void

    private let loader: PlantReadingLoader
    private let actionHandler: (PlantMonitorAction) -> Void
    private var appeared: Bool = false

    public let historyLabel: String = String.localised(key: "plant.monitor.history.label")

    public var loadedReading: Observer<PlantReading>?
    public var loadedError: Observer<Error>?

    public init(loader: PlantReadingLoader, actionHandler: @escaping (PlantMonitorAction) -> Void) {
        self.loader = loader
        self.actionHandler = actionHandler
    }

    public func appear() {
        guard appeared == false else { return }
        appeared = true
        loader.subscribe { [weak self] result in
            switch result {
            case .success(let reading):
                self?.loadedReading?(reading)
            case .failure(let error):
                self?.loadedError?(error)
            }
        }
    }

    public func historyTap() {
        actionHandler(.historyTap)
    }
}
```

**Small presentation view models** take a domain model in their init and expose
ready-to-display strings as `let` properties, so views only render:

```swift
public enum PlantSensorKind: Equatable, CaseIterable {
    case moisture
    case light
    case temperature
    case humidity
}

public final class PlantSensorCardViewModel {
    public let title: String
    public let value: String

    public init(kind: PlantSensorKind, reading: PlantReading) {
        self.title = switch kind {
        case .moisture: String.localised(key: "plant.monitor.moisture.title")
        case .light: String.localised(key: "plant.monitor.light.title")
        case .temperature: String.localised(key: "plant.monitor.temperature.title")
        case .humidity: String.localised(key: "plant.monitor.humidity.title")
        }
        self.value = switch kind {
        case .moisture: PlantMonitorFormatter.percent(reading.moisture)
        case .light: PlantMonitorFormatter.lux(reading.lux)
        case .temperature: PlantMonitorFormatter.temperature(reading.temperature)
        case .humidity: PlantMonitorFormatter.percent(reading.humidity)
        }
    }
}
```

The **error view model** turns errors into copy and tells the UI which kind of error it is:

```swift
@MainActor
public final class PlantMonitorErrorViewModel {
    public typealias Observer<T> = (T) -> Void

    private let error: Error
    private let actionHandler: (PlantMonitorAction) -> Void

    public var loadedConnection: Observer<Void>?
    public var loadedGeneral: Observer<Void>?

    public let description: String
    public let buttonTitle: String = String.localised(key: "plant.monitor.error.dismiss.label")

    public init(error: Error, actionHandler: @escaping (PlantMonitorAction) -> Void) {
        self.error = error
        self.actionHandler = actionHandler
        self.description = switch error {
        case PeripheralPlantReadingLoader.Error.connectivity:
            String.localised(key: "plant.monitor.connectivity.error.description")
        default:
            String.localised(key: "plant.monitor.general.error.description")
        }
    }

    public func appear() {
        switch error {
        case PeripheralPlantReadingLoader.Error.connectivity:
            loadedConnection?(())
        default:
            loadedGeneral?(())
        }
    }

    public func tap() {
        actionHandler(.dismissed)
    }
}
```

**Formatters** are internal `enum` namespaces with static functions and a fixed locale, so
output is predictable in tests:

```swift
enum PlantMonitorFormatter {
    static let placeholder = "–"
    private static let locale = Locale(identifier: "en_US")

    static func percent(_ value: Double?) -> String {
        guard let value else { return placeholder }
        return value.formatted(.number.precision(.fractionLength(0)).locale(locale)) + "%"
    }

    static func lux(_ value: Int?) -> String {
        guard let value else { return placeholder }
        return value.formatted(.number.locale(locale)) + " lx"
    }

    static func temperature(_ value: Double?) -> String {
        guard let value else { return placeholder }
        return value.formatted(.number.precision(.fractionLength(1)).locale(locale)) + " °C"
    }
}
```

**Localisation:** all user-facing text goes through `String.localised(key:)` with dotted
keys (`plant.monitor.moisture.title`), one strings table per feature:

```swift
public enum PlantMonitorBundle {
    public static let bundle: Bundle = .module
}

extension String {
    static func localised(key: String) -> String {
        NSLocalizedString(key, tableName: "PlantMonitor", bundle: PlantMonitorBundle.bundle, comment: "")
    }
}
```

---

## 5. UI layer (FeatureiOS target)

### 5.1 Stores

Internal `@MainActor` `ObservableObject` classes. `@Published` properties hold
**ready-made views, texts, colors, and images**, not raw data. Loading starts as a
skeleton by default. Stores are the single source of truth for the UI state.

```swift
import SwiftUI

@MainActor
final class PlantMonitorStore: ObservableObject {
    @Published var moisture: PlantSensorCardView?
    @Published var light: PlantSensorCardView?
    @Published var temperature: PlantSensorCardView?
    @Published var humidity: PlantSensorCardView?
    @Published var loading: LoadingSkeletonView? = LoadingSkeletonView()
    @Published var error: PlantMonitorErrorView?
}
```

Embedded views from other features are wrapped so `.id()` forces SwiftUI to rebuild them:

```swift
struct DetailsView<T: View>: Identifiable {
    let id: UUID = UUID()
    let view: T
}
```

### 5.2 Views

Public structs with **internal inits** (only composers create them). They hold
`@ObservedObject store` + `viewModel`, render whatever the store holds, send user actions
to view model methods, and call `onAppear(perform: viewModel.appear)`. Views contain zero
business logic; layout and animation only.

```swift
import PlantMonitor
import SwiftUI

public struct PlantMonitorView: View {
    @ObservedObject private var store: PlantMonitorStore
    private let viewModel: PlantMonitorViewModel

    init(store: PlantMonitorStore, viewModel: PlantMonitorViewModel) {
        self.store = store
        self.viewModel = viewModel
    }

    public var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    store.moisture
                    store.light
                    store.temperature
                    store.humidity
                }

                Button(action: viewModel.historyTap) {
                    Text(viewModel.historyLabel)
                        .font(PlantMonitorFont.button)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(16)
        }
        .overlay { store.loading }
        .overlay { store.error }
        .onAppear(perform: viewModel.appear)
    }
}

public struct PlantSensorCardView: View {
    private let viewModel: PlantSensorCardViewModel

    init(viewModel: PlantSensorCardViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(viewModel.title)
                .font(PlantMonitorFont.caption)
                .foregroundStyle(PlantMonitorColor.secondaryText)
            Text(viewModel.value)
                .font(PlantMonitorFont.value)
                .foregroundStyle(PlantMonitorColor.primaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(PlantMonitorColor.cardBackground, in: RoundedRectangle(cornerRadius: 16))
    }
}
```

Sub-components follow the same pairing of store + view model:

```swift
@MainActor
final class PlantMonitorErrorStore: ObservableObject {
    @Published var icon: Image?
}

public struct PlantMonitorErrorView: View {
    @ObservedObject private var store: PlantMonitorErrorStore
    private let viewModel: PlantMonitorErrorViewModel

    init(store: PlantMonitorErrorStore, viewModel: PlantMonitorErrorViewModel) {
        self.store = store
        self.viewModel = viewModel
    }

    public var body: some View {
        ZStack {
            Rectangle()
                .fill(PlantMonitorColor.background)
                .ignoresSafeArea()
            VStack(alignment: .center, spacing: 24) {
                store.icon
                    .font(PlantMonitorFont.icon)
                    .foregroundStyle(PlantMonitorColor.secondaryText)
                Text(viewModel.description)
                    .font(PlantMonitorFont.body)
                    .foregroundStyle(PlantMonitorColor.primaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                Button(action: viewModel.tap) {
                    Text(viewModel.buttonTitle)
                        .font(PlantMonitorFont.button)
                }
            }
        }
        .onAppear(perform: viewModel.appear)
    }
}
```

Generic loading views (`LoadingSkeletonView`, `LoadingTransparentView`) live in the
FeatureiOS target that first needs them and move to a `PlantSharediOS` target when a
second feature needs them too.

### 5.3 Composers

Public `@MainActor enum` with static `composed(...)` functions. A composer creates the
store and view model, connects **every observer to the store with `[weak store]`**, and
returns the configured view. **Visual decisions live here**: which icon an error shows,
which color a state uses. Sub-components get their own store + view model through private
`make…` helpers.

```swift
import PlantMonitor
import SwiftUI

@MainActor
public enum PlantMonitorUIComposer {
    public static func composed(
        with loader: PlantReadingLoader,
        actionHandler: @escaping (PlantMonitorAction) -> Void
    ) -> PlantMonitorView {
        let store = PlantMonitorStore()
        let viewModel = PlantMonitorViewModel(loader: loader, actionHandler: actionHandler)

        viewModel.loadedReading = { [weak store] reading in
            store?.loading = nil
            store?.error = nil
            store?.moisture = makeCard(.moisture, reading: reading)
            store?.light = makeCard(.light, reading: reading)
            store?.temperature = makeCard(.temperature, reading: reading)
            store?.humidity = makeCard(.humidity, reading: reading)
        }

        viewModel.loadedError = { [weak store] error in
            store?.loading = nil
            store?.error = makeError(for: error, actionHandler: actionHandler)
        }

        return PlantMonitorView(store: store, viewModel: viewModel)
    }

    private static func makeCard(_ kind: PlantSensorKind, reading: PlantReading) -> PlantSensorCardView {
        PlantSensorCardView(viewModel: PlantSensorCardViewModel(kind: kind, reading: reading))
    }

    private static func makeError(
        for error: Error,
        actionHandler: @escaping (PlantMonitorAction) -> Void
    ) -> PlantMonitorErrorView {
        let store = PlantMonitorErrorStore()
        let viewModel = PlantMonitorErrorViewModel(error: error, actionHandler: actionHandler)

        viewModel.loadedConnection = { [weak store] _ in
            store?.icon = Image(systemName: "antenna.radiowaves.left.and.right.slash")
        }

        viewModel.loadedGeneral = { [weak store] _ in
            store?.icon = Image(systemName: "exclamationmark.triangle")
        }

        return PlantMonitorErrorView(store: store, viewModel: viewModel)
    }
}
```

### 5.4 Embedding a view from another feature

A feature never imports another feature. It declares a generic view and receives a factory
closure through its composer; the app passes the other feature's composer in. Example for
M4, when the mood face becomes its own component:

```swift
public static func composed<Face: View>(
    with loader: PlantReadingLoader,
    face: @escaping (PlantMood) -> Face,
    actionHandler: @escaping (PlantMonitorAction) -> Void
) -> PlantMonitorView<Face>
```

The store then holds `@Published var face: DetailsView<Face>?`, and integration tests pass
an `Equatable` stub view for `Face`.

### 5.5 Styles

Feature-prefixed `enum`s with static constants: `PlantMonitorFont`, `PlantMonitorColor`.
Use **adaptive SwiftUI styles** that work in light and dark mode and compile on macOS
(`Color.primary`, `Color.secondary`, opacity variants, `BackgroundStyle` via `.background`),
never hard-coded UIKit colors and **no asset catalog colors**.

Why no asset catalog: FeatureiOS targets must keep building and testing with `swift test` on
macOS, and the SwiftPM command line does not reliably compile `.xcassets` the way Xcode
does. An asset color would then build in Xcode but be missing under `swift test`. SwiftUI's
semantic styles already adapt to light/dark mode and accessibility settings, so they cover
what the asset colors were for. A style that isn't a `Color` (like `BackgroundStyle`) is
drawn through a shape, e.g. `Rectangle().fill(PlantMonitorColor.background)`.

```swift
import SwiftUI

enum PlantMonitorFont {
    static let caption: Font = .system(size: 13, weight: .regular)
    static let body: Font = .system(size: 16, weight: .regular)
    static let value: Font = .system(size: 28, weight: .bold, design: .rounded)
    static let button: Font = .system(size: 16, weight: .semibold)
    static let icon: Font = .system(size: 40, weight: .regular)
}

enum PlantMonitorColor {
    static let primaryText: Color = .primary
    static let secondaryText: Color = .secondary
    static let background: BackgroundStyle = .background
    static let cardBackground: Color = .secondary.opacity(0.12)
}
```

**Fixed design colors are the exception** (DESIGN.md palettes). They are defined in code with
`Color(hex:)` in the feature's style enums, never in an asset catalog. The palette is chosen
by data (for example the monitor's scene), not by the system light / dark setting.

If any other custom color is ever needed, propose how to add it first.

---

## 6. Composition root (app target)

The app target is the only place that knows concrete types. It creates clients and
loaders, composes features **once** (not inside `body`), and handles every feature's
actions (navigation lives here).

```swift
import PlantMonitor
import PlantMonitoriOS
import PlantShared
import SwiftUI

@main
struct TalkingPlantApp: App {
    private let monitor: PlantMonitorView

    init() {
        let client = SimulatedPeripheralClient()
        let loader = PeripheralPlantReadingLoader(client: client, calibration: { .placeholder })
        monitor = PlantMonitorUIComposer.composed(with: loader, actionHandler: { _ in })
    }

    var body: some Scene {
        WindowGroup {
            monitor
        }
    }
}
```

Switching between the simulated plant and the real sensor is a decision made here, by
choosing which `PeripheralClient` to inject.

---

## 7. Testing

All tests use **XCTest**. View tests use **ViewInspector**.

### 7.1 Two kinds of tests

| Target | Kind | What it covers | Runs on |
|---|---|---|---|
| `PlantXTests` | Unit tests | Loaders, mappers, decorators, clients, view models | macOS (`swift test`), no simulator |
| `PlantXiOSTests` | Integration tests | The whole feature, **starting from the UIComposer**: loader stub → view model → store → rendered view | Simulator (Xcode / `xcodebuild`) |

### 7.2 Conventions

- **Naming:** `test_<trigger>_<expectedBehavior>`, e.g. `test_subscribe_deliversConnectivityErrorOnClientFailure`.
- **One base class per feature and test target** (`PlantMonitorXCTestCase`) holding shared
  helpers, factories, spies, and stubs. Test classes are `final`, subclass it, and are
  `@MainActor`.
- **`makeSUT(...)`** returns a tuple with the SUT and its collaborators, with default
  parameters for everything, and calls `trackMemoryLeak` on every object it creates.
- **Factories:** `anyNSError()`, `anyData()`, `anyDate()`, `makeReading(...)`,
  `makeReadingPacket(...)`, all with default parameters.
- **Test doubles:**
  - `ClientSpy` records `messages` in an `Equatable` enum and stores completions, so tests
    control timing with `completeRead(with:at:)` / `completeSubscription(with:at:)`.
  - `LoaderStub` does the same for loader protocols; one stub may implement several.
  - `DefaultsSpy` records `set` / `retrieve` and lets tests stub retrieved values.
- **`expect(...)` helpers** live in `PlantMonitorXCTestCase+Expect.swift`, one per loader
  protocol, comparing results case by case and failing with a clear message.
- **Memory leaks:** every `makeSUT` tracks its objects, and each loader has a
  `test_<method>_doesNotCreateMemoryLeaks` test releasing the SUT after a pending call.
- **Assertion helpers** pass `file:` and `line:` through.

### 7.3 Base class and spies

```swift
import PlantMonitor
import PlantShared
import XCTest

@MainActor
class PlantMonitorXCTestCase: XCTestCase {
    func anyNSError() -> NSError {
        NSError(domain: "any", code: 1)
    }

    func anyDate() -> Date {
        Date(timeIntervalSince1970: 1_000)
    }

    func makeReading(
        moisture: Double? = 50,
        lux: Int? = 1_000,
        temperature: Double? = 23.5,
        humidity: Double? = 55.2,
        batteryMillivolts: Int? = nil,
        sequence: UInt32 = 42,
        receivedAt: Date = Date(timeIntervalSince1970: 1_000)
    ) -> PlantReading {
        PlantReading(
            moisture: moisture,
            lux: lux,
            temperature: temperature,
            humidity: humidity,
            batteryMillivolts: batteryMillivolts,
            sequence: sequence,
            receivedAt: receivedAt
        )
    }

    func makeReadingPacket(
        version: UInt8 = 1,
        flags: UInt8 = 0b0111,
        soilMillivolts: UInt16 = 2_500,
        lux: UInt16 = 1_000,
        temperatureCenti: Int16 = 2_350,
        humidityCenti: UInt16 = 5_520,
        batteryMillivolts: UInt16 = 0,
        sequence: UInt32 = 42
    ) -> Data {
        var data = Data([version, flags])
        [soilMillivolts, lux, UInt16(bitPattern: temperatureCenti), humidityCenti, batteryMillivolts]
            .forEach { value in withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) } }
        withUnsafeBytes(of: sequence.littleEndian) { data.append(contentsOf: $0) }
        return data
    }

    func trackMemoryLeak(_ instance: AnyObject, file: StaticString = #filePath, line: UInt = #line) {
        addTeardownBlock { [weak instance] in
            XCTAssertNil(instance, "Instance should be deallocated. Potential memory leak", file: file, line: line)
        }
    }

    @MainActor
    final class ClientSpy: PeripheralClient {
        enum Message: Equatable {
            case read(PlantCharacteristic)
            case subscribe(PlantCharacteristic)
            case write(Data, PlantCharacteristic)
        }

        var messages: [Message] = []

        private var readCompletions: [(PeripheralClient.Result) -> Void] = []
        func read(_ characteristic: PlantCharacteristic, completion: @escaping (PeripheralClient.Result) -> Void) {
            messages.append(.read(characteristic))
            readCompletions.append(completion)
        }

        func completeRead(with data: Data, at index: Int = 0) {
            readCompletions[index](.success(data))
        }

        func completeRead(with error: Error, at index: Int = 0) {
            readCompletions[index](.failure(error))
        }

        private var subscriptions: [(PeripheralClient.Result) -> Void] = []
        func subscribe(to characteristic: PlantCharacteristic, update: @escaping (PeripheralClient.Result) -> Void) {
            messages.append(.subscribe(characteristic))
            subscriptions.append(update)
        }

        func completeSubscription(with data: Data, at index: Int = 0) {
            subscriptions[index](.success(data))
        }

        func completeSubscription(with error: Error, at index: Int = 0) {
            subscriptions[index](.failure(error))
        }

        private var writeCompletions: [(PeripheralClient.WriteResult) -> Void] = []
        func write(_ data: Data, to characteristic: PlantCharacteristic, completion: @escaping (PeripheralClient.WriteResult) -> Void) {
            messages.append(.write(data, characteristic))
            writeCompletions.append(completion)
        }

        func completeWrite(with error: Error?, at index: Int = 0) {
            writeCompletions[index](error)
        }
    }

    @MainActor
    final class LoaderStub: PlantReadingLoader {
        enum Message: Equatable {
            case loadReading
            case subscribeReadings
        }

        var messages: [Message] = []

        private var loadCompletions: [(PlantReadingLoader.Result) -> Void] = []
        func load(completion: @escaping (PlantReadingLoader.Result) -> Void) {
            messages.append(.loadReading)
            loadCompletions.append(completion)
        }

        private var subscriptions: [(PlantReadingLoader.Result) -> Void] = []
        func subscribe(update: @escaping (PlantReadingLoader.Result) -> Void) {
            messages.append(.subscribeReadings)
            subscriptions.append(update)
        }

        func completeSubscription(with reading: PlantReading, at index: Int = 0) {
            subscriptions[index](.success(reading))
        }

        func completeSubscription(with error: Error, at index: Int = 0) {
            subscriptions[index](.failure(error))
        }
    }
}
```

### 7.4 Expect helper

```swift
extension PlantMonitorXCTestCase {
    func expect(
        reading sut: PlantReadingLoader,
        toDeliver expectedResult: PlantReadingLoader.Result,
        when action: () -> Void,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let exp = expectation(description: "wait for reading")

        sut.subscribe { result in
            switch (expectedResult, result) {
            case let (.success(expected), .success(received)):
                XCTAssertEqual(expected, received, file: file, line: line)
            case let (.failure(expected as PeripheralPlantReadingLoader.Error), .failure(received as PeripheralPlantReadingLoader.Error)):
                XCTAssertEqual(expected, received, file: file, line: line)
            case let (.failure(expected as NSError), .failure(received as NSError)):
                XCTAssertEqual(expected, received, file: file, line: line)
            default:
                XCTFail("Expected \(expectedResult), got \(result) instead", file: file, line: line)
            }

            exp.fulfill()
        }

        action()

        wait(for: [exp], timeout: 1.0)
    }
}
```

### 7.5 Unit test example (loader)

```swift
@MainActor
final class PeripheralPlantReadingLoaderTests: PlantMonitorXCTestCase {
    func test_init_doesNotMessageClient() {
        let (_, client) = makeSUT()

        XCTAssertEqual(client.messages, [])
    }

    func test_subscribe_subscribesToReadingsOnClient() {
        let (sut, client) = makeSUT()

        sut.subscribe(update: { _ in })

        XCTAssertEqual(client.messages, [.subscribe(.readings)])
    }

    func test_subscribe_deliversConnectivityErrorOnClientFailure() {
        let (sut, client) = makeSUT()

        expect(
            reading: sut,
            toDeliver: .failure(PeripheralPlantReadingLoader.Error.connectivity),
            when: { client.completeSubscription(with: anyNSError()) }
        )
    }

    func test_subscribe_deliversInvalidDataErrorOnWrongPacketLength() {
        [0, 15, 17].forEach { length in
            let (sut, client) = makeSUT()

            expect(
                reading: sut,
                toDeliver: .failure(PeripheralPlantReadingLoader.Error.invalidData),
                when: { client.completeSubscription(with: Data(repeating: 1, count: length)) }
            )
        }
    }

    func test_subscribe_deliversReadingOnValidPacket() {
        let (sut, client) = makeSUT(currentDate: anyDate())
        let expected = PlantReading(
            moisture: MoistureCalibration.placeholder.moisturePercent(soilMillivolts: 2_500),
            lux: 1_000,
            temperature: 23.5,
            humidity: 55.2,
            batteryMillivolts: nil,
            sequence: 42,
            receivedAt: anyDate()
        )

        expect(
            reading: sut,
            toDeliver: .success(expected),
            when: { client.completeSubscription(with: makeReadingPacket()) }
        )
    }

    func test_subscribe_doesNotCreateMemoryLeaks() {
        let client = ClientSpy()
        var sut: PeripheralPlantReadingLoader? = PeripheralPlantReadingLoader(client: client, calibration: { .placeholder })
        weak var weakSUT: PeripheralPlantReadingLoader? = sut

        sut?.subscribe(update: { _ in })

        sut = nil
        XCTAssertNil(weakSUT, "Expect to release all references of SUT")
    }

    // MARK: - Private helpers

    private func makeSUT(
        currentDate: Date = Date(timeIntervalSince1970: 1_000),
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> (sut: PeripheralPlantReadingLoader, client: ClientSpy) {
        let client = ClientSpy()
        let sut = PeripheralPlantReadingLoader(client: client, calibration: { .placeholder }, currentDate: { currentDate })
        trackMemoryLeak(client, file: file, line: line)
        trackMemoryLeak(sut, file: file, line: line)
        return (sut, client)
    }
}
```

The full loader suite also covers: unsupported versions (0 and 2), each flag cleared
giving `nil`, negative temperatures and max values, every update being delivered, and the
fixture from `BLE_CONTRACT.md`.

### 7.6 Integration tests (from the UIComposer)

The iOS test base class composes the feature with a `LoaderStub` and `Equatable` stub views
for any injected child views:

```swift
@MainActor
class PlantMonitoriOSXCTestCase: XCTestCase {
    func makeSUT(
        actionHandler: @escaping (PlantMonitorAction) -> Void = { _ in },
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> (sut: PlantMonitorView, loader: LoaderStub) {
        let loader = LoaderStub()
        let sut = PlantMonitorUIComposer.composed(with: loader, actionHandler: actionHandler)
        trackMemoryLeak(loader, file: file, line: line)
        return (sut, loader)
    }

    // trackMemoryLeak, factories, and LoaderStub as in section 7.3
}
```

**ViewInspector extensions**, one file per view (`PlantMonitorView+ViewInspector.swift`),
expose readable accessors and simulations, so tests read like specifications:

```swift
import PlantMonitoriOS
import SwiftUI
import ViewInspector

extension PlantMonitorView {
    var isLoading: Bool {
        (try? inspect().find(LoadingSkeletonView.self)) != nil
    }

    func simulateAppear() {
        try? inspect().scrollView().callOnAppear()
    }

    func renderedCards() -> [PlantSensorCardView] {
        (try? inspect().findAll(PlantSensorCardView.self).map { try $0.actualView() }) ?? []
    }

    func renderedError() -> PlantMonitorErrorView? {
        try? inspect().find(PlantMonitorErrorView.self).actualView()
    }
}

extension PlantSensorCardView {
    var title: String? { try? inspect().vStack().text(0).string() }
    var value: String? { try? inspect().vStack().text(1).string() }
}

extension PlantMonitorErrorView {
    var description: String? { try? inspect().zStack().vStack(1).text(1).string() }

    func simulateTap() {
        try? inspect().zStack().vStack(1).button(2).tap()
    }
}
```

```swift
@MainActor
final class PlantMonitorUIITests: PlantMonitoriOSXCTestCase {
    func test_init_doesNotMessageLoader() {
        let (_, loader) = makeSUT()

        XCTAssertEqual(loader.messages, [])
    }

    func test_init_displaysLoading() {
        let (sut, _) = makeSUT()

        XCTAssertTrue(sut.isLoading)
    }

    func test_appear_subscribesToReadingsOnce() {
        let (sut, loader) = makeSUT()

        sut.simulateAppear()
        sut.simulateAppear()

        XCTAssertEqual(loader.messages, [.subscribeReadings])
    }

    func test_appear_rendersSensorCardsOnReading() {
        let (sut, loader) = makeSUT()
        let reading = makeReading(moisture: 42, lux: 1_200, temperature: 21.5, humidity: 60)

        sut.simulateAppear()
        loader.completeSubscription(with: reading)

        XCTAssertFalse(sut.isLoading)
        XCTAssertEqual(sut.renderedCards().map(\.value), ["42%", "1,200 lx", "21.5 °C", "60%"])
    }

    func test_appear_displaysConnectivityErrorOnFailure() {
        let (sut, loader) = makeSUT()

        sut.simulateAppear()
        loader.completeSubscription(with: PeripheralPlantReadingLoader.Error.connectivity)

        XCTAssertEqual(
            sut.renderedError()?.description,
            String.localised(key: "plant.monitor.connectivity.error.description")
        )
    }

    func test_error_deliversDismissedAction() {
        let exp = expectation(description: "wait for action")
        var invokedActions: [PlantMonitorAction] = []
        let (sut, loader) = makeSUT(actionHandler: {
            invokedActions.append($0)
            exp.fulfill()
        })

        sut.simulateAppear()
        loader.completeSubscription(with: anyNSError())
        sut.renderedError()?.simulateTap()
        wait(for: [exp], timeout: 1.0)

        XCTAssertEqual(invokedActions, [.dismissed])
    }
}
```

Test targets read strings through the feature's public bundle accessor:

```swift
extension String {
    static func localised(key: String) -> String {
        NSLocalizedString(key, tableName: "PlantMonitor", bundle: PlantMonitorBundle.bundle, comment: "")
    }
}
```

---

## 8. Adding a feature: checklist

1. **Pick the slice.** Does it belong to an existing feature? If not, create
   `PlantX` + `PlantXiOS` + their test targets in `Package.swift`.
2. **Domain:** models (`Equatable`, `Sendable`), the Action enum, loader protocols.
3. **API:** loader implementing the protocol through a client, plus a mapper. Unit tests
   first: init, request messages, connectivity error, invalid data, success, memory leaks.
4. **Persistence (if needed):** a decorator implementing the same protocol. Unit tests.
5. **Presentation:** view model with observers and an action handler, small view models,
   formatter, strings. Unit tests for anything with logic.
6. **UI:** store, views, styles, composer.
7. **Integration tests** from the composer, with ViewInspector extensions.
8. **Composition root:** wire it in the app target and handle its actions.

---

## 9. Naming conventions

| Kind | Pattern | Example |
|---|---|---|
| Domain model | `<Feature><Thing>` | `PlantReading`, `PlantMood` |
| Action enum | `<Feature>Action` | `PlantMonitorAction` |
| Loader protocol | `<Thing>Loader` | `PlantReadingLoader` |
| Bluetooth loader | `Peripheral<Thing>Loader` | `PeripheralPlantReadingLoader` |
| Mapper | `<Thing>Mapper` | `PlantReadingMapper` |
| Raw mirror type in a mapper | `Remote<Thing>` (private) | `RemoteReading` |
| Persistence decorator | `Local<Thing>Decorator` | `LocalPlantReadingDecorator` |
| Cache decorator | `InMemory<Thing>Decorator` | `InMemoryMoistureCalibrationDecorator` |
| Fallback composite | `<Thing>With<Primary>Composite` | `PlantReadingWithLocalComposite` |
| Client protocol / impl | `<Kind>Client` / `<Tech><Kind>Client` | `PeripheralClient` / `CoreBluetoothPeripheralClient` |
| Runtime fake | `Simulated<Kind>Client` | `SimulatedPeripheralClient` |
| View model | `<Feature><Component>ViewModel` | `PlantSensorCardViewModel` |
| Store / View | `<Feature><Component>Store` / `View` | `PlantMonitorStore` / `PlantMonitorView` |
| Composer | `<Feature>UIComposer` | `PlantMonitorUIComposer` |
| Styles | `<Feature>Font` / `<Feature>Color` | `PlantMonitorFont` |
| Formatter | `<Feature>Formatter` | `PlantMonitorFormatter` |
| Test base class | `<Feature>XCTestCase` / `<Feature>iOSXCTestCase` | `PlantMonitorXCTestCase` |
| Test doubles | `ClientSpy`, `LoaderStub`, `DefaultsSpy`, `<Name>Stub` views | `FaceStub` |
| Integration tests | `<Feature>UIITests` | `PlantMonitorUIITests` |
| String keys | `plant.<feature>.<thing>.<kind>` | `plant.monitor.moisture.title` |

---

## 10. Where the M1 code goes

| M1 type | New home |
|---|---|
| `PlantContract` (UUIDs, lengths, protocol version) | `PlantShared/Contract/PlantBluetoothContract` + `PlantCharacteristic` |
| `ReadingPacket` + `SensorReading` | `PlantMonitor/API/PlantReadingMapper` (private `RemoteReading`) + `PlantMonitor/Domain/PlantReading` |
| `MoistureCalibration` | `PlantShared/Domain/MoistureCalibration` (unchanged behavior) |
| `DeviceInfo` | `PlantDevice/Domain/PlantDeviceInfo` + `PlantDevice/API/PlantDeviceInfoMapper` |
| `PlantCommand` | `PlantDevice/Domain/PlantDeviceCommand` + `PlantDevice/API/PlantDeviceCommandMapper` |
| `PlantContractError` | Replaced by each loader's nested `Error` (`connectivity`, `invalidData`) |
| Swift Testing tests | XCTest, same cases, in the matching test target |

## 11. Milestones mapped to the architecture

| Milestone | Work |
|---|---|
| M2 | `SimulatedPeripheralClient` (PlantShared) + the `PlantMonitor` slice above: loader, mapper, view model, sensor cards, loading, error, composer, composition root |
| M3 | `PlantHistory` / `PlantHistoryiOS` + `LocalPlantReadingDecorator` with a SwiftData-backed store client (`PlantReading` and `PlantReadingFormatter` promoted to PlantShared) |
| M4 | Health and mood in `PlantMonitor` (deterministic, unit-tested) + the mood face as an embedded component |
| M5 | `PlantChat` / `PlantChatiOS`: Foundation Models voice, notifications, chat, template fallback |
| M6 | `CoreBluetoothPeripheralClient` + `PlantDevice` pairing and Device Info |
| M7 | Firmware (unchanged) |
| M8 | `PlantDeviceiOS` calibration screen + `LocalMoistureCalibrationLoader` |
| M9 | `PlantCheckup` / `PlantCheckupiOS`: leaf check-up from a photo. Vision plant segmentation, deterministic color analysis (green / yellow / brown ratios, dark spots) and diagnosis rules combining the photo result with sensor history (all unit-tested), saved past check-ups. Foundation Models only phrases the result as "this might be…" with a suggestion. Later: Create ML classifier on our own labeled photos, optional pot camera (XIAO ESP32S3 Sense) |
