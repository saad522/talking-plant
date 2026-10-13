import Foundation
import PlantShared

@MainActor
public final class PlantDevicePickerViewModel {
    public typealias Observer<T> = (T) -> Void

    private let scanLoader: PlantDeviceScanLoader
    private let connectionLoader: PlantDeviceConnectionLoader
    private let pairingLoader: PlantDevicePairingLoader
    private let actionHandler: (PlantDeviceAction) -> Void
    private var candidates: [UUID: PlantDeviceCandidate] = [:]
    private var scanning: Bool = false
    private var subscribed: Bool = false

    public let title: String = String.localised(key: "plant.device.picker.title")

    public var loadedCandidates: Observer<[PlantDeviceCandidateViewModel]>?
    /// What to show while the list is empty.
    public var loadedEmptyText: Observer<String>?

    public init(
        scanLoader: PlantDeviceScanLoader,
        connectionLoader: PlantDeviceConnectionLoader,
        pairingLoader: PlantDevicePairingLoader,
        actionHandler: @escaping (PlantDeviceAction) -> Void
    ) {
        self.scanLoader = scanLoader
        self.connectionLoader = connectionLoader
        self.pairingLoader = pairingLoader
        self.actionHandler = actionHandler
    }

    public func appear() {
        if subscribed == false {
            subscribed = true
            loadedEmptyText?(emptyText(for: nil))
            connectionLoader.subscribe { [weak self] connection in
                guard let self else { return }
                loadedEmptyText?(emptyText(for: connection))
            }
        }
        startScan()
    }

    public func disappear() {
        stopScan()
    }

    public func select(_ candidate: PlantDeviceCandidateViewModel) {
        stopScan()
        pairingLoader.pair(candidate.candidate)
        actionHandler(.paired)
    }

    private func startScan() {
        guard scanning == false else { return }
        scanning = true
        scanLoader.start { [weak self] candidate in
            guard let self else { return }
            candidates[candidate.identifier] = candidate
            loadedCandidates?(
                candidates.values
                    .sorted { ($0.name, $0.identifier.uuidString) < ($1.name, $1.identifier.uuidString) }
                    .map(PlantDeviceCandidateViewModel.init)
            )
        }
    }

    private func stopScan() {
        guard scanning else { return }
        scanning = false
        scanLoader.stop()
    }

    private func emptyText(for connection: PlantConnection?) -> String {
        switch connection {
        case .bluetoothOff: String.localised(key: "plant.device.picker.empty.bluetoothOff")
        case .bluetoothUnauthorized: String.localised(key: "plant.device.picker.empty.bluetoothUnauthorized")
        case .bluetoothUnsupported: String.localised(key: "plant.device.picker.empty.bluetoothUnsupported")
        default: String.localised(key: "plant.device.picker.empty.looking")
        }
    }
}
