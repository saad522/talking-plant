@MainActor
public protocol PlantSpeechGeneratorClient {
    /// 24 kHz mono samples for one chunk. `speed` 1 is the voice's normal speed.
    /// Waits for a load that is in progress. Throws right away when the model is neither
    /// loaded nor loading. The caller's start timeout bounds the wait.
    func generate(_ text: String, speed: Float) async throws -> [Float]
}
