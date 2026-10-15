#if os(iOS)
import AVFoundation
import os

/// Plays the bundled `.caf` (or `.wav`) files. Players are created on first use and kept.
/// A missing or unplayable file is logged and skipped, so the app works before the files exist.
@MainActor
public final class AVAudioPlayerPlantSoundEffectsClient: PlantSoundEffectsClient {
    private static let logger = Logger(subsystem: "TalkingPlant", category: "sounds")
    private static let extensions = ["caf", "wav"]

    private let bundle: Bundle
    private var players: [String: AVAudioPlayer] = [:]
    private var missing: Set<String> = []

    public init(bundle: Bundle = .main) {
        self.bundle = bundle
    }

    public func play(_ effect: PlantSoundEffect) {
        guard let player = player(for: effect) else { return }
        PlantHomeAudioSession.activateAmbient()
        player.currentTime = 0
        player.play()
    }

    private func player(for effect: PlantSoundEffect) -> AVAudioPlayer? {
        let name = effect.fileName
        if let cached = players[name] { return cached }
        guard missing.contains(name) == false else { return nil }
        let bundle = bundle
        guard let url = Self.extensions.lazy.compactMap({ bundle.url(forResource: name, withExtension: $0) }).first else {
            Self.logger.notice("sound file \(name) not found")
            missing.insert(name)
            return nil
        }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.prepareToPlay()
            players[name] = player
            return player
        } catch {
            Self.logger.error("sound file \(name) can't be played: \(String(describing: error))")
            missing.insert(name)
            return nil
        }
    }
}
#endif
