import Foundation

/// Turns the transcriber's events into transcripts and decides when listening ends: after a pause,
/// when nothing is heard, or at the maximum duration.
@MainActor
public final class TranscriberPlantTranscriptLoader: PlantTranscriptLoader {
    /// A one-shot timer. Calls the action once after the interval.
    public typealias Schedule = @MainActor (TimeInterval, @escaping @MainActor () -> Void) -> Void

    /// Seconds without new words before listening ends.
    static let silenceTimeout: TimeInterval = 1.5
    /// Seconds without any words before listening is given up.
    static let noSpeechTimeout: TimeInterval = 6
    static let maximumDuration: TimeInterval = 30

    public enum Error: Swift.Error, Equatable {
        case preparing
        case transcription
    }

    private let client: PlantTranscriberClient
    private let schedule: Schedule

    private var update: ((PlantTranscriptLoader.Result) -> Void)?
    private var committed: [String] = []
    private var volatile = ""
    private var text = ""
    /// Changes whenever listening starts or ends, so older timers and events do nothing.
    private var session = 0
    /// Changes with every new text, so older silence timers do nothing.
    private var silenceGeneration = 0

    public init(client: PlantTranscriberClient, schedule: @escaping Schedule = TranscriberPlantTranscriptLoader.sleep) {
        self.client = client
        self.schedule = schedule
    }

    public static func sleep(_ interval: TimeInterval, _ action: @escaping @MainActor () -> Void) {
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(interval))
            action()
        }
    }

    public var authorization: PlantSpeechAuthorization {
        client.authorization
    }

    public func requestAuthorization(completion: @escaping (PlantSpeechAuthorization) -> Void) {
        client.requestAuthorization(completion: completion)
    }

    public func prepare() {
        client.prepare()
    }

    public func start(update: @escaping (PlantTranscriptLoader.Result) -> Void) {
        session += 1
        silenceGeneration += 1
        committed = []
        volatile = ""
        text = ""
        self.update = update

        let current = session
        client.start { [weak self] event in
            self?.handle(event, session: current)
        }
        schedule(Self.noSpeechTimeout) { [weak self] in
            guard let self, session == current, text.isEmpty else { return }
            client.cancel()
            deliverFinal()
        }
        schedule(Self.maximumDuration) { [weak self] in
            guard let self, session == current else { return }
            client.finish()
        }
    }

    public func stop() {
        client.finish()
    }

    public func cancel() {
        end()
        client.cancel()
    }

    private func handle(_ event: PlantTranscriberEvent, session current: Int) {
        guard session == current else { return }
        switch event {
        case .volatile(let value):
            volatile = value.trimmingCharacters(in: .whitespacesAndNewlines)
            textChanged()
        case .final(let value):
            let segment = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if !segment.isEmpty { committed.append(segment) }
            volatile = ""
            textChanged()
        case .finished:
            deliverFinal()
        case .failed(let error):
            let update = update
            end()
            update?(.failure(error == .preparing ? Error.preparing : Error.transcription))
        }
    }

    private func textChanged() {
        let combined = (committed + [volatile]).filter { !$0.isEmpty }.joined(separator: " ")
        guard combined != text else { return }
        text = combined
        update?(.success(PlantTranscript(text: combined, isFinal: false)))
        restartSilenceTimer()
    }

    private func restartSilenceTimer() {
        silenceGeneration += 1
        let current = session
        let generation = silenceGeneration
        schedule(Self.silenceTimeout) { [weak self] in
            guard let self, session == current, silenceGeneration == generation else { return }
            client.finish()
        }
    }

    private func deliverFinal() {
        let update = update
        let final = text
        end()
        update?(.success(PlantTranscript(text: final, isFinal: true)))
    }

    private func end() {
        session += 1
        update = nil
    }
}
