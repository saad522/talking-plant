import Foundation
import PlantShared

@MainActor
public final class PeripheralPlantDeviceInfoLoader: PlantDeviceInfoLoader {
    private let client: PeripheralClient

    public enum Error: Swift.Error, Equatable {
        case connectivity
        case invalidData
    }

    public init(client: PeripheralClient) {
        self.client = client
    }

    public func load(completion: @escaping (PlantDeviceInfoLoader.Result) -> Void) {
        client.read(.deviceInfo) { result in
            switch result {
            case .success(let data):
                completion(PlantDeviceInfoLoader.Result(catching: { try PlantDeviceInfoMapper.map(data) }))
            case .failure:
                completion(.failure(Error.connectivity))
            }
        }
    }
}
