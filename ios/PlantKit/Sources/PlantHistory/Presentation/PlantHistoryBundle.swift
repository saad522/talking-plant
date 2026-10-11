import Foundation

public enum PlantHistoryBundle {
    public static let bundle: Bundle = .module
}

extension String {
    static func localised(key: String) -> String {
        NSLocalizedString(key, tableName: "PlantHistory", bundle: PlantHistoryBundle.bundle, comment: "")
    }
}
