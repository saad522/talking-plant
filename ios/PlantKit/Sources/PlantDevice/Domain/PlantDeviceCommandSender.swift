import Foundation

@MainActor
public protocol PlantDeviceCommandSender {
    typealias Result = Error?

    func send(_ command: PlantDeviceCommand, completion: @escaping (Result) -> Void)
}
