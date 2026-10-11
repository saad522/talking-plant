import Foundation

@MainActor
public protocol PlantAudioSessionClient {
    /// Sets the category and activates. False when the system refuses, e.g. during a call.
    func activate() -> Bool
    /// Deactivates and lets other apps' audio resume.
    func deactivate()
    func subscribe(update: @escaping (PlantAudioSessionEvent) -> Void)
}

public enum PlantAudioSessionEvent: Equatable, Sendable {
    case interruptionBegan
    case interruptionEnded
    case outputDeviceLost
}
