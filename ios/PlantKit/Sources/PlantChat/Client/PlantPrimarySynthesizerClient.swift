@MainActor
public protocol PlantPrimarySynthesizerClient {
    /// Sends `.generated` when the first audio is handed to the player, `.started` once the first buffer
    /// has actually played back, then exactly one `.finished` or `.failed`. Nothing is sent after `stop()`.
    func speak(_ text: String, style: PlantSpeechStyle, update: @escaping (PlantSpeechEvent) -> Void)
    /// Stops at once, synchronously.
    func stop()
}

public enum PlantSpeechEvent: Equatable, Sendable {
    /// The first audio is with the player. Playback is not confirmed yet.
    case generated
    /// The player reported the first buffer as played back.
    case started
    case finished
    case failed
}
