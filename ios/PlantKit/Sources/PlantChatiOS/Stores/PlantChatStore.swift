import PlantChat
import SwiftUI

@MainActor
final class PlantChatStore<Face: View>: ObservableObject {
    @Published var title: String = ""
    @Published var subtitle: String = ""
    @Published var face: Face?
    @Published var notice: PlantChatNoticeView?
    @Published var messages: [PlantChatBubbleView] = []
    @Published var isReplying: Bool = false
    @Published var personalityMenu: PlantChatPersonalityMenuView?
    @Published var draft: String = ""
    @Published var activity: PlantChatActivity = .idle
    /// The words heard so far; `nil` until the first ones arrive.
    @Published var liveTranscript: String?
    @Published var inputMode: PlantChatInputMode = .voice
    @Published var microphoneNotice: PlantChatMicrophoneNoticeView?
}
