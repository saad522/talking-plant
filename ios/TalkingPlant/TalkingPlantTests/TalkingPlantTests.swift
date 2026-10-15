//
//  TalkingPlantTests.swift
//  TalkingPlantTests
//
//  Created by Saad Saissi Hassani on 9/10/2026.
//

import PlantDevice
import PlantMonitor
import XCTest
@testable import TalkingPlant

@MainActor
final class TalkingPlantTests: XCTestCase {
    func test_waterTap_inSimulatedMode_watersTheSimulatedPlantOnly() {
        XCTAssertEqual(perform(.waterTap, in: .simulated), ["water"])
    }

    func test_waterTap_inSensorMode_asksForAReadingOnly() {
        XCTAssertEqual(perform(.waterTap, in: .sensor), ["readNow"])
    }

    func test_talkTap_prewarmsInBothModes() {
        XCTAssertEqual(perform(.talkTap, in: .simulated), ["prewarm"])
        XCTAssertEqual(perform(.talkTap, in: .sensor), ["prewarm"])
    }

    func test_otherActions_doNothing() {
        XCTAssertEqual(perform(.historyTap, in: .simulated), [])
        XCTAssertEqual(perform(.settingsTap, in: .sensor), [])
    }

    private func perform(_ action: PlantMonitorAction, in mode: PlantDeviceMode) -> [String] {
        var calls: [String] = []
        AppGraph.perform(
            action,
            in: mode,
            readNow: { calls.append("readNow") },
            water: { calls.append("water") },
            prewarm: { calls.append("prewarm") }
        )
        return calls
    }


    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testExample() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        // Any test you write for XCTest can be annotated as throws and async.
        // Mark your test throws to produce an unexpected failure when your test encounters an uncaught error.
        // Mark your test async to allow awaiting for asynchronous code to complete. Check the results with assertions afterwards.
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

}
