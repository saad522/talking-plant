import Foundation

/// Commands written to the Command characteristic. The firmware clamps values itself.
public enum PlantCommand: Equatable, Sendable {
    case readNow
    case setInterval(seconds: UInt16)
    case pumpRun(milliseconds: UInt16)
    case pumpStop

    public var opcode: UInt8 {
        switch self {
        case .readNow: 0x01
        case .setInterval: 0x02
        case .pumpRun: 0x10
        case .pumpStop: 0x11
        }
    }

    public var data: Data {
        switch self {
        case .readNow, .pumpStop:
            Data([opcode])
        case .setInterval(let value), .pumpRun(let value):
            Data([opcode, UInt8(value & 0xFF), UInt8(value >> 8)])
        }
    }
}
