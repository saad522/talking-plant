import Foundation
import PlantShared

public final class PlantMonitorHeaderViewModel {
    public let title: String
    /// "<room> · <mood label>", or just the room before a mood loads.
    public let subtitle: String

    public init(name: String, room: String, mood: PlantMood?) {
        self.title = name
        if let mood {
            self.subtitle = String(
                format: String.localised(key: "plant.monitor.header.subtitle"),
                room,
                PlantMoodViewModel(mood: mood).label
            )
        } else {
            self.subtitle = room
        }
    }
}
