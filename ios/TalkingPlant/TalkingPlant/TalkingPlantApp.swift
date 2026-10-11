//
//  TalkingPlantApp.swift
//  TalkingPlant
//
//  Created by Saad Saissi Hassani on 9/10/2026.
//

import Combine
import PlantHistory
import PlantHistoryiOS
import PlantMonitor
import PlantMonitoriOS
import PlantShared
import SwiftUI

@main
struct TalkingPlantApp: App {
    @StateObject private var navigation: AppNavigation
    private let monitor: PlantMonitorView
    private let history: PlantHistoryView

    init() {
        let store = Self.makeStore()
        let client = SimulatedPeripheralClient(startDate: Self.simulatedStartDate(continuingFrom: store))
        // Simulated mode: readings and the history range use the simulated clock.
        let currentDate = { client.currentDate }

        let readings = LocalPlantReadingDecorator(
            decoratee: PeripheralPlantReadingLoader(client: client, calibration: { .placeholder }, currentDate: currentDate),
            store: store
        )
        let navigation = AppNavigation()

        monitor = PlantMonitorUIComposer.composed(with: readings, actionHandler: { [weak navigation] action in
            navigation?.handle(action)
        })
        history = PlantHistoryUIComposer.composed(with: LocalPlantHistoryLoader(store: store, currentDate: currentDate))
        _navigation = StateObject(wrappedValue: navigation)
    }

    var body: some Scene {
        WindowGroup {
            NavigationStack(path: $navigation.path) {
                monitor
                    .navigationDestination(for: AppNavigation.Route.self) { route in
                        switch route {
                        case .history: history
                        }
                    }
            }
        }
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
    }

    @Published var path: [Route] = []

    func handle(_ action: PlantMonitorAction) {
        switch action {
        case .historyTap: path.append(.history)
        case .dismissed: break
        }
    }
}
