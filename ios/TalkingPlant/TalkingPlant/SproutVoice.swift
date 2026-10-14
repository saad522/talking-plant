//
//  SproutVoice.swift
//  TalkingPlant
//

import Foundation
import os
import PlantChat
import UIKit
#if canImport(PlantKokoro)
import PlantKokoro
#endif

/// Sprout's speech and the Kokoro model's lifecycle (docs/plans/M5c-kokoro.md 3.7).
/// One per app, shared by every graph, so a mode change never loads a second model.
/// Devices below the RAM gate, and builds without the PlantKokoro package, use the Apple voice alone.
@MainActor
final class SproutVoice {
    /// Just under 6 GB: iOS reports slightly less than the marketing size.
    static let minimumPhysicalMemory: UInt64 = 5_500_000_000

    let synthesizer: PlantSynthesizerClient
    private let prewarmModel: () async throws -> Void
    private let unloadModel: () -> Void
    #if DEBUG
    // For the voice check screen.
    private let apple = AVSpeechPlantSynthesizerClient()
    private var physicalMemory: UInt64 = 0
    #if canImport(PlantKokoro)
    private var generator: KokoroSproutGenerator?
    private var chunked: ChunkedPlantSynthesizerClient?
    /// Set by "Reset peak". Until then the peak is the kernel's, since launch.
    private var peakWindow: KokoroPeakWindow?
    #endif
    #endif
    let id = UUID()
    private var memoryWarnings: Task<Void, Never>?
    private static let logger = Logger(subsystem: "TalkingPlant", category: "voice")

    init(physicalMemory: UInt64 = ProcessInfo.processInfo.physicalMemory) {
        #if DEBUG
        self.physicalMemory = physicalMemory
        #endif
        #if canImport(PlantKokoro)
        Self.logger.notice("SproutVoice \(self.id) created: physical memory \(physicalMemory) bytes, gate \(Self.minimumPhysicalMemory)")
        if physicalMemory >= Self.minimumPhysicalMemory {
            let generator = KokoroSproutGenerator()
            let chunked = ChunkedPlantSynthesizerClient(generator: generator, player: AVAudioEnginePlantSpeechPlayerClient())
            #if DEBUG
            self.generator = generator
            self.chunked = chunked
            synthesizer = FallbackPlantSynthesizerClient(primary: chunked, fallback: apple)
            #else
            synthesizer = FallbackPlantSynthesizerClient(primary: chunked, fallback: AVSpeechPlantSynthesizerClient())
            #endif
            prewarmModel = { try await generator.prewarm() }
            unloadModel = { generator.unload() }
            memoryWarnings = Task { [weak self] in
                for await _ in NotificationCenter.default.notifications(named: UIApplication.didReceiveMemoryWarningNotification) {
                    self?.unload(from: "memory warning")
                }
            }
            return
        }
        #endif
        #if DEBUG
        synthesizer = apple
        #else
        synthesizer = AVSpeechPlantSynthesizerClient()
        #endif
        prewarmModel = {}
        unloadModel = {}
    }

    deinit { memoryWarnings?.cancel() }

    /// Idempotent: home screen appears, scene becomes active.
    func prewarm() {
        Self.logger.notice("prewarm requested on SproutVoice \(self.id)")
        Task {
            do {
                try await prewarmModel()
            } catch {
                Self.logger.error("prewarm failed: \(String(describing: error))")
            }
        }
    }

    /// Scene goes to the background, or a memory warning.
    func unload(from source: String) {
        Self.logger.notice("unload from: \(source), SproutVoice \(self.id)")
        unloadModel()
    }
}

#if canImport(PlantKokoro)
extension KokoroSproutGenerator: PlantSpeechGeneratorClient {}
#endif

#if DEBUG
extension SproutVoice: PlantVoiceCheckClient {
    var snapshot: PlantVoiceCheckSnapshot {
        #if canImport(PlantKokoro)
        let memory = KokoroMemory.current()
        let state: PlantVoiceCheckSnapshot.State = switch generator?.state {
        case .loaded: .loaded
        case .loading: .loading
        case .notLoaded, nil: .notLoaded
        }
        return PlantVoiceCheckSnapshot(
            voiceID: id.uuidString,
            physicalMemory: physicalMemory,
            minimumPhysicalMemory: Self.minimumPhysicalMemory,
            state: state,
            loadSeconds: generator?.timings?.loadSeconds,
            warmUpSeconds: generator?.timings?.warmUpSeconds,
            memoryNowBytes: memory?.currentBytes,
            memoryPeakBytes: peakWindow?.peakBytes ?? memory?.peakBytes,
            utterance: chunked?.lastMetrics
        )
        #else
        PlantVoiceCheckSnapshot(
            voiceID: id.uuidString,
            physicalMemory: physicalMemory,
            minimumPhysicalMemory: Self.minimumPhysicalMemory,
            state: .notLoaded
        )
        #endif
    }

    func load() async -> String? {
        do {
            try await prewarmModel()
            return nil
        } catch {
            return String(describing: error)
        }
    }

    func unload() {
        unload(from: "voice check")
    }

    func resetPeak() {
        #if canImport(PlantKokoro)
        peakWindow?.stop()
        peakWindow = KokoroPeakWindow()
        #endif
    }

    func speak(_ text: String, style: PlantSpeechStyle, appleOnly: Bool, completion: @escaping () -> Void) {
        stop()
        if appleOnly {
            apple.speak(text, style: style, completion: completion)
        } else {
            synthesizer.speak(text, style: style, completion: completion)
        }
    }

    func stop() {
        synthesizer.stop()
        apple.stop()
    }
}
#endif
