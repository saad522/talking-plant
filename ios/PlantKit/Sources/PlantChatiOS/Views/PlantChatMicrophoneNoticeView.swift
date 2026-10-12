import SwiftUI

public struct PlantChatMicrophoneNoticeView: View {
    @Environment(\.plantChatColor) private var color

    public let text: String
    public let settingsLabel: String?
    private let settings: () -> Void

    init(text: String, settingsLabel: String?, settings: @escaping () -> Void) {
        self.text = text
        self.settingsLabel = settingsLabel
        self.settings = settings
    }

    public var body: some View {
        VStack(spacing: PlantChatSize.noticePadding) {
            Text(text)
                .font(PlantChatFont.notice)
                .foregroundStyle(color.inkSecondary)
                .multilineTextAlignment(.center)
            if let settingsLabel {
                Button(action: settings) {
                    Text(settingsLabel)
                        .font(PlantChatFont.notice)
                        .foregroundStyle(color.primary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(PlantChatSize.noticePadding)
        .frame(maxWidth: .infinity)
        .background(color.card, in: RoundedRectangle(cornerRadius: PlantChatSize.noticeRadius))
        .padding(.horizontal, PlantChatSize.screenPadding)
    }
}
