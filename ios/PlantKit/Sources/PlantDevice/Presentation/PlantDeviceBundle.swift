import Foundation

public enum PlantDeviceBundle {
    public static let bundle: Bundle = .module
}

extension String {
    static func localised(key: String) -> String {
        NSLocalizedString(key, tableName: "PlantDevice", bundle: PlantDeviceBundle.bundle, comment: "")
    }
}
