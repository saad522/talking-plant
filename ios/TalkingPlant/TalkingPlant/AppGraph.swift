//
//  AppGraph.swift
//  TalkingPlant
//

import Combine
import Foundation
import PlantChat
import PlantChatiOS
import PlantDevice
import PlantDeviceiOS
import PlantFaceiOS
import PlantHistory
import PlantHistoryiOS
import PlantMonitor
import PlantMonitoriOS
import PlantShared
import SwiftUI

/// Everything the app shows for one mode (simulated plant or real sensor). A mode change builds a new graph.
@MainActor
final class AppGraph {
    let id = UUID()
    let mode: PlantDeviceMode
    let monitor: PlantMonitorView<PlantFaceView>
    let history: PlantHistoryView
    let chat: PlantChatView<PlantFaceView>
    let device: PlantDeviceView
    let devicePicker: PlantDevicePickerView
    /// A new calibration screen each time it is pushed, so it starts from the saved values.
    let makeCalibration: () -> PlantDeviceCalibrationView
    #if DEBUG
    let simulatedPlant: SimulatedPeripheralClient?
    #endif

    // Long-lived objects the graph keeps alive.
    private let sensor: CoreBluetoothPeripheralClient?
    private let moodNotifier: PlantMoodNotifier
    private let notificationClient: UserNotificationsPlantNotificationClient
    private let connectionSetup: PlantDeviceConnectionSetup?
    private let readNowScheduler: PlantDeviceReadNowScheduler

    init(
        mode: PlantDeviceMode,
        store: PlantReadingStore,
        defaults: DefaultsClient,
        voice: SproutVoice,
        haptics: PlantHapticsClient,
        actionHandler: @escaping (AppAction) -> Void
    ) {
        self.mode = mode

        let simulated: SimulatedPeripheralClient?
        let sensor: CoreBluetoothPeripheralClient?
        let client: any PeripheralClient & PeripheralConnectionClient
        let currentDate: () -> Date
        let calibration: () -> MoistureCalibration
        let calibrationLoader = LocalMoistureCalibrationLoader(defaults: defaults)
        switch mode {
        case .simulated:
            // The simulated clock continues from the last saved reading and the soil from its saved value.
            let plant = SimulatedPeripheralClient(
                startDate: Self.simulatedStartDate(continuingFrom: store),
                defaults: defaults
            )
            simulated = plant
            sensor = nil
            client = plant
            currentDate = { plant.currentDate }
            calibration = { SimulatedPeripheralClient.calibration }
        case .sensor:
            let central = CoreBluetoothPeripheralClient()
            simulated = nil
            sensor = central
            client = central
            currentDate = Date.init
            calibration = { calibrationLoader.load() }
        }
        self.sensor = sensor
        #if DEBUG
        simulatedPlant = simulated
        #endif

        let readings = LocalPlantReadingDecorator(
            decoratee: PeripheralPlantReadingLoader(client: client, calibration: calibration, currentDate: currentDate),
            store: store
        )
        let health = LocalPlantHealthLoader(
            store: store,
            profile: .houseplant,
            currentDate: currentDate,
            recheckInterval: 60,
            schedule: SimulatedPeripheralClient.repeatingTimer
        )

        let connection = PeripheralPlantDeviceConnectionLoader(client: client, schedule: SimulatedPeripheralClient.repeatingTimer)
        let commands = PeripheralPlantDeviceCommandSender(client: client)
        let deviceSettings = PlantDeviceSettings(defaults: defaults)
        let pairing = PeripheralPlantDevicePairingLoader(client: client, settings: deviceSettings)
        let readNow = PlantDeviceReadNowScheduler(commands: commands, schedule: SimulatedPeripheralClient.repeatingTimer)
        readNowScheduler = readNow

        let plantName = "Sprout"
        let settings = PlantPersonalitySettings(defaults: defaults)
        let historySummary = LocalPlantHistorySummaryLoader(store: store, currentDate: currentDate)
        let languageModel = Self.makeLanguageModel(historyLoader: historySummary)
        let factsLoader = LocalPlantVoiceFactsLoader(
            moodLoader: PlantHealthMoodLoaderAdapter(healthLoader: health),
            store: store,
            currentDate: currentDate
        )
        let lineLoader = LanguageModelPlantVoiceLineLoader(
            client: languageModel.client,
            personality: { settings.load() },
            plantName: plantName
        )
        let chatLoader = LanguageModelPlantChatLoader(
            client: languageModel.client,
            personality: { settings.load() },
            plantName: plantName
        )

        monitor = PlantMonitorUIComposer.composed(
            with: readings,
            healthLoader: health,
            connectionLoader: PlantDeviceConnectionLoaderAdapter(loader: connection),
            speechLoader: PlantVoiceSpeechLoaderAdapter(lineLoader: lineLoader),
            plantName: plantName,
            room: "Living room",
            lastScene: PlantLastSceneStore(defaults: defaults),
            face: PlantFaceUIComposer.composed,
            haptics: haptics,
            clock: Date.init,
            schedule: SimulatedPeripheralClient.repeatingTimer,
            actionHandler: { action in
                switch (action, mode) {
                case (.waterTap, .sensor):
                    readNow.scheduleReadNow()
                case (.waterTap, .simulated):
                    #if DEBUG
                    simulated?.water()
                    #else
                    break
                    #endif
                case (.talkTap, _):
                    languageModel.prewarm()
                default:
                    break
                }
                actionHandler(.monitor(action))
            }
        )
        chat = PlantChatUIComposer.composed(
            chatLoader: chatLoader,
            lineLoader: lineLoader,
            factsLoader: factsLoader,
            settings: settings,
            transcriptLoader: TranscriberPlantTranscriptLoader(client: Self.makeTranscriberClient(plantName: plantName)),
            audioSession: AVAudioSessionPlantAudioSessionClient(),
            synthesizer: voice.synthesizer,
            spokenReplies: PlantSpokenReplySettings(defaults: defaults),
            plantName: plantName,
            face: PlantFaceUIComposer.composed,
            haptics: haptics,
            actionHandler: { action in
                if action == .openSettings, let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
                actionHandler(.chat(action))
            }
        )
        history = PlantHistoryUIComposer.composed(with: LocalPlantHistoryLoader(store: store, currentDate: currentDate), haptics: haptics)

        let deviceActionHandler = { (action: PlantDeviceAction) in
            if action == .openSettings, let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
            actionHandler(.device(action))
        }
        device = PlantDeviceUIComposer.composed(
            connectionLoader: connection,
            pairingLoader: pairing,
            infoLoader: PeripheralPlantDeviceInfoLoader(client: client),
            calibrationLoader: calibrationLoader,
            rawReadingLoader: PeripheralPlantDeviceRawReadingLoader(client: client, currentDate: currentDate),
            commandSender: commands,
            settings: deviceSettings,
            showsRawReading: Self.showsRawReading,
            haptics: haptics,
            actionHandler: deviceActionHandler
        )
        makeCalibration = {
            PlantDeviceUIComposer.composedCalibration(
                calibrationLoader: calibrationLoader,
                rawReadingLoader: PeripheralPlantDeviceRawReadingLoader(client: client, currentDate: currentDate),
                connectionLoader: connection,
                commandSender: commands,
                schedule: SimulatedPeripheralClient.repeatingTimer,
                haptics: haptics
            )
        }
        devicePicker = PlantDeviceUIComposer.composedPicker(
            scanLoader: PeripheralPlantDeviceScanLoader(client: client),
            connectionLoader: connection,
            pairingLoader: pairing,
            haptics: haptics,
            actionHandler: deviceActionHandler
        )

        // Notifications use the real clock, so the limit holds even though the simulated clock runs ahead.
        notificationClient = UserNotificationsPlantNotificationClient()
        moodNotifier = PlantMoodNotifier(
            factsLoader: factsLoader,
            lineLoader: lineLoader,
            notifications: notificationClient,
            defaults: defaults,
            plantName: plantName,
            currentDate: Date.init,
            minimumInterval: Self.notificationInterval,
            severityRanking: PlantHealthIssue.allCases.map(\.mood)
        )
        moodNotifier.start()

        if mode == .sensor {
            let setup = PlantDeviceConnectionSetup(
                connection: connection,
                infoLoader: PeripheralPlantDeviceInfoLoader(client: client),
                commands: commands,
                readingInterval: Self.readingInterval
            )
            connectionSetup = setup
            setup.start()
            pairing.connectSaved()
        } else {
            connectionSetup = nil
        }
    }

    /// Stops reconnecting. The old graph's sensor must not keep the connection once a new graph exists.
    func disconnect() {
        sensor?.disconnect()
    }

    // MARK: - Helpers

    /// The raw sensor values are a bring-up aid, so only DEBUG builds show them.
    private static var showsRawReading: Bool {
        #if DEBUG
        true
        #else
        false
        #endif
    }

    /// Five minutes between readings. DEBUG builds accept `-PlantReadingInterval <seconds>`.
    private static var readingInterval: UInt16 {
        #if DEBUG
        if let seconds = debugArgument("-PlantReadingInterval").flatMap(UInt16.init) {
            return seconds
        }
        #endif
        return 300
    }

    /// Reads `-Name value` from the launch arguments. Also accepts the pair as one argument
    /// (`"-Name value"`), which is how a scheme entry can arrive.
    private static func debugArgument(_ name: String) -> String? {
        let arguments = ProcessInfo.processInfo.arguments.flatMap { $0.split(separator: " ").map(String.init) }
        guard let index = arguments.firstIndex(of: name), arguments.indices.contains(index + 1) else { return nil }
        return arguments[index + 1]
    }

    /// One hour between notifications of the same mood. DEBUG builds accept `-PlantNotificationInterval <seconds>`.
    private static var notificationInterval: TimeInterval {
        #if DEBUG
        if let seconds = debugArgument("-PlantNotificationInterval").flatMap(TimeInterval.init) {
            return seconds
        }
        #endif
        return 60 * 60
    }

    /// DEBUG builds accept `-PlantSpeechUnsupported` to check keyboard-only mode in the simulator.
    private static func makeTranscriberClient(plantName: String) -> PlantTranscriberClient {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-PlantSpeechUnsupported") {
            return UnsupportedTranscriberClient()
        }
        #endif
        return SpeechAnalyzerPlantTranscriberClient(plantName: plantName)
    }

    /// The on-device model. DEBUG builds accept `-PlantVoiceUnavailable` to check the template fallback.
    private static func makeLanguageModel(
        historyLoader: PlantHistorySummaryLoader
    ) -> (client: PlantLanguageModelClient, prewarm: () -> Void) {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-PlantVoiceUnavailable") {
            return (UnavailableLanguageModelClient(), {})
        }
        #endif
        let client = FoundationModelsPlantLanguageModelClient(historyLoader: historyLoader)
        return (client, { client.prewarm() })
    }

    /// Continues the simulated clock from the last saved reading, so history stays continuous
    /// across relaunches. Starts today at 08:00 when nothing is saved yet.
    private static func simulatedStartDate(continuingFrom store: PlantReadingStore) -> Date {
        var lastReadingDate: Date?
        store.retrieve(from: .distantPast, to: .distantFuture) { result in
            lastReadingDate = (try? result.get())?.last?.receivedAt
        }
        return lastReadingDate ?? SimulatedPeripheralClient.defaultStartDate()
    }
}

/// A feature action, forwarded from a graph's views to the app.
enum AppAction {
    case monitor(PlantMonitorAction)
    case chat(PlantChatAction)
    case device(PlantDeviceAction)
}

/// Holds the current graph and swaps it when the mode changes.
@MainActor
final class AppGraphStore: ObservableObject {
    @Published private(set) var graph: AppGraph

    private final class ActionRelay {
        var handle: (AppAction) -> Void = { _ in }
    }

    private let navigation: AppNavigation
    private let defaults: DefaultsClient
    private let relay: ActionRelay
    let voice: SproutVoice
    private let haptics: PlantHapticsClient
    private var stores: [PlantDeviceMode: PlantReadingStore] = [:]

    init(navigation: AppNavigation, voice: SproutVoice, haptics: PlantHapticsClient, defaults: DefaultsClient = UserDefaultsClient()) {
        let relay = ActionRelay()
        let mode = PlantDeviceSettings(defaults: defaults).loadMode()
        let store = Self.makeStore(fileName: Self.fileName(for: mode))
        self.navigation = navigation
        self.defaults = defaults
        self.relay = relay
        self.voice = voice
        self.haptics = haptics
        stores[mode] = store
        graph = AppGraph(mode: mode, store: store, defaults: defaults, voice: voice, haptics: haptics, actionHandler: { relay.handle($0) })
        relay.handle = { [weak self] in self?.handle($0) }
    }

    private func handle(_ action: AppAction) {
        switch action {
        case .monitor(let action): navigation.handle(action)
        case .chat(let action): navigation.handle(action)
        case .device(.modeChanged(let mode)): switchMode(to: mode)
        case .device(.clearSensorHistory): clearSensorHistory()
        case .device(let action): navigation.handle(action)
        }
    }

    private func switchMode(to mode: PlantDeviceMode) {
        guard mode != graph.mode else { return }
        graph.disconnect()
        graph = makeGraph(mode: mode)
    }

    /// DEBUG bring-up aid. Only the sensor store is cleared, never the simulated one.
    private func clearSensorHistory() {
        stores[.sensor]?.deleteAll { _ in }
    }

    private func makeGraph(mode: PlantDeviceMode) -> AppGraph {
        AppGraph(mode: mode, store: store(for: mode), defaults: defaults, voice: voice, haptics: haptics, actionHandler: { [relay] in relay.handle($0) })
    }

    /// One store per mode, kept for the life of the app, so switching back never opens a second container on the same file.
    private func store(for mode: PlantDeviceMode) -> PlantReadingStore {
        if let store = stores[mode] { return store }
        let store = Self.makeStore(fileName: Self.fileName(for: mode))
        stores[mode] = store
        return store
    }

    private static func fileName(for mode: PlantDeviceMode) -> String {
        mode == .simulated ? "PlantHistory.store" : "PlantHistory-Sensor.store"
    }

    private static func makeStore(fileName: String) -> PlantReadingStore {
        let directory = URL.applicationSupportDirectory
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            return try SwiftDataPlantReadingStore(storeURL: directory.appending(path: fileName))
        } catch {
            // History is lost on relaunch, but the app keeps working.
            return try! SwiftDataPlantReadingStore(storeURL: nil)
        }
    }
}
