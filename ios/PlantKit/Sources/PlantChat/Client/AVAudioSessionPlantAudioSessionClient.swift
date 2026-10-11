#if os(iOS)
import AVFoundation

@MainActor
public final class AVAudioSessionPlantAudioSessionClient: PlantAudioSessionClient {
    private let session: AVAudioSession
    private var update: ((PlantAudioSessionEvent) -> Void)?
    private var observers: [NSObjectProtocol] = []

    public init(session: AVAudioSession = .sharedInstance()) {
        self.session = session
    }

    isolated deinit {
        observers.forEach(NotificationCenter.default.removeObserver)
    }

    public func activate() -> Bool {
        do {
            try session.setCategory(.playAndRecord, mode: .spokenAudio, options: [.defaultToSpeaker, .allowBluetoothHFP])
            try session.setActive(true)
            return true
        } catch {
            return false
        }
    }

    public func deactivate() {
        try? session.setActive(false, options: .notifyOthersOnDeactivation)
    }

    public func subscribe(update: @escaping (PlantAudioSessionEvent) -> Void) {
        self.update = update
        guard observers.isEmpty else { return }
        let center = NotificationCenter.default
        observers = [
            center.addObserver(forName: AVAudioSession.interruptionNotification, object: session, queue: .main) { [weak self] note in
                let rawType = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
                MainActor.assumeIsolated { self?.interruption(rawType) }
            },
            center.addObserver(forName: AVAudioSession.routeChangeNotification, object: session, queue: .main) { [weak self] note in
                let rawReason = note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt
                MainActor.assumeIsolated { self?.routeChange(rawReason) }
            }
        ]
    }

    private func interruption(_ rawType: UInt?) {
        switch rawType.flatMap(AVAudioSession.InterruptionType.init(rawValue:)) {
        case .began: update?(.interruptionBegan)
        case .ended: update?(.interruptionEnded)
        default: break
        }
    }

    private func routeChange(_ rawReason: UInt?) {
        guard rawReason.flatMap(AVAudioSession.RouteChangeReason.init(rawValue:)) == .oldDeviceUnavailable else { return }
        update?(.outputDeviceLost)
    }
}
#endif
