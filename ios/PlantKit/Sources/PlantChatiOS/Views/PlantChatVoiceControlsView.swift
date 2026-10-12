import PlantChat
import SwiftUI

/// The keyboard, mic and end buttons that take the text field's place (DESIGN.md section 6).
public struct PlantChatVoiceControlsView: View {
    @Environment(\.plantChatColor) private var color

    public let activity: PlantChatActivity
    public let keyboardLabel: String
    public let micLabel: String
    public let endLabel: String
    private let keyboard: () -> Void
    private let mic: () -> Void
    private let end: () -> Void

    init(
        activity: PlantChatActivity,
        keyboardLabel: String,
        micLabel: String,
        endLabel: String,
        keyboard: @escaping () -> Void,
        mic: @escaping () -> Void,
        end: @escaping () -> Void
    ) {
        self.activity = activity
        self.keyboardLabel = keyboardLabel
        self.micLabel = micLabel
        self.endLabel = endLabel
        self.keyboard = keyboard
        self.mic = mic
        self.end = end
    }

    public var body: some View {
        HStack(spacing: PlantChatSize.voiceControlsSpacing) {
            Button(action: keyboard) {
                Image(systemName: "keyboard")
                    .font(PlantChatFont.headerIcon)
                    .foregroundStyle(color.ink)
                    .frame(width: PlantChatSize.voiceSideButton, height: PlantChatSize.voiceSideButton)
                    .background(color.card, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(keyboardLabel)

            Button(action: mic) {
                Image(systemName: micIcon)
                    .font(PlantChatFont.micIcon)
                    .foregroundStyle(color.onPrimary)
                    .frame(width: PlantChatSize.micButton, height: PlantChatSize.micButton)
                    .background(color.primary, in: Circle())
                    .overlay { Circle().strokeBorder(color.micBorder, lineWidth: PlantChatSize.micBorder) }
                    .opacity(activity == .thinking ? 0.4 : 1)
            }
            .buttonStyle(.plain)
            .disabled(activity == .thinking)
            .accessibilityLabel(micLabel)

            Button(action: end) {
                Image(systemName: "xmark")
                    .font(PlantChatFont.headerIcon)
                    .foregroundStyle(color.userBubbleText)
                    .frame(width: PlantChatSize.voiceSideButton, height: PlantChatSize.voiceSideButton)
                    .background(color.userBubble, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(endLabel)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, PlantChatSize.screenPadding)
        .padding(.vertical, PlantChatSize.inputSpacing)
    }

    private var micIcon: String {
        switch activity {
        case .idle, .speaking: "mic.fill"
        case .listening: "stop.fill"
        case .thinking: "ellipsis"
        }
    }
}
