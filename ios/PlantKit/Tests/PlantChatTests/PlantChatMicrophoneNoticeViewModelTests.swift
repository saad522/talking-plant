import XCTest
@testable import PlantChat

@MainActor
final class PlantChatMicrophoneNoticeViewModelTests: PlantChatXCTestCase {
    func test_initWithAuthorization_needingNoNotice_returnsNil() {
        [PlantSpeechAuthorization.authorized, .notDetermined].forEach { authorization in
            XCTAssertNil(PlantChatMicrophoneNoticeViewModel(authorization: authorization, actionHandler: { _ in }))
        }
    }

    func test_denied_offersOpeningSettings() {
        var actions: [PlantChatAction] = []
        let sut = PlantChatMicrophoneNoticeViewModel(authorization: .denied, actionHandler: { actions.append($0) })

        XCTAssertEqual(sut?.settingsLabel, "Open Settings")
        XCTAssertEqual(actions, [])

        sut?.settingsTap()

        XCTAssertEqual(actions, [.openSettings])
    }

    func test_restrictedAndUnsupported_haveTextWithoutSettings() {
        let restricted = PlantChatMicrophoneNoticeViewModel(authorization: .restricted, actionHandler: { _ in })
        let unsupported = PlantChatMicrophoneNoticeViewModel(authorization: .unsupported, actionHandler: { _ in })

        XCTAssertNil(restricted?.settingsLabel)
        XCTAssertNil(unsupported?.settingsLabel)
        XCTAssertNotEqual(restricted?.text, unsupported?.text)
    }

    func test_failures_haveDistinctTextWithoutSettings() {
        let failures: [PlantChatMicrophoneNoticeViewModel.Failure] = [.preparing, .transcription, .audio]
        let sut = failures.map { PlantChatMicrophoneNoticeViewModel(failure: $0, actionHandler: { _ in }) }

        XCTAssertEqual(Set(sut.map(\.text)).count, 3)
        XCTAssertTrue(sut.allSatisfy { $0.settingsLabel == nil && $0.text.isEmpty == false })
    }
}
