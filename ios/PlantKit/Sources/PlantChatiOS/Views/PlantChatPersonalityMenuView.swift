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

    public struct SpeakReplies {
        public let label: String
        public let isOn: Bool
        let set: (Bool) -> Void

        init(label: String, isOn: Bool, set: @escaping (Bool) -> Void) {
            self.label = label
            self.isOn = isOn
            self.set = set
        }
    }

    @Environment(\.plantChatColor) private var color

    public let accessibilityLabel: String
    public let options: [Option]
    public let speakReplies: SpeakReplies
    /// DEBUG only: opens the Kokoro spike (docs/spikes/kokoro.md). Delete with the spike.
    public let voiceSpike: (() -> Void)?

    init(accessibilityLabel: String, options: [Option], speakReplies: SpeakReplies, voiceSpike: (() -> Void)? = nil) {
        self.accessibilityLabel = accessibilityLabel
        self.options = options
        self.speakReplies = speakReplies
        self.voiceSpike = voiceSpike
    }

    public var body: some View {
        Menu {
            // The picker only shows when there is a choice (v1 ships cheerful only).
            if options.count > 1 {
                ForEach(options) { option in
                    Button(action: option.select) {
                        if option.isSelected {
                            Label(option.label, systemImage: "checkmark")
                        } else {
                            Text(option.label)
                        }
                    }
                }
                Divider()
            }
            Toggle(speakReplies.label, isOn: Binding(get: { speakReplies.isOn }, set: speakReplies.set))
            if let voiceSpike {
                Button("Voice spike", action: voiceSpike)
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
