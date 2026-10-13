import Foundation
import PlantShared

/// On every connect: read Device Info, then set the reading interval, then ask for a reading
/// so the home screen doesn't wait a full interval. Nothing is sent when Device Info fails,
/// which includes an unsupported protocol version.
@MainActor
public final class PlantDeviceConnectionSetup {
    private let connection: PlantDeviceConnectionLoader
    private let infoLoader: PlantDeviceInfoLoader
    private let commands: PlantDeviceCommandSender
    private let readingInterval: UInt16
    private var isConnected = false
    private var run = 0

    public init(
        connection: PlantDeviceConnectionLoader,
        infoLoader: PlantDeviceInfoLoader,
        commands: PlantDeviceCommandSender,
        readingInterval: UInt16
    ) {
        self.connection = connection
        self.infoLoader = infoLoader
        self.commands = commands
        self.readingInterval = readingInterval
    }

    public func start() {
        connection.subscribe { [weak self] connection in
            self?.handle(connection)
        }
    }

    private func handle(_ connection: PlantConnection) {
        let nowConnected = connection == .connected
        guard nowConnected != isConnected else { return }
        isConnected = nowConnected
        run += 1
        guard nowConnected else { return }

        let current = run
        infoLoader.load { [weak self] result in
            guard case .success = result, let self, self.run == current else { return }
            self.commands.send(.setInterval(seconds: self.readingInterval)) { [weak self] error in
                guard error == nil else { return }
                self?.commands.send(.readNow) { _ in }
            }
        }
    }
}
