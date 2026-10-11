import SwiftUI

public struct PlantChatPersonalityMenuView: View {
    public struct Option: Equatable, Identifiable {
        public let id: String
        public let label: String
        public let isSelected: Bool
        let select: () -> Void

        init(id: String, label: String, isSelected: Bool, select: @escaping () -> Void) {
            self.id = id
            self.label = label
            self.isSelected = isSelected
            self.select = select
        }

        public static func == (lhs: Option, rhs: Option) -> Bool {
            lhs.id == rhs.id && lhs.label == rhs.label && lhs.isSelected == rhs.isSelected
        }
    }

    @Environment(\.plantChatColor) private var color

    public let accessibilityLabel: String
    public let options: [Option]

    init(accessibilityLabel: String, options: [Option]) {
        self.accessibilityLabel = accessibilityLabel
        self.options = options
    }

    public var body: some View {
        Menu {
            ForEach(options) { option in
                Button(action: option.select) {
                    if option.isSelected {
                        Label(option.label, systemImage: "checkmark")
                    } else {
                        Text(option.label)
                    }
                }
            }
        } label: {
            Image(systemName: "slider.horizontal.3")
                .font(PlantChatFont.headerIcon)
                .foregroundStyle(color.ink)
                .frame(width: PlantChatSize.headerButton, height: PlantChatSize.headerButton)
                .background(color.card, in: Circle())
        }
        .accessibilityLabel(accessibilityLabel)
    }
}
