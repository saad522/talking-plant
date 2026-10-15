import PlantMonitor
import SwiftUI
import XCTest
@testable import PlantMonitoriOS

@MainActor
final class PlantMonitorBackgroundTests: PlantMonitoriOSXCTestCase {
    func test_background_deliversTheHomeBackgroundOfEachScene() {
        XCTAssertEqual(PlantMonitorUIComposer.background(for: .day), PlantMonitorPalette.day.background)
        XCTAssertEqual(PlantMonitorUIComposer.background(for: .thirsty), PlantMonitorPalette.thirsty.background)
        XCTAssertEqual(PlantMonitorUIComposer.background(for: .night), PlantMonitorPalette.night.background)
    }
}
