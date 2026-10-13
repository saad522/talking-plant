import Foundation

/// Characteristics of the Plant Service from `docs/BLE_CONTRACT.md` (v1).
public enum PlantCharacteristic: Equatable, Sendable, CaseIterable {
    case readings
    case deviceInfo
    case command

    public init?(uuid: UUID) {
        guard let match = Self.allCases.first(where: { $0.uuid == uuid }) else { return nil }
        self = match
    }

    public var uuid: UUID {
        switch self {
        case .readings: UUID(uuidString: "7697A002-5F72-4B79-B7A4-6632379F2F13")!
        case .deviceInfo: UUID(uuidString: "7697A003-5F72-4B79-B7A4-6632379F2F13")!
        case .command: UUID(uuidString: "7697A004-5F72-4B79-B7A4-6632379F2F13")!
        }
    }
}
