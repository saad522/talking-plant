import Foundation
import PlantShared

@MainActor
public final class PeripheralPlantDeviceConnectionLoader: PlantDeviceConnectionLoader {
    public typealias Schedule = @MainActor (_ interval: TimeInterval, _ tick: @escaping @MainActor @Sendable () -> Bool) -> Void

    private let client: PeripheralConnectionClient
    private let offlineAfter: TimeInterval
    private let schedule: Schedule
    private var generation = 0
    private var current: PlantConnection?

    /// - Parameters:
    ///   - offlineAfter: How long the client may stay `.connecting` before the connection reads `.offline`.
    ///   - schedule: Calls `tick` after `offlineAfter`; the tick returns `false` so it runs once.
    public init(client: PeripheralConnectionClient, offlineAfter: TimeInterval = 20, schedule: @escaping Schedule) {
        self.client = client
        self.offlineAfter = offlineAfter
        self.schedule = schedule
    }

    public func subscribe(update: @escaping (PlantConnection) -> Void) {
        client.subscribe(state: { [weak self] state in
            self?.handle(state, update: update)
        })
    }

    private func handle(_ state: PeripheralConnectionState, update: @escaping (PlantConnection) -> Void) {
        generation += 1
        let connection = Self.map(state)
        deliver(connection, update: update)

        guard state == .connecting else { return }
        let expected = generation
        nonisolated(unsafe) let update = update
        schedule(offlineAfter) { [weak self] in
            guard let self, self.generation == expected else { return false }
            self.deliver(.offline, update: update)
            return false
        }
    }

    private func deliver(_ connection: PlantConnection, update: (PlantConnection) -> Void) {
        guard connection != current else { return }
        current = connection
        update(connection)
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
