import Foundation
import PlantShared

@MainActor
public final class PeripheralPlantDeviceRawReadingLoader: PlantDeviceRawReadingLoader {
    private let client: PeripheralClient
    private let currentDate: () -> Date

    public enum Error: Swift.Error, Equatable {
        case connectivity
        case invalidData
    }

    public init(client: PeripheralClient, currentDate: @escaping () -> Date = Date.init) {
        self.client = client
        self.currentDate = currentDate
    }

    public func load(completion: @escaping (PlantDeviceRawReadingLoader.Result) -> Void) {
        client.read(.readings) { [currentDate] result in
            completion(Self.map(result, receivedAt: currentDate()))
        }
    }

    public func subscribe(update: @escaping (PlantDeviceRawReadingLoader.Result) -> Void) {
        client.subscribe(to: .readings) { [currentDate] result in
            update(Self.map(result, receivedAt: currentDate()))
        }
    }

    private static func map(_ result: PeripheralClient.Result, receivedAt: Date) -> PlantDeviceRawReadingLoader.Result {
        switch result {
        case .success(let data):
            return PlantDeviceRawReadingLoader.Result(catching: {
                try PlantDeviceRawReadingMapper.map(data, receivedAt: receivedAt)
            })
        case .failure:
            return .failure(Error.connectivity)
        }
    }
}
