import Foundation

public enum PlantChatBundle {
    public static let bundle: Bundle = .module
}

extension String {
    static func localised(key: String) -> String {
        NSLocalizedString(key, tableName: "PlantChat", bundle: PlantChatBundle.bundle, comment: "")
    }
}
