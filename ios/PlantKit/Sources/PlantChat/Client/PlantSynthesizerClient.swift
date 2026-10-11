import Foundation

@MainActor
public protocol PlantSynthesizerClient {
    /// Calls `completion` once, when the speech ends for any reason (finished or stopped).
    func speak(_ text: String, style: PlantSpeechStyle, completion: @escaping () -> Void)
    func stop()
}
