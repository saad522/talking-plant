import Foundation

/// Sends `READ_NOW` once, a while after being asked. Used after watering, so the moisture
/// reading arrives soon after the soil has soaked it up. Asking again restarts the wait.
@MainActor
public final class PlantDeviceReadNowScheduler {
    public typealias Schedule = @MainActor (_ interval: TimeInterval, _ tick: @escaping @MainActor @Sendable () -> Bool) -> Void

    private let commands: PlantDeviceCommandSender
    private let delay: TimeInterval
    private let schedule: Schedule
    private var generation = 0

    /// - Parameters:
    ///   - delay: How long to wait before sending.
    ///   - schedule: Calls `tick` after `delay`; the tick returns `false` so it runs once.
    public init(commands: PlantDeviceCommandSender, delay: TimeInterval = 10, schedule: @escaping Schedule) {
        self.commands = commands
        self.delay = delay
        self.schedule = schedule
    }

    public func scheduleReadNow() {
        generation += 1
        let expected = generation
        schedule(delay) { [weak self] in
            guard let self, self.generation == expected else { return false }
            self.commands.send(.readNow) { _ in }
            return false
        }
    }
}
