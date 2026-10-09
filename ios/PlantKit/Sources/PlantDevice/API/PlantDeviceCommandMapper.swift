import Foundation

enum PlantDeviceCommandMapper {
    private enum Opcode: UInt8 {
        case readNow = 0x01
        case setInterval = 0x02
        case pumpRun = 0x10
        case pumpStop = 0x11
    }

    static func map(_ command: PlantDeviceCommand) -> Data {
        switch command {
        case .readNow:
            Data([Opcode.readNow.rawValue])
        case .setInterval(let seconds):
            Data([Opcode.setInterval.rawValue]) + littleEndian(seconds)
        case .pumpRun(let milliseconds):
            Data([Opcode.pumpRun.rawValue]) + littleEndian(milliseconds)
        case .pumpStop:
            Data([Opcode.pumpStop.rawValue])
        }
    }

    private static func littleEndian(_ value: UInt16) -> Data {
        Data([UInt8(value & 0xFF), UInt8(value >> 8)])
    }
}
