import AVFoundation

@MainActor
public final class AVSpeechPlantSynthesizerClient: NSObject, PlantSynthesizerClient, AVSpeechSynthesizerDelegate {
    private let synthesizer = AVSpeechSynthesizer()
    private var current: (id: ObjectIdentifier, completion: () -> Void)?

    public override init() {
        super.init()
        synthesizer.delegate = self
    }

    public func speak(_ text: String, style: PlantSpeechStyle, completion: @escaping () -> Void) {
        stop()
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechVoiceCatalog.avVoice(for: style)
        utterance.rate = style.rate
        utterance.pitchMultiplier = 1
        current = (ObjectIdentifier(utterance), completion)
        synthesizer.speak(utterance)
    }

    public func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        complete(nil)
    }

    public nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        let id = ObjectIdentifier(utterance)
        Task { @MainActor in self.complete(id) }
    }

    public nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        let id = ObjectIdentifier(utterance)
        Task { @MainActor in self.complete(id) }
    }

    /// Calls the pending completion once. A nil `id` completes whatever is pending.
    private func complete(_ id: ObjectIdentifier?) {
        guard let pending = current, id == nil || id == pending.id else { return }
        current = nil
        pending.completion()
    }
}
