import Foundation

public struct PlantIntroPose: Equatable, Sendable {
    public let scaleX: Double
    public let scaleY: Double
    /// Points, negative is up.
    public let offsetY: Double
    /// Degrees.
    public let rotation: Double

    public static let rest = PlantIntroPose(scaleX: 1, scaleY: 1, offsetY: 0, rotation: 0)
}

/// Pure curves of the intro, in seconds since it started. Every value is at rest outside its window,
/// so the first frame is exactly the launch screen.
public enum PlantIntroTimeline {
    public static let wakeDuration = 0.5
    public static let blinkStart = 0.25
    public static let blinkDuration = 0.12
    public static let glowStart = 0.2
    public static let textStart = 0.4
    /// The glow and the text are done; the hand-off begins.
    public static let handoffStart = 1.0
    public static let handoffDuration = 0.6
    public static let shortHandoffDuration = 0.3
    /// Where the bounce is fired from, for the haptic.
    public static let hapticTime = 0.1

    private struct Keyframe {
        let time: Double
        let scaleX: Double
        let scaleY: Double
        let offsetY: Double
    }

    private static let keyframes = [
        Keyframe(time: 0, scaleX: 1, scaleY: 1, offsetY: 0),
        Keyframe(time: 0.08, scaleX: 1.08, scaleY: 0.9, offsetY: 0),
        Keyframe(time: 0.22, scaleX: 0.94, scaleY: 1.1, offsetY: -24),
        Keyframe(time: 0.32, scaleX: 0.97, scaleY: 1.04, offsetY: -30),
        Keyframe(time: 0.42, scaleX: 1.1, scaleY: 0.88, offsetY: 0),
        Keyframe(time: wakeDuration, scaleX: 1, scaleY: 1, offsetY: 0),
    ]

    /// Squash and stretch bounce with a small leaf wiggle.
    public static func pose(at time: Double) -> PlantIntroPose {
        guard time > 0, time < wakeDuration else { return .rest }
        let upper = keyframes.firstIndex { $0.time >= time } ?? keyframes.count - 1
        let from = keyframes[max(upper - 1, 0)]
        let to = keyframes[upper]
        let fraction = smoothstep((time - from.time) / (to.time - from.time))
        let wiggle = 3.5 * sin(2 * .pi * 3 * time) * (1 - time / wakeDuration)
        return PlantIntroPose(
            scaleX: lerp(from.scaleX, to.scaleX, fraction),
            scaleY: lerp(from.scaleY, to.scaleY, fraction),
            offsetY: lerp(from.offsetY, to.offsetY, fraction),
            rotation: wiggle
        )
    }

    public static func isBlinking(at time: Double) -> Bool {
        time >= blinkStart && time < blinkStart + blinkDuration
    }

    /// 0 to 1 and back to 0, once, between `glowStart` and `handoffStart`.
    public static func glow(at time: Double) -> Double {
        guard time > glowStart, time < handoffStart else { return 0 }
        return sin(.pi * (time - glowStart) / (handoffStart - glowStart))
    }

    /// 0 before `textStart`, 1 at `handoffStart`.
    public static func textProgress(at time: Double) -> Double {
        let linear = min(max((time - textStart) / (handoffStart - textStart), 0), 1)
        return 1 - (1 - linear) * (1 - linear)
    }

    private static func lerp(_ from: Double, _ to: Double, _ fraction: Double) -> Double {
        from + (to - from) * fraction
    }

    private static func smoothstep(_ value: Double) -> Double {
        let clamped = min(max(value, 0), 1)
        return clamped * clamped * (3 - 2 * clamped)
    }
}
