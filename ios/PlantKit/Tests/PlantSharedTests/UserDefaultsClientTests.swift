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
