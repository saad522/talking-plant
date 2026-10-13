import Foundation
import PlantShared

@MainActor
public final class PeripheralPlantDeviceConnectionLoader: PlantDeviceConnectionLoader {
    public typealias Schedule = @MainActor (_ interval: TimeInterval, _ tick: @escaping @MainActor @Sendable () -> Bool) -> Void

    private let client: PeripheralConnectionClient
    private let offlineAfter: TimeInterval
    private let schedule: Schedule

    /// - Parameters:
    ///   - offlineAfter: How long the client may stay `.connecting` before the connection reads `.offline`.
    ///   - schedule: Calls `tick` after `offlineAfter`; the tick returns `false` so it runs once.
    public init(client: PeripheralConnectionClient, offlineAfter: TimeInterval = 20, schedule: @escaping Schedule) {
        self.client = client
        self.offlineAfter = offlineAfter
        self.schedule = schedule
    }

    public func subscribe(update: @escaping (PlantConnection) -> Void) {
        let subscription = Subscription(offlineAfter: offlineAfter, schedule: schedule, update: update)
        client.subscribe(state: { state in
            subscription.handle(state)
        })
    }

    /// One per subscriber, so each de-duplicates and times out on its own.
    @MainActor
    private final class Subscription {
        private let offlineAfter: TimeInterval
        private let schedule: Schedule
        private let update: (PlantConnection) -> Void
        private var generation = 0
        private var current: PlantConnection?

        init(offlineAfter: TimeInterval, schedule: @escaping Schedule, update: @escaping (PlantConnection) -> Void) {
            self.offlineAfter = offlineAfter
            self.schedule = schedule
            self.update = update
        }

        func handle(_ state: PeripheralConnectionState) {
            generation += 1
            deliver(PeripheralPlantDeviceConnectionLoader.map(state))

            guard state == .connecting else { return }
            let expected = generation
            schedule(offlineAfter) { [weak self] in
                guard let self, self.generation == expected else { return false }
                self.deliver(.offline)
                return false
            }
        }

        private func deliver(_ connection: PlantConnection) {
            guard connection != current else { return }
            current = connection
            update(connection)
        }
    }

    private static func map(_ state: PeripheralConnectionState) -> PlantConnection {
        switch state {
        case .unsupported: .bluetoothUnsupported
        case .unauthorized: .bluetoothUnauthorized
        case .poweredOff: .bluetoothOff
        case .idle: .notPaired
        case .connecting: .connecting
        case .connected: .connected
        case .incompatible: .incompatible
        }
    }
}
