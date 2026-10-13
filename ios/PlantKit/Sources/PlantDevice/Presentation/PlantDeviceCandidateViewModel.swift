import Foundation

public final class PlantDeviceCandidateViewModel: Equatable {
    public let candidate: PlantDeviceCandidate
    public var name: String { candidate.name }
    /// 1...3, from the signal strength.
    public let signalBars: Int

    public init(candidate: PlantDeviceCandidate) {
        self.candidate = candidate
        signalBars = switch candidate.rssi {
        case (-60)...: 3
        case (-75)...: 2
        default: 1
        }
    }

    public static func == (lhs: PlantDeviceCandidateViewModel, rhs: PlantDeviceCandidateViewModel) -> Bool {
        lhs.candidate == rhs.candidate
    }
}
