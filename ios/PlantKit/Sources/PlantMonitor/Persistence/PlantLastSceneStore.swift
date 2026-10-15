import Foundation
import PlantShared

/// Remembers the last scene shown, so the next launch draws it on the first frame instead of fading to it.
/// Night until a scene was saved: with no sensor yet, the plant is offline, which is a night scene.
@MainActor
public final class PlantLastSceneStore {
    private let defaults: DefaultsClient
    private let key = "plant.monitor.lastScene"

    public init(defaults: DefaultsClient) {
        self.defaults = defaults
    }

    public var scene: PlantMonitorScene {
        defaults.retrieveString(forKey: key).flatMap(PlantMonitorScene.init(rawValue:)) ?? .night
    }

    public func save(_ scene: PlantMonitorScene) {
        defaults.set(scene.rawValue, forKey: key)
    }
}
