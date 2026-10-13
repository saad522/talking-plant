import PlantDevice
import SwiftUI

@MainActor
final class PlantDevicePickerStore: ObservableObject {
    @Published var candidates: [PlantDeviceCandidateViewModel] = []
    @Published var emptyText: String = ""
}
