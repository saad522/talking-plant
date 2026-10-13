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
import PlantMonitor
import PlantMonitoriOS
import PlantShared
#if DEBUG
import PlantTestPeripheral
#endif
import SwiftUI

@main
struct TalkingPlantApp: App {
    @StateObject private var navigation: AppNavigation
    @StateObject private var graphStore: AppGraphStore

    init() {
        let navigation = AppNavigation()
        _navigation = StateObject(wrappedValue: navigation)
        _graphStore = StateObject(wrappedValue: AppGraphStore(navigation: navigation))
    }

    var body: some Scene {
        WindowGroup {
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
    }

    private var appContent: some View {
        let graph = graphStore.graph
        return NavigationStack(path: $navigation.path) {
            graph.monitor
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
                    }
                }
        }
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
        case .modeChanged, .openSettings: break
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
