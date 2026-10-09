import Foundation

/// Constants from `docs/BLE_CONTRACT.md` (v1).
public enum PlantBluetoothContract {
    public static let protocolVersion: UInt8 = 1

    public static let serviceUUID = UUID(uuidString: "7697A001-5F72-4B79-B7A4-6632379F2F13")!

    public static let localNamePrefix = "TalkingPlant-"

    public static let readingLength = 16
    public static let deviceInfoLength = 8
}
