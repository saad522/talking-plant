@MainActor
public protocol PlantSpeechPlayerClient {
    /// Starts the engine. Throws if it can't.
    func start() throws
    /// Queues 24 kHz mono samples. `completion(true)` once played back, `(false)` if playback
    /// broke (interruption, route change, media reset). Never called after `stop()`.
    func enqueue(_ samples: [Float], completion: @escaping (Bool) -> Void)
    /// Stops at once, synchronously.
    func stop()
}
