//
//  TalkingPlantApp.swift
//  TalkingPlant
//
//  Created by Saad Saissi Hassani on 9/10/2026.
//

import Combine
import Foundation
import PlantChat
import PlantChatiOS
import PlantFaceiOS
import PlantHistory
import PlantHistoryiOS
import PlantMonitor
import PlantMonitoriOS
import PlantShared
import SwiftUI

@main
struct TalkingPlantApp: App {
    @StateObject private var navigation: AppNavigation
    private let monitor: PlantMonitorView<PlantFaceView>
    private let history: PlantHistoryView
    private let chat: PlantChatView<PlantFaceView>
    private let moodNotifier: PlantMoodNotifier
    private let notificationClient: UserNotificationsPlantNotificationClient
    #if DEBUG
    private let simulatedPlant: SimulatedPeripheralClient
    #endif

    init() {
        let store = Self.makeStore()
        // The simulated clock continues from the last saved reading and the soil from its saved value.
        let client = SimulatedPeripheralClient(
            startDate: Self.simulatedStartDate(continuingFrom: store),
            defaults: UserDefaultsClient()
        )
        // Simulated mode: readings and the history range use the simulated clock.
        let currentDate = { client.currentDate }

        let readings = LocalPlantReadingDecorator(
            decoratee: PeripheralPlantReadingLoader(client: client, calibration: { .placeholder }, currentDate: currentDate),
            store: store
        )
        let navigation = AppNavigation()

        let health = LocalPlantHealthLoader(
            store: store,
            profile: .houseplant,
            currentDate: currentDate,
            recheckInterval: 60,
            schedule: SimulatedPeripheralClient.repeatingTimer
        )

        let plantName = "Sprout"
        let defaults = UserDefaultsClient()
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
            speechLoader: PlantVoiceSpeechLoaderAdapter(lineLoader: lineLoader),
            plantName: plantName,
            room: "Living room",
            face: PlantFaceUIComposer.composed,
            actionHandler: { [weak navigation] action in
                #if DEBUG
                if action == .waterTap { client.water() }
                #endif
                if action == .talkTap { languageModel.prewarm() }
                navigation?.handle(action)
            }
        )
        chat = PlantChatUIComposer.composed(
            chatLoader: chatLoader,
            lineLoader: lineLoader,
            factsLoader: factsLoader,
            settings: settings,
            transcriptLoader: TranscriberPlantTranscriptLoader(client: Self.makeTranscriberClient()),
            audioSession: AVAudioSessionPlantAudioSessionClient(),
            synthesizer: AVSpeechPlantSynthesizerClient(),
            spokenReplies: PlantSpokenReplySettings(defaults: defaults),
            plantName: plantName,
            face: PlantFaceUIComposer.composed,
            actionHandler: { [weak navigation] action in
                if action == .openSettings, let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
                navigation?.handle(action)
            }
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
        history = PlantHistoryUIComposer.composed(with: LocalPlantHistoryLoader(store: store, currentDate: currentDate))
        _navigation = StateObject(wrappedValue: navigation)
        #if DEBUG
        simulatedPlant = client
        #endif
    }

    var body: some Scene {
        WindowGroup {
            NavigationStack(path: $navigation.path) {
                monitor
                    #if DEBUG
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Water") { simulatedPlant.water() }
                        }
                    }
                    #endif
                    .navigationDestination(for: AppNavigation.Route.self) { route in
                        switch route {
                        case .history: history
                        case .chat: chat
                        }
                    }
            }
        }
    }

    /// One hour between notifications of the same mood. DEBUG builds accept `-PlantNotificationInterval <seconds>`.
    private static var notificationInterval: TimeInterval {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if let index = arguments.firstIndex(of: "-PlantNotificationInterval"),
           arguments.indices.contains(index + 1),
           let seconds = TimeInterval(arguments[index + 1]) {
            return seconds
        }
        #endif
        return 60 * 60
    }

    /// DEBUG builds accept `-PlantSpeechUnsupported` to check keyboard-only mode in the simulator.
    private static func makeTranscriberClient() -> PlantTranscriberClient {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-PlantSpeechUnsupported") {
            return UnsupportedTranscriberClient()
        }
        #endif
        return SpeechAnalyzerPlantTranscriberClient()
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

    private static func makeStore() -> PlantReadingStore {
        let directory = URL.applicationSupportDirectory
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            return try SwiftDataPlantReadingStore(storeURL: directory.appending(path: "PlantHistory.store"))
        } catch {
            // History is lost on relaunch, but the app keeps working.
            return try! SwiftDataPlantReadingStore(storeURL: nil)
        }
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

@MainActor
final class AppNavigation: ObservableObject {
    enum Route: Hashable {
        case history
        case chat
    }

    @Published var path: [Route] = []

    func handle(_ action: PlantMonitorAction) {
        switch action {
        case .historyTap: path.append(.history)
        case .talkTap: path.append(.chat)
        case .waterTap, .dismissed: break
        }
    }

    func handle(_ action: PlantChatAction) {
        switch action {
        case .backTap: _ = path.popLast()
        case .openSettings: break
        }
    }
}

/// PlantChat's mood source, backed by the monitor's health loader.
@MainActor
struct PlantHealthMoodLoaderAdapter: PlantMoodLoader {
    let healthLoader: PlantHealthLoader

    func load(completion: @escaping (PlantMoodLoader.Result) -> Void) {
        healthLoader.load { result in
            completion(result.map { PlantMoodState(mood: $0.mood, problems: $0.issues.map(\.mood)) })
        }
    }

    func subscribe(update: @escaping () -> Void) {
        healthLoader.subscribe(update: update)
    }
}

/// The home speech bubble's source, backed by PlantChat's line loader.
@MainActor
struct PlantVoiceSpeechLoaderAdapter: PlantSpeechLoader {
    let lineLoader: PlantVoiceLineLoader

    func load(mood: PlantMood, isSleeping: Bool, reading: PlantReading?, completion: @escaping (PlantSpeechLoader.Result) -> Void) {
        let facts = PlantVoiceFacts(mood: mood, isSleeping: isSleeping, reading: reading, problems: [mood])
        lineLoader.load(PlantVoiceLineRequest(facts: facts, purpose: .home), completion: completion)
    }
}

#if DEBUG
/// Stands in for the model when the app is launched with `-PlantVoiceUnavailable`.
@MainActor
private struct UnavailableLanguageModelClient: PlantLanguageModelClient {
    let isAvailable = false

    func makeSession(instructions: String, canReadHistory: Bool) -> PlantLanguageModelSession {
        FailingSession()
    }

    private final class FailingSession: PlantLanguageModelSession {
        func respond(to prompt: String, completion: @escaping (PlantLanguageModelSession.Result) -> Void) {
            completion(.failure(PlantLanguageModelError.generation))
        }
    }
}
#endif

#if DEBUG
/// A transcriber that reports `.unsupported`, so the Talk screen is keyboard only.
@MainActor
struct UnsupportedTranscriberClient: PlantTranscriberClient {
    var authorization: PlantSpeechAuthorization { .unsupported }
    func requestAuthorization(completion: @escaping (PlantSpeechAuthorization) -> Void) { completion(.unsupported) }
    func prepare() {}
    func start(update: @escaping (PlantTranscriberEvent) -> Void) {}
    func finish() {}
    func cancel() {}
}
#endif
