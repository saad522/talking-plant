import XCTest
@testable import PlantChat

@MainActor
final class PlantPersonalitySettingsTests: PlantChatXCTestCase {
    func test_init_doesNotMessageDefaults() {
        let (_, defaults) = makeSUT()

        XCTAssertEqual(defaults.messages, [])
    }

    func test_load_deliversCheerfulWhenNothingIsSaved() {
        let (sut, defaults) = makeSUT()

        XCTAssertEqual(sut.load(), .cheerful)
        XCTAssertEqual(defaults.messages, [.retrieveString(forKey: "plant.chat.personality")])
    }

    func test_load_deliversSavedPersonality() {
        PlantPersonality.available.forEach { personality in
            let (sut, defaults) = makeSUT()
            defaults.stub(personality.rawValue, forKey: "plant.chat.personality")

            XCTAssertEqual(sut.load(), personality)
        }
    }

    func test_load_deliversCheerfulForUnknownRawValue() {
        let (sut, defaults) = makeSUT()
        defaults.stub("pirate", forKey: "plant.chat.personality")

        XCTAssertEqual(sut.load(), .cheerful)
    }

    func test_load_deliversCheerfulForHiddenPersonalities() {
        [PlantPersonality.grumpyGrandma, .dramatic].forEach { personality in
            let (sut, defaults) = makeSUT()
            defaults.stub(personality.rawValue, forKey: "plant.chat.personality")

            XCTAssertEqual(sut.load(), .cheerful)
        }
    }

    func test_available_hidesGrumpyGrandmaAndDramatic() {
        XCTAssertEqual(PlantPersonality.available, [.cheerful, .chillSurfer, .politeButler])
    }

    func test_save_storesRawValueUnderKey() {
        let (sut, defaults) = makeSUT()

        sut.save(.politeButler)

        XCTAssertEqual(defaults.messages, [.setString("politeButler", forKey: "plant.chat.personality")])
    }

    func test_load_deliversLastSavedPersonality() {
        let (sut, _) = makeSUT()

        sut.save(.politeButler)
        sut.save(.chillSurfer)

        XCTAssertEqual(sut.load(), .chillSurfer)
    }

    // MARK: - Private helpers

    private func makeSUT(file: StaticString = #filePath, line: UInt = #line) -> (sut: PlantPersonalitySettings, defaults: DefaultsSpy) {
        let defaults = DefaultsSpy()
        let sut = PlantPersonalitySettings(defaults: defaults)
        trackMemoryLeak(defaults, file: file, line: line)
        trackMemoryLeak(sut, file: file, line: line)
        return (sut, defaults)
    }
}
