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

    /// `.playback` with ducking, for a line the user asked for by tapping Sprout: it plays with the silent switch on,
    /// and other apps' audio gets quieter under it.
    public static func activatePlayback(session: AVAudioSession = .sharedInstance()) {
        do {
            try session.setCategory(.playback, options: [.duckOthers])
            try session.setActive(true)
        } catch {}
    }

    /// Tells other apps they can come back to full volume. The next sound or automatic line goes back to `.ambient`.
    public static func deactivate(session: AVAudioSession = .sharedInstance()) {
        do {
            try session.setActive(false, options: .notifyOthersOnDeactivation)
        } catch {}
    }
}
#endif
