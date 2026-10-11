import PlantShared
import XCTest

@MainActor
final class UserDefaultsClientTests: PlantSharedXCTestCase {
    func test_retrieve_deliversNilForMissingKey() {
        let sut = makeSUT()

        XCTAssertNil(sut.retrieve(forKey: "missing"))
    }

    func test_retrieve_deliversLastSetValue() {
        let sut = makeSUT()

        sut.set(1_118, forKey: "soil")
        sut.set(1_136.5, forKey: "soil")

        XCTAssertEqual(sut.retrieve(forKey: "soil"), 1_136.5)
    }

    func test_set_persistsAcrossInstancesSharingDefaults() {
        let defaults = makeDefaults()

        UserDefaultsClient(defaults: defaults).set(2_000, forKey: "soil")

        XCTAssertEqual(UserDefaultsClient(defaults: defaults).retrieve(forKey: "soil"), 2_000)
    }

    func test_retrieveString_deliversNilForMissingKey() {
        let sut = makeSUT()

        XCTAssertNil(sut.retrieveString(forKey: "missing"))
    }

    func test_retrieveString_deliversLastSetValue() {
        let sut = makeSUT()

        sut.set("cheerful", forKey: "personality")
        sut.set("dramatic", forKey: "personality")

        XCTAssertEqual(sut.retrieveString(forKey: "personality"), "dramatic")
    }

    func test_setString_persistsAcrossInstancesSharingDefaults() {
        let defaults = makeDefaults()

        UserDefaultsClient(defaults: defaults).set("dramatic", forKey: "personality")

        XCTAssertEqual(UserDefaultsClient(defaults: defaults).retrieveString(forKey: "personality"), "dramatic")
    }

    func test_retrieveString_doesNotDeliverDoubleStoredUnderSameKey() {
        let sut = makeSUT()

        sut.set(1.5, forKey: "key")

        XCTAssertNil(sut.retrieveString(forKey: "key"))
    }

    func test_retrieveBool_deliversNilForMissingKey() {
        let sut = makeSUT()

        XCTAssertNil(sut.retrieveBool(forKey: "missing"))
    }

    func test_retrieveBool_deliversLastSetValue() {
        let sut = makeSUT()

        sut.set(true, forKey: "speak")
        sut.set(false, forKey: "speak")

        XCTAssertEqual(sut.retrieveBool(forKey: "speak"), false)
    }

    func test_setBool_persistsAcrossInstancesSharingDefaults() {
        let defaults = makeDefaults()

        UserDefaultsClient(defaults: defaults).set(true, forKey: "speak")

        XCTAssertEqual(UserDefaultsClient(defaults: defaults).retrieveBool(forKey: "speak"), true)
    }

    func test_retrieveBool_doesNotDeliverStringStoredUnderSameKey() {
        let sut = makeSUT()

        sut.set("yes", forKey: "key")

        XCTAssertNil(sut.retrieveBool(forKey: "key"))
    }

    // MARK: - Private helpers

    private func makeSUT(file: StaticString = #filePath, line: UInt = #line) -> UserDefaultsClient {
        let sut = UserDefaultsClient(defaults: makeDefaults())
        trackMemoryLeak(sut, file: file, line: line)
        return sut
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "UserDefaultsClientTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        addTeardownBlock { defaults.removePersistentDomain(forName: suiteName) }
        return defaults
    }
}
