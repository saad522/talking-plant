import XCTest
@testable import PlantChat

@MainActor
final class PlantSpokenReplySettingsTests: PlantChatXCTestCase {
    func test_init_doesNotMessageDefaults() {
        let (_, defaults) = makeSUT()

        XCTAssertEqual(defaults.messages, [])
    }

    func test_isEnabled_isTrueWhenNothingIsSaved() {
        let (sut, defaults) = makeSUT()

        XCTAssertTrue(sut.isEnabled)
        XCTAssertEqual(defaults.messages, [.retrieveBool(forKey: "plant.chat.spokenReplies.enabled")])
    }

    func test_isEnabled_deliversSavedOff() {
        let (sut, defaults) = makeSUT()
        defaults.stub(false, forKey: "plant.chat.spokenReplies.enabled")

        XCTAssertFalse(sut.isEnabled)
    }

    func test_save_storesValueUnderKey() {
        let (sut, defaults) = makeSUT()

        sut.save(isEnabled: false)

        XCTAssertEqual(defaults.messages, [.setBool(false, forKey: "plant.chat.spokenReplies.enabled")])
    }

    func test_isEnabled_deliversLastSavedValue() {
        let (sut, _) = makeSUT()

        sut.save(isEnabled: false)
        sut.save(isEnabled: true)

        XCTAssertTrue(sut.isEnabled)
    }

    // MARK: - Private helpers

    private func makeSUT(file: StaticString = #filePath, line: UInt = #line) -> (sut: PlantSpokenReplySettings, defaults: DefaultsSpy) {
        let defaults = DefaultsSpy()
        let sut = PlantSpokenReplySettings(defaults: defaults)
        trackMemoryLeak(defaults, file: file, line: line)
        trackMemoryLeak(sut, file: file, line: line)
        return (sut, defaults)
    }
}
