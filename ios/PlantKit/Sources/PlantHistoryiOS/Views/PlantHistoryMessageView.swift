import SwiftUI

/// Full-screen message for the empty and error states. The composer picks the icon.
public struct PlantHistoryMessageView: View {
    private let icon: Image
    private let text: String

    init(icon: Image, text: String) {
        self.icon = icon
        self.text = text
    }

    public var body: some View {
        ZStack {
            Rectangle()
                .fill(PlantHistoryColor.background)
                .ignoresSafeArea()
            VStack(alignment: .center, spacing: 24) {
                icon
                    .font(PlantHistoryFont.icon)
                    .foregroundStyle(PlantHistoryColor.secondaryText)
                Text(text)
                    .font(PlantHistoryFont.body)
                    .foregroundStyle(PlantHistoryColor.primaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
        }
    }
}
