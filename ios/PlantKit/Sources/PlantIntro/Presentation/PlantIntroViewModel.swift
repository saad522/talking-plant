import Combine
import Foundation

/// The intro's state machine. The view drives the clock; this decides what is allowed and how long the hand-off takes.
@MainActor
public final class PlantIntroViewModel: ObservableObject {
    public enum State: Equatable, Sendable {
        case ready
        case playing
        case handingOff
        case finished
    }

    @Published public private(set) var state: State
    /// Called once, when the hand-off is done and the intro can be removed.
    public var completed: (() -> Void)?

    /// False on a warm launch: the app shows home straight away.
    public let shouldShowIntro: Bool
    public let greeting: String
    public let particleStyle: PlantIntroParticleStyle
    public let title = PlantIntroGreeting.title

    private let reduceMotion: Bool
    private var isSkipped = false

    public init(isColdLaunch: Bool, reduceMotion: Bool, hour: Int) {
        self.shouldShowIntro = isColdLaunch
        self.reduceMotion = reduceMotion
        self.greeting = PlantIntroGreeting.greeting(for: hour)
        self.particleStyle = PlantIntroGreeting.period(for: hour).particleStyle
        self.state = isColdLaunch ? .ready : .finished
    }

    public var isVisible: Bool { state != .finished }
    /// False with Reduce Motion: no bounce, glow, particles or text, only the crossfade.
    public var playsMotion: Bool { !reduceMotion }
    /// Seconds from the first frame until the hand-off begins.
    public var handoffDelay: Double { PlantIntroTimeline.handoffStart }
    public var handoffDuration: Double {
        reduceMotion || isSkipped ? PlantIntroTimeline.shortHandoffDuration : PlantIntroTimeline.handoffDuration
    }

    public func start() {
        guard state == .ready else { return }
        state = reduceMotion ? .handingOff : .playing
    }

    public func beginHandoff() {
        guard state == .playing else { return }
        state = .handingOff
    }

    /// A tap anywhere: hand off now, quickly. Does nothing once the hand-off is running.
    public func skip() {
        guard state == .ready || state == .playing else { return }
        isSkipped = true
        state = .handingOff
    }

    public func complete() {
        guard state == .handingOff else { return }
        state = .finished
        completed?()
    }
}
