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
import PlantDevice
import PlantDeviceiOS
import PlantFaceiOS
import PlantHistoryiOS
import PlantIntro
import PlantIntroiOS
import PlantMonitor
import PlantMonitoriOS
import PlantShared
#if DEBUG
import PlantTestPeripheral
#endif
import SwiftUI
import UIKit

@main
struct TalkingPlantApp: App {
    /// One for the whole process: only the first launch of the process is cold, so coming back from background never replays the intro.
    private static let launchTracker = PlantIntroLaunchTracker()
    /// One haptics client for the whole app: the graphs and the intro share its generators.
    private static let haptics = UIKitPlantHapticsClient()

    @StateObject private var navigation: AppNavigation
    @StateObject private var graphStore: AppGraphStore
    @StateObject private var intro: PlantIntroViewModel
    @Environment(\.scenePhase) private var scenePhase

    init() {
        #if DEBUG
        // For the on-device checks: the first launch after this speaks the home line again.
        if ProcessInfo.processInfo.arguments.contains("-PlantSpokenLineReset") {
            UserDefaults.standard.removeObject(forKey: "plant.monitor.spoken.mood")
            UserDefaults.standard.removeObject(forKey: "plant.monitor.spoken.day")
        }
        #endif
        let navigation = AppNavigation()
        _navigation = StateObject(wrappedValue: navigation)
        // The voice is created inside the autoclosure, so it exists once, in the store that SwiftUI keeps.
        // A second `App.init` must not create a voice that prewarms a model the chat never uses.
        _graphStore = StateObject(wrappedValue: AppGraphStore(navigation: navigation, voice: SproutVoice(), haptics: Self.haptics))
        _intro = StateObject(wrappedValue: PlantIntroViewModel(
            isColdLaunch: Self.launchTracker.consumeColdLaunch(),
            reduceMotion: UIAccessibility.isReduceMotionEnabled,
            hour: Calendar.current.component(.hour, from: Date())
        ))
    }

    var body: some Scene {
        WindowGroup {
            rootContent
                .overlay { introOverlay }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active: graphStore.voice.prewarm()
            case .background: graphStore.voice.unload(from: "scenePhase background")
            default: break
            }
        }
    }

    /// Home is built underneath from the first frame; the intro only covers it until the hand-off is done.
    @ViewBuilder
    private var introOverlay: some View {
        if intro.isVisible {
            PlantIntroUIComposer.composed(
                viewModel: intro,
                sprout: Image("LaunchSprout"),
                sproutBlink: Image("LaunchSproutBlink"),
                sproutHeight: UIImage(named: "LaunchSprout")?.size.height ?? 151,
                launchBackground: Color("LaunchBackground"),
                handoffBackground: PlantMonitorUIComposer.background(
                    for: PlantLastSceneStore(defaults: UserDefaultsClient()).scene
                ),
                haptics: Self.haptics,
                sounds: graphStore.sounds
            )
        }
    }

    @ViewBuilder
    private var rootContent: some View {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-PlantTestPeripheral") {
            TestPeripheralView()
        } else {
            appContent
        }
        #else
        appContent
        #endif
    }

    private var appContent: some View {
        let graph = graphStore.graph
        return NavigationStack(path: $navigation.path) {
            graph.monitor
                .onAppear { graphStore.voice.prewarm() }
                #if DEBUG
                .toolbar {
                    if let simulatedPlant = graph.simulatedPlant {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Water") { simulatedPlant.water() }
                        }
                    }
                }
                #endif
                .navigationDestination(for: AppNavigation.Route.self) { route in
                    switch route {
                    case .history: graph.history
                    case .chat: graph.chat
                    case .device: graph.device
                    case .devicePicker: graph.devicePicker
                    case .calibration: graph.makeCalibration()
                    #if DEBUG
                    case .voiceCheck: VoiceCheckView(voice: graphStore.voice)
                    #endif
                    }
                }
        }
        // Dark backdrop from the first frame, so nothing white shows behind the content.
        .background { Color("LaunchBackground").ignoresSafeArea() }
        // A new graph means new view models, so the screen starts over; the navigation path stays.
        .id(graph.id)
    }
}

@MainActor
final class AppNavigation: ObservableObject {
    enum Route: Hashable {
        case history
        case chat
        case device
        case devicePicker
        case calibration
        #if DEBUG
        case voiceCheck
        #endif
    }

    @Published var path: [Route] = []

    func handle(_ action: PlantMonitorAction) {
        switch action {
        case .historyTap: path.append(.history)
        case .talkTap: path.append(.chat)
        case .settingsTap: path.append(.device)
        case .waterTap, .dismissed: break
        }
    }

    func handle(_ action: PlantDeviceAction) {
        switch action {
        case .pairTap: path.append(.devicePicker)
        case .paired: _ = path.popLast()
        case .calibrationTap: path.append(.calibration)
        case .modeChanged, .openSettings, .clearSensorHistory: break
        }
    }

    func handle(_ action: PlantChatAction) {
        switch action {
        case .backTap: _ = path.popLast()
        case .openSettings: break
        #if DEBUG
        case .voiceCheckTap: path.append(.voiceCheck)
        #endif
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

/// PlantMonitor's connection source, backed by PlantDevice's connection loader.
@MainActor
struct PlantDeviceConnectionLoaderAdapter: PlantConnectionLoader {
    let loader: PlantDeviceConnectionLoader

    func subscribe(update: @escaping (PlantConnection) -> Void) {
        loader.subscribe(update: update)
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
struct UnavailableLanguageModelClient: PlantLanguageModelClient {
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
