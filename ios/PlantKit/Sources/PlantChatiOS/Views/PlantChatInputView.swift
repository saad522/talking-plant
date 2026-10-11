import SwiftUI

public struct PlantChatInputView: View {
    @Environment(\.plantChatColor) private var color

    public let placeholder: String
    public let sendLabel: String
    public let canSend: Bool
    private let text: Binding<String>
    private let send: () -> Void

    init(
        placeholder: String,
        sendLabel: String,
        text: Binding<String>,
        canSend: Bool,
        send: @escaping () -> Void
    ) {
        self.placeholder = placeholder
        self.sendLabel = sendLabel
        self.text = text
        self.canSend = canSend
        self.send = send
    }

    public var body: some View {
        HStack(spacing: PlantChatSize.inputSpacing) {
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
