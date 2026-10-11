import XCTest
@testable import PlantMonitor

@MainActor
final class PlantMonitorErrorViewModelTests: PlantMonitorXCTestCase {
    func test_init_hasLocalisedButtonTitle() {
        let sut = makeSUT(error: anyNSError())

        XCTAssertEqual(sut.buttonTitle, String.localised(key: "plant.monitor.error.dismiss.label"))
    }

    func test_init_hasConnectivityDescriptionOnConnectivityError() {
        let sut = makeSUT(error: PeripheralPlantReadingLoader.Error.connectivity)

        XCTAssertEqual(sut.description, String.localised(key: "plant.monitor.connectivity.error.description"))
    }

    func test_init_hasGeneralDescriptionOnOtherErrors() {
        let errors: [Error] = [PeripheralPlantReadingLoader.Error.invalidData, anyNSError()]

        errors.forEach { error in
            let sut = makeSUT(error: error)

            XCTAssertEqual(sut.description, String.localised(key: "plant.monitor.general.error.description"), "\(error)")
        }
    }

    func test_appear_deliversConnectionOnConnectivityError() {
        let sut = makeSUT(error: PeripheralPlantReadingLoader.Error.connectivity)
        var events: [String] = []
        sut.loadedConnection = { _ in events.append("connection") }
        sut.loadedGeneral = { _ in events.append("general") }

        sut.appear()

        XCTAssertEqual(events, ["connection"])
    }

    func test_appear_deliversGeneralOnOtherErrors() {
        let sut = makeSUT(error: PeripheralPlantReadingLoader.Error.invalidData)
        var events: [String] = []
        sut.loadedConnection = { _ in events.append("connection") }
        sut.loadedGeneral = { _ in events.append("general") }

        sut.appear()

        XCTAssertEqual(events, ["general"])
    }

    func test_tap_deliversDismissedAction() {
        var actions: [PlantMonitorAction] = []
        let sut = makeSUT(error: anyNSError(), actionHandler: { actions.append($0) })

        sut.tap()

        XCTAssertEqual(actions, [.dismissed])
    }

    // MARK: - Private helpers

    private func makeSUT(
        error: Error,
        actionHandler: @escaping (PlantMonitorAction) -> Void = { _ in },
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> PlantMonitorErrorViewModel {
        let sut = PlantMonitorErrorViewModel(error: error, actionHandler: actionHandler)
        trackMemoryLeak(sut, file: file, line: line)
        return sut
    }
}
