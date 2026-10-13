import Foundation

@MainActor
public protocol PlantDeviceInfoLoader {
    typealias Result = Swift.Result<PlantDeviceInfo, Error>

    func load(completion: @escaping (Result) -> Void)
}
