import Foundation

@MainActor
public protocol PlantDevicePairingLoader {
    /// Delivers the current paired device (or `nil`) immediately, then every change.
    func subscribe(update: @escaping (PlantPairedDevice?) -> Void)
    func pair(_ candidate: PlantDeviceCandidate)
    func forget()
    /// Connects to the saved device, if there is one.
    func connectSaved()
}
