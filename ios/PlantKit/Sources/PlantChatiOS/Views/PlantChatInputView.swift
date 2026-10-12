import SwiftUI

public struct PlantChatInputView: View {
    @Environment(\.plantChatColor) private var color

    public let placeholder: String
    public let sendLabel: String
    public let canSend: Bool
    public let voiceLabel: String
    private let text: Binding<String>
    private let send: () -> Void
    private let voice: () -> Void

    init(
        placeholder: String,
        sendLabel: String,
        text: Binding<String>,
        canSend: Bool,
        voiceLabel: String,
        send: @escaping () -> Void,
        voice: @escaping () -> Void
    ) {
        self.placeholder = placeholder
        self.sendLabel = sendLabel
        self.text = text
        self.canSend = canSend
        self.voiceLabel = voiceLabel
        self.send = send
        self.voice = voice
    }

    public var body: some View {
        HStack(spacing: PlantChatSize.inputSpacing) {
            Button(action: voice) {
                Image(systemName: "mic.fill")
                    .font(PlantChatFont.sendIcon)
                    .foregroundStyle(color.primary)
                    .frame(width: PlantChatSize.inputMicButton, height: PlantChatSize.inputMicButton)
                    .background(color.card, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(voiceLabel)

            TextField(placeholder, text: text)
                .font(PlantChatFont.input)
                .foregroundStyle(color.ink)
                .submitLabel(.send)
                .onSubmit { if canSend { send() } }
                .padding(.horizontal, PlantChatSize.inputHorizontalPadding)
                .frame(height: PlantChatSize.inputHeight)
                .background(color.card, in: Capsule())

            Button(action: send) {
                Image(systemName: "arrow.up")
                    .font(PlantChatFont.sendIcon)
                    .foregroundStyle(color.onPrimary)
                    .frame(width: PlantChatSize.sendButton, height: PlantChatSize.sendButton)
                    .background(color.primary, in: Circle())
                    .opacity(canSend ? 1 : 0.4)
            }
            .buttonStyle(.plain)
            .disabled(canSend == false)
            .accessibilityLabel(sendLabel)
        }
        .padding(.horizontal, PlantChatSize.screenPadding)
        .padding(.vertical, PlantChatSize.inputSpacing)
    }
}
