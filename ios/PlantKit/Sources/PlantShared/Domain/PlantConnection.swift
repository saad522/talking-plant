public enum PlantConnection: Equatable, Sendable {
    case notPaired
    case connecting
    case connected
    case offline                // still connecting after the grace period
    case bluetoothOff
    case bluetoothUnauthorized
    case bluetoothUnsupported
    case incompatible
}
