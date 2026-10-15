#if os(iOS)
import AVFoundation

/// The audio session for Sprout's sounds outside Talk (docs/plans/P1-alive.md D5).
@MainActor
public enum PlantHomeAudioSession {
    /// `.ambient`: the silent switch mutes the sound and other apps' audio keeps playing, mixed.
    public static func activateAmbient(session: AVAudioSession = .sharedInstance()) {
        do {
            try session.setCategory(.ambient)
            try session.setActive(true)
        } catch {}
    }
}
#endif
