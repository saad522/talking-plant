@MainActor
public protocol PlantPrimarySynthesizerClient {
    /// Sends `.started` once audio plays, then exactly one `.finished` or `.failed`.
    /// Nothing is sent after `stop()`.
    func speak(_ text: String, style: PlantSpeechStyle, update: @escaping (PlantSpeechEvent) -> Void)
    /// Stops at once, synchronously.
    func stop()
}

public enum PlantSpeechEvent: Equatable, Sendable {
    case started
    case finished
    case failed
}
