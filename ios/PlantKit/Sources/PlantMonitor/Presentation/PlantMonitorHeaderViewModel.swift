import Foundation
import PlantShared

public final class PlantMonitorHeaderViewModel {
    public let title: String
    /// "<room> · <mood label>" ("Sleeping" while the plant sleeps), or just the room before a mood loads.
    public let subtitle: String

    public init(name: String, room: String, mood: PlantMood?, isSleeping: Bool = false) {
        self.title = name
        if let mood {
            self.subtitle = String(
                format: String.localised(key: "plant.monitor.header.subtitle"),
                room,
                isSleeping ? String.localised(key: "plant.monitor.sleeping.label") : PlantMoodViewModel(mood: mood).label
            )
        } else {
            self.subtitle = room
        }
    }
}
