import Foundation

/// Decides when a pending connect by identifier gets a scan by name as a second chance. A
/// peripheral that rotates its Bluetooth address (an iPhone acting as the test board) leaves
/// the saved identifier stale, and the pending connect never succeeds. The connect by
/// identifier stays the first try; only after `delay` does the scan start.
struct ReconnectFallbackPolicy {
    static let delay: Duration = .seconds(5)

    private(set) var isScanning = false

    /// True when the scan should start now. False if the connection already succeeded or
    /// there is nothing to connect to.
    mutating func delayElapsed(hasTarget: Bool, isConnecting: Bool) -> Bool {
        guard hasTarget, isConnecting, !isScanning else { return false }
        isScanning = true
        return true
    }

    mutating func reset() {
        isScanning = false
    }

    /// True when an advertisement is the saved plant under a new identifier, so the pending
    /// connect should be replaced. Same identifier means the first try is still the right one.
    func shouldAdopt(advertisedIdentifier: UUID, advertisedName: String?, pending: UUID, targetName: String) -> Bool {
        isScanning && advertisedName == targetName && advertisedIdentifier != pending
    }
}
