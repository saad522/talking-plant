import Foundation
import PlantShared

@MainActor
public final class PeripheralPlantReadingLoader: PlantReadingLoader {
    private let client: PeripheralClient
    private let calibration: () -> MoistureCalibration
    private let currentDate: () -> Date

    public enum Error: Swift.Error, Equatable {
        case connectivity
        case invalidData
    }

    public init(
        client: PeripheralClient,
        calibration: @escaping () -> MoistureCalibration,
        currentDate: @escaping () -> Date = Date.init
    ) {
        self.client = client
        self.calibration = calibration
        self.currentDate = currentDate
    }

    public func load(completion: @escaping (PlantReadingLoader.Result) -> Void) {
        client.read(.readings) { [calibration, currentDate] result in
            completion(Self.map(result, receivedAt: currentDate(), calibration: calibration()))
        }
    }

    public func subscribe(update: @escaping (PlantReadingLoader.Result) -> Void) {
        client.subscribe(to: .readings) { [calibration, currentDate] result in
            update(Self.map(result, receivedAt: currentDate(), calibration: calibration()))
        }
    }

    private static func map(
        _ result: PeripheralClient.Result,
        receivedAt: Date,
        calibration: MoistureCalibration
    ) -> PlantReadingLoader.Result {
        switch result {
        case .success(let data):
            return PlantReadingLoader.Result(catching: {
                try PlantReadingMapper.map(data, receivedAt: receivedAt, calibration: calibration)
            })
        case .failure:
            return .failure(Error.connectivity)
        }
    }
}
