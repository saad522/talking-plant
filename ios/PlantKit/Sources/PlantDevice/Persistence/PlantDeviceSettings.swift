import Foundation
import PlantShared

@MainActor
public final class PlantDeviceSettings {
    static let modeKey = "plant.device.mode"
    static let identifierKey = "plant.device.paired.identifier"
    static let nameKey = "plant.device.paired.name"

    private let defaults: DefaultsClient

    public init(defaults: DefaultsClient) {
        self.defaults = defaults
    }

    /// The saved mode, or `.simulated` when nothing valid is saved.
    public func loadMode() -> PlantDeviceMode {
        defaults.retrieveString(forKey: Self.modeKey).flatMap(PlantDeviceMode.init(rawValue:)) ?? .simulated
    }

    public func saveMode(_ mode: PlantDeviceMode) {
        defaults.set(mode.rawValue, forKey: Self.modeKey)
    }

    /// The saved device, or `nil` when none is saved or the saved identifier is not a valid UUID.
    public func loadPairedDevice() -> PlantPairedDevice? {
        guard let identifier = defaults.retrieveString(forKey: Self.identifierKey).flatMap(UUID.init(uuidString:)),
              let name = defaults.retrieveString(forKey: Self.nameKey) else { return nil }
        return PlantPairedDevice(identifier: identifier, name: name)
    }

    public func savePairedDevice(_ device: PlantPairedDevice) {
        defaults.set(device.identifier.uuidString, forKey: Self.identifierKey)
        defaults.set(device.name, forKey: Self.nameKey)
    }

    /// `DefaultsClient` can't remove a key, so clearing saves empty strings.
    public func clearPairedDevice() {
        defaults.set("", forKey: Self.identifierKey)
        defaults.set("", forKey: Self.nameKey)
    }
}
