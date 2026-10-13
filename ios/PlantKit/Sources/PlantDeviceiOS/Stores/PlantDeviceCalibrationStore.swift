import PlantDevice
import SwiftUI

@MainActor
final class PlantDeviceCalibrationStore: ObservableObject {
    @Published var status: PlantDeviceCalibrationStatusViewModel?
    @Published var liveSoil: String = ""
    @Published var dryDraft: String?
    @Published var wetDraft: String?
    @Published var capturing: PlantDeviceCalibrationPoint?
    @Published var canCapture: Bool = false
    @Published var canSave: Bool = false
    @Published var message: String?
    @Published var warning: String?
}
