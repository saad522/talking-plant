import PlantShared

/// What started a spoken line. A tap is an explicit request, so the app plays it even with the silent switch on.
public enum PlantMonitorSpeechTrigger: Equatable, Sendable {
    case automatic
    case tap
}

/// Speaks a home line. The app adapts Sprout's voice to this.
/// `completion` fires when the line ends, and also when `stop()` cuts it off.
@MainActor
public protocol PlantMonitorVoice {
    func speak(_ text: String, mood: PlantMood, trigger: PlantMonitorSpeechTrigger, completion: @escaping () -> Void)
    func stop()
}

/// The bubble's final line for a mood: the generated one, or the template when generating failed.
public struct PlantMonitorSpokenLine: Equatable, Sendable {
    public let text: String
    public let mood: PlantMood
    public let isSleeping: Bool

    public init(text: String, mood: PlantMood, isSleeping: Bool) {
        self.text = text
        self.mood = mood
        self.isSleeping = isSleeping
    }
}
