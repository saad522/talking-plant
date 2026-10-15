import Foundation

public enum PlantIntroBundle {
    public static let bundle: Bundle = .module
}

extension String {
    static func localised(key: String) -> String {
        NSLocalizedString(key, tableName: "PlantIntro", bundle: PlantIntroBundle.bundle, comment: "")
    }
}
