//
//  TalkingPlantApp.swift
//  TalkingPlant
//
//  Created by Saad Saissi Hassani on 9/10/2026.
//

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
