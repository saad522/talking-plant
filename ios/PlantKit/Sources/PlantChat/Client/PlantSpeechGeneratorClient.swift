@MainActor
public protocol PlantSpeechGeneratorClient {
    /// 24 kHz mono samples for one chunk. `speed` 1 is the voice's normal speed.
    /// Waits for a load that is in progress. Throws right away when the model is neither
    /// loaded nor loading. The caller's start timeout bounds the wait.
    func generate(_ text: String, speed: Float) async throws -> [Float]
    func utteranceStarted()
    func utteranceFinished()
}

public extension PlantSpeechGeneratorClient {
    /// Called when an utterance begins and when it ends (finished, failed or stopped), so the
    /// generator can measure the utterance and release scratch memory. Does nothing by default.
    func utteranceStarted() {}
    func utteranceFinished() {}
}
