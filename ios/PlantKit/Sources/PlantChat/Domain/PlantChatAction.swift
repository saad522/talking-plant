import Foundation

public enum PlantChatAction: Equatable {
    case backTap
    case openSettings
    #if DEBUG
    /// DEBUG voice check screen.
    case voiceCheckTap
    #endif
}
