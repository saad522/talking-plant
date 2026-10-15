import Foundation

@MainActor
public final class TrackingPlantSynthesizerClient: PlantSynthesizerClient {
    private let decoratee: PlantSynthesizerClient

    /// True from `speak` until that call's completion or `stop()`.
    public private(set) var isSpeaking = false
    /// Changes on every `speak` and `stop`, so an old completion never clears a newer speech.
    private var generation = 0

    public init(decoratee: PlantSynthesizerClient) {
        self.decoratee = decoratee
    }

    public func speak(_ text: String, style: PlantSpeechStyle, completion: @escaping () -> Void) {
        generation += 1
        let current = generation
        isSpeaking = true
        decoratee.speak(text, style: style) { [weak self] in
            if let self, generation == current {
                isSpeaking = false
            }
            completion()
        }
    }

    public func stop() {
        generation += 1
        isSpeaking = false
        decoratee.stop()
    }
}
