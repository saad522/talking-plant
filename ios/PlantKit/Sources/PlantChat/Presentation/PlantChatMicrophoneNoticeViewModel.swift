import Foundation

@MainActor
public final class PlantChatMicrophoneNoticeViewModel {
    public enum Failure: Equatable, Sendable {
        case preparing
        case transcription
        case audio
    }

    private let actionHandler: (PlantChatAction) -> Void

    public let text: String
    /// Only when the user can fix it in Settings.
    public let settingsLabel: String?

    /// - Returns: `nil` when the authorization needs no notice.
    public init?(authorization: PlantSpeechAuthorization, actionHandler: @escaping (PlantChatAction) -> Void) {
        switch authorization {
        case .denied:
            text = String.localised(key: "plant.chat.mic.denied.notice")
            settingsLabel = String.localised(key: "plant.chat.mic.settings.label")
        case .restricted:
            text = String.localised(key: "plant.chat.mic.restricted.notice")
            settingsLabel = nil
        case .unsupported:
            text = String.localised(key: "plant.chat.mic.unsupported.notice")
            settingsLabel = nil
        case .notDetermined, .authorized:
            return nil
        }
        self.actionHandler = actionHandler
    }

    public init(failure: Failure, actionHandler: @escaping (PlantChatAction) -> Void) {
        text = switch failure {
        case .preparing: String.localised(key: "plant.chat.mic.preparing.notice")
        case .transcription: String.localised(key: "plant.chat.mic.failure.notice")
        case .audio: String.localised(key: "plant.chat.mic.busy.notice")
        }
        settingsLabel = nil
        self.actionHandler = actionHandler
    }

    public func settingsTap() {
        actionHandler(.openSettings)
    }
}
