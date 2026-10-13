import Foundation
import PlantShared

@MainActor
public final class PeripheralPlantDeviceCommandSender: PlantDeviceCommandSender {
    private let client: PeripheralClient

    public enum Error: Swift.Error, Equatable {
        case connectivity
    }

    public init(client: PeripheralClient) {
        self.client = client
    }

    public func send(_ command: PlantDeviceCommand, completion: @escaping (PlantDeviceCommandSender.Result) -> Void) {
        client.write(PlantDeviceCommandMapper.map(command), to: .command) { error in
            completion(error == nil ? nil : Error.connectivity)
        }
    }
}
