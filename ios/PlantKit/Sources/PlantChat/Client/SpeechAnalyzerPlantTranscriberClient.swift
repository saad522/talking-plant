@preconcurrency import AVFoundation
import Speech

/// On-device transcription with `SpeechAnalyzer`. Uses `DictationTranscriber` when `SpeechTranscriber` can't handle the locale.
/// The audio session is activated by the caller; the stop rules live in `TranscriberPlantTranscriptLoader`.
@available(iOS 26, macOS 26, *)
@MainActor
public final class SpeechAnalyzerPlantTranscriberClient: PlantTranscriberClient {
    private enum Transcriber {
        case speech(SpeechTranscriber)
        case dictation(DictationTranscriber)

        var module: any SpeechModule {
            switch self {
            case let .speech(transcriber): transcriber
            case let .dictation(transcriber): transcriber
            }
        }
    }

    private let locale: Locale
    private var isSupported: Bool?
    private var generation = 0
    private var task: Task<Void, Never>?
    private var engine: AVAudioEngine?
    private var analyzer: SpeechAnalyzer?
    private var input: AsyncStream<AnalyzerInput>.Continuation?

    public init(locale: Locale = .current) {
        self.locale = locale.language.languageCode == .english ? locale : Locale(identifier: "en-US")
    }

    public var authorization: PlantSpeechAuthorization {
        if isSupported == false { return .unsupported }
        let microphone = AVAudioApplication.shared.recordPermission
        let speech = SFSpeechRecognizer.authorizationStatus()
        if microphone == .denied || speech == .denied { return .denied }
        if speech == .restricted { return .restricted }
        if microphone == .undetermined || speech == .notDetermined { return .notDetermined }
        return .authorized
    }

    public func requestAuthorization(completion: @escaping (PlantSpeechAuthorization) -> Void) {
        Task {
            if await resolveTranscriber() == nil {
                completion(.unsupported)
                return
            }
            if AVAudioApplication.shared.recordPermission == .undetermined {
                _ = await AVAudioApplication.requestRecordPermission()
            }
            if AVAudioApplication.shared.recordPermission == .granted, SFSpeechRecognizer.authorizationStatus() == .notDetermined {
                await withCheckedContinuation { continuation in
                    SFSpeechRecognizer.requestAuthorization { _ in continuation.resume() }
                }
            }
            completion(authorization)
        }
    }

    public func prepare() {
        Task {
            guard let transcriber = await resolveTranscriber() else { return }
            _ = try? await installAssets(for: transcriber)
        }
    }

    public func start(update: @escaping (PlantTranscriberEvent) -> Void) {
        cancel()
        let generation = generation
        task = Task { await run(generation: generation, update: update) }
    }

    public func finish() {
        guard let analyzer else { return }
        stopMicrophone()
        input?.finish()
        input = nil
        Task { try? await analyzer.finalizeAndFinishThroughEndOfInput() }
    }

    public func cancel() {
        generation += 1
        task?.cancel()
        task = nil
        stopMicrophone()
        input?.finish()
        input = nil
        if let analyzer {
            Task { await analyzer.cancelAndFinishNow() }
        }
        analyzer = nil
    }

    private func run(generation: Int, update: (PlantTranscriberEvent) -> Void) async {
        do {
            guard let transcriber = await resolveTranscriber() else { return fail(.transcription, generation, update) }
            guard try await installAssets(for: transcriber) else { return fail(.preparing, generation, update) }
            let analyzer = SpeechAnalyzer(modules: [transcriber.module])
            guard let format = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber.module]) else {
                return fail(.transcription, generation, update)
            }
            let (stream, continuation) = AsyncStream.makeStream(of: AnalyzerInput.self)
            guard generation == self.generation else { return }
            self.analyzer = analyzer
            input = continuation
            try startMicrophone(format: format, continuation: continuation)
            try await analyzer.start(inputSequence: stream)

            switch transcriber {
            case let .speech(transcriber):
                for try await result in transcriber.results where generation == self.generation {
                    update(Self.event(String(result.text.characters), isFinal: result.isFinal))
                }
            case let .dictation(transcriber):
                for try await result in transcriber.results where generation == self.generation {
                    update(Self.event(String(result.text.characters), isFinal: result.isFinal))
                }
            }
            if generation == self.generation {
                teardown()
                update(.finished)
            }
        } catch {
            fail(.transcription, generation, update)
        }
    }

    private func fail(_ error: PlantTranscriberError, _ generation: Int, _ update: (PlantTranscriberEvent) -> Void) {
        guard generation == self.generation else { return }
        teardown()
        update(.failed(error))
    }

    private func teardown() {
        stopMicrophone()
        input?.finish()
        input = nil
        analyzer = nil
    }

    private static func event(_ text: String, isFinal: Bool) -> PlantTranscriberEvent {
        isFinal ? .final(text) : .volatile(text)
    }

    // MARK: Models

    private var cachedTranscriber: Transcriber?

    private func resolveTranscriber() async -> Transcriber? {
        if let cachedTranscriber { return cachedTranscriber }
        let resolved: Transcriber?
        if SpeechTranscriber.isAvailable, let supported = await SpeechTranscriber.supportedLocale(equivalentTo: locale) {
            resolved = .speech(SpeechTranscriber(locale: supported, preset: .progressiveTranscription))
        } else if let supported = await DictationTranscriber.supportedLocale(equivalentTo: locale) {
            resolved = .dictation(DictationTranscriber(locale: supported, preset: .progressiveShortDictation))
        } else {
            resolved = nil
        }
        isSupported = resolved != nil
        cachedTranscriber = resolved
        return resolved
    }

    /// True when the model is installed, installing it first if needed.
    private func installAssets(for transcriber: Transcriber) async throws -> Bool {
        let module = transcriber.module
        if await AssetInventory.status(forModules: [module]) == .installed { return true }
        if let request = try await AssetInventory.assetInstallationRequest(supporting: [module]) {
            try await request.downloadAndInstall()
        }
        return await AssetInventory.status(forModules: [module]) == .installed
    }

    // MARK: Microphone

    private func startMicrophone(format: AVAudioFormat, continuation: AsyncStream<AnalyzerInput>.Continuation) throws {
        let engine = AVAudioEngine()
        Self.installTap(on: engine.inputNode, targetFormat: format, continuation: continuation)
        engine.prepare()
        try engine.start()
        self.engine = engine
    }

    private func stopMicrophone() {
        engine?.stop()
        engine?.inputNode.removeTap(onBus: 0)
        engine = nil
    }

    /// Not main-actor isolated: the tap block runs on the audio thread.
    private nonisolated static func installTap(
        on node: AVAudioInputNode,
        targetFormat: AVAudioFormat,
        continuation: AsyncStream<AnalyzerInput>.Continuation
    ) {
        let inputFormat = node.outputFormat(forBus: 0)
        let converter = AVAudioConverter(from: inputFormat, to: targetFormat)
        node.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { buffer, _ in
            guard let converter else { return }
            let ratio = targetFormat.sampleRate / inputFormat.sampleRate
            let capacity = AVAudioFrameCount((Double(buffer.frameLength) * ratio).rounded(.up))
            guard let converted = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: capacity) else { return }
            nonisolated(unsafe) var supplied = false
            var error: NSError?
            converter.convert(to: converted, error: &error) { _, status in
                if supplied {
                    status.pointee = .noDataNow
                    return nil
                }
                supplied = true
                status.pointee = .haveData
                return buffer
            }
            if error == nil, converted.frameLength > 0 {
                continuation.yield(AnalyzerInput(buffer: converted))
            }
        }
    }
}
