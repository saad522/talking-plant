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
    let id = UUID()
    private var memoryWarnings: Task<Void, Never>?
    private static let logger = Logger(subsystem: "TalkingPlant", category: "voice")

    init(physicalMemory: UInt64 = ProcessInfo.processInfo.physicalMemory) {
        #if canImport(PlantKokoro)
        Self.logger.notice("SproutVoice \(self.id) created: physical memory \(physicalMemory) bytes, gate \(Self.minimumPhysicalMemory)")
        if physicalMemory >= Self.minimumPhysicalMemory {
            let generator = KokoroSproutGenerator()
            synthesizer = FallbackPlantSynthesizerClient(
                primary: ChunkedPlantSynthesizerClient(generator: generator, player: AVAudioEnginePlantSpeechPlayerClient()),
                fallback: AVSpeechPlantSynthesizerClient()
            )
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
        synthesizer = AVSpeechPlantSynthesizerClient()
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
