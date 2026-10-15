import Foundation

/// Tells a cold launch from a warm one: only the first ask in a process is cold.
/// The app keeps one for the whole process, so returning from background never replays the intro.
@MainActor
public final class PlantIntroLaunchTracker {
    private var isConsumed = false

    public init() {}

    public func consumeColdLaunch() -> Bool {
        defer { isConsumed = true }
        return !isConsumed
    }
}
