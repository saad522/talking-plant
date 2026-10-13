import PlantDevice
import SwiftUI

@MainActor
final class PlantDeviceStore: ObservableObject {
    @Published var mode: PlantDeviceMode = .simulated
    @Published var connection: PlantDeviceConnectionViewModel?
    /// Name of the paired sensor; `nil` when none is paired.
    @Published var pairedName: String?
    @Published var info: PlantDeviceInfoViewModel?
    @Published var commandError: String?
}
