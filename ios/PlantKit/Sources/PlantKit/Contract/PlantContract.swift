import Foundation

/// Constants from `docs/BLE_CONTRACT.md` (v1).
public enum PlantContract {
    public static let version: UInt8 = 1

    public static let serviceUUID = UUID(uuidString: "7697A001-5F72-4B79-B7A4-6632379F2F13")!
    public static let readingsUUID = UUID(uuidString: "7697A002-5F72-4B79-B7A4-6632379F2F13")!
    public static let deviceInfoUUID = UUID(uuidString: "7697A003-5F72-4B79-B7A4-6632379F2F13")!
    public static let commandUUID = UUID(uuidString: "7697A004-5F72-4B79-B7A4-6632379F2F13")!

    public static let localNamePrefix = "TalkingPlant-"

    public static let readingPacketLength = 16
    public static let deviceInfoLength = 8
}

public enum PlantContractError: Error, Equatable, Sendable {
    case wrongLength(expected: Int, actual: Int)
    case unsupportedVersion(UInt8)
}

/// Little-endian reads over a byte array. Callers check the length first.
extension Array where Element == UInt8 {
    func uint16LE(at offset: Int) -> UInt16 {
        UInt16(self[offset]) | UInt16(self[offset + 1]) << 8
    }

    func int16LE(at offset: Int) -> Int16 {
        Int16(bitPattern: uint16LE(at: offset))
    }

    func uint32LE(at offset: Int) -> UInt32 {
        UInt32(uint16LE(at: offset)) | UInt32(uint16LE(at: offset + 2)) << 16
    }
}
