import Foundation

/// One drifting light. Positions are fractions of the screen, so the view only scales them.
public struct PlantIntroParticle: Equatable, Sendable {
    public struct State: Equatable, Sendable {
        public let x: Double
        public let y: Double
        public let opacity: Double
    }

    public static let defaultCount = 15

    public let x: Double
    public let startY: Double
    /// How far it rises, as a fraction of the screen height.
    public let rise: Double
    public let drift: Double
    public let delay: Double
    public let life: Double
    /// Points.
    public let size: Double

    /// Same particles every launch: a fixed generator, no randomness.
    public static func make(count: Int = defaultCount) -> [PlantIntroParticle] {
        var seed: UInt64 = 0x5EED
        func next() -> Double {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            return Double(seed >> 33) / Double(1 << 31)
        }
        return (0..<count).map { index in
            let life = 0.5 + next() * 0.3
            let delay = PlantIntroTimeline.glowStart + next() * (PlantIntroTimeline.handoffStart - PlantIntroTimeline.glowStart - life)
            return PlantIntroParticle(
                x: (Double(index) + next() * 0.8) / Double(count),
                startY: 0.5 + next() * 0.35,
                rise: 0.15 + next() * 0.25,
                drift: (next() - 0.5) * 0.06,
                delay: delay,
                life: life,
                size: 2 + next() * 3
            )
        }
    }

    public func state(at time: Double) -> State? {
        let progress = (time - delay) / life
        guard progress >= 0, progress <= 1 else { return nil }
        return State(
            x: x + drift * sin(progress * 2 * .pi),
            y: startY - rise * progress,
            opacity: sin(progress * .pi)
        )
    }
}
