#if canImport(FoundationModels)
import FoundationModels
import Foundation

/// The on-device Apple model. Checked on a real iPhone only; its prompts and tool output come from `PlantVoicePrompt`.
@available(macOS 26, iOS 26, *)
@MainActor
public final class FoundationModelsPlantLanguageModelClient: PlantLanguageModelClient {
    private let historyLoader: PlantHistorySummaryLoader

    public init(historyLoader: PlantHistorySummaryLoader) {
        self.historyLoader = historyLoader
    }

    /// Read on every call, so a model that finishes downloading is picked up without a restart.
    public var isAvailable: Bool {
        SystemLanguageModel.default.availability == .available
    }

    public func makeSession(instructions: String, canReadHistory: Bool) -> PlantLanguageModelSession {
        let tools: [any Tool] = canReadHistory ? [PlantHistoryTool(historyLoader: historyLoader)] : []
        let options = GenerationOptions(temperature: canReadHistory ? 0.5 : nil)
        return Session(LanguageModelSession(tools: tools, instructions: instructions), options: options)
    }

    /// Loads the model ahead of the first message.
    public func prewarm() {
        guard isAvailable else { return }
        LanguageModelSession().prewarm()
    }

    private final class Session: PlantLanguageModelSession {
        private let session: LanguageModelSession
        private let options: GenerationOptions

        init(_ session: LanguageModelSession, options: GenerationOptions) {
            self.session = session
            self.options = options
        }

        func respond(to prompt: String, completion: @escaping (PlantLanguageModelSession.Result) -> Void) {
            Task { @MainActor in
                do {
                    completion(.success(try await session.respond(to: prompt, options: options).content))
                } catch let error as LanguageModelSession.GenerationError {
                    if case .exceededContextWindowSize = error {
                        completion(.failure(PlantLanguageModelError.contextTooLong))
                    } else {
                        completion(.failure(PlantLanguageModelError.generation))
                    }
                } catch {
                    completion(.failure(PlantLanguageModelError.generation))
                }
            }
        }
    }
}

/// Lets the model look up how the plant did over the last day or week.
@available(macOS 26, iOS 26, *)
private struct PlantHistoryTool: Tool {
    /// Only used on the main actor, inside `summary(of:)`.
    nonisolated(unsafe) let historyLoader: PlantHistorySummaryLoader

    let name = "readPlantHistory"
    let description = "Gets the lowest, average and highest moisture, light, temperature and humidity of the plant over the last day or the last week."

    @Generable
    struct Arguments {
        @Guide(description: "How far back to look.")
        let period: Period
    }

    @Generable
    enum Period {
        case day
        case week
    }

    func call(arguments: Arguments) async throws -> String {
        await summary(of: arguments.period == .day ? .day : .week)
    }

    @MainActor
    private func summary(of period: PlantHistorySummary.Period) async -> String {
        await withCheckedContinuation { continuation in
            historyLoader.load(period) { result in
                switch result {
                case .success(let summary): continuation.resume(returning: PlantVoicePrompt.history(summary))
                case .failure: continuation.resume(returning: "The history is not available right now.")
                }
            }
        }
    }
}
#endif
