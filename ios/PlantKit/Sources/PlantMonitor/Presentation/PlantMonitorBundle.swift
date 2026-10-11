import Foundation

public enum PlantMonitorBundle {
    public static let bundle: Bundle = .module
}

extension String {
    static func localised(key: String) -> String {
        NSLocalizedString(key, tableName: "PlantMonitor", bundle: PlantMonitorBundle.bundle, comment: "")
    }
}
