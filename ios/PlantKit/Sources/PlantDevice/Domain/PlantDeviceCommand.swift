import Foundation

/// Commands written to the Command characteristic. The firmware clamps values itself.
public enum PlantDeviceCommand: Equatable, Sendable {
    case readNow
    case setInterval(seconds: UInt16)
    case pumpRun(milliseconds: UInt16)
    case pumpStop
}
