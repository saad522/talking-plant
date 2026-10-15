import PlantMonitor
import PlantShared
import XCTest

@MainActor
final class PlantLastSceneStoreTests: XCTestCase {
    func test_scene_isNightWhenNothingSaved() {
        XCTAssertEqual(PlantLastSceneStore(defaults: DefaultsSpy()).scene, .night)
    }

    func test_scene_isNightWhenSavedValueIsUnknown() {
        let defaults = DefaultsSpy()
        defaults.set("dawn", forKey: "plant.monitor.lastScene")

        XCTAssertEqual(PlantLastSceneStore(defaults: defaults).scene, .night)
    }

    func test_scene_returnsEachSavedScene() {
        let defaults = DefaultsSpy()
        let sut = PlantLastSceneStore(defaults: defaults)

        for scene in [PlantMonitorScene.day, .thirsty, .night] {
            sut.save(scene)
            XCTAssertEqual(PlantLastSceneStore(defaults: defaults).scene, scene)
        }
    }

    private final class DefaultsSpy: DefaultsClient {
        private var strings: [String: String] = [:]

        func set(_ value: Double, forKey key: String) {}
        func retrieve(forKey key: String) -> Double? { nil }
        func set(_ value: String, forKey key: String) { strings[key] = value }
        func retrieveString(forKey key: String) -> String? { strings[key] }
        func set(_ value: Bool, forKey key: String) {}
        func retrieveBool(forKey key: String) -> Bool? { nil }
    }
}
