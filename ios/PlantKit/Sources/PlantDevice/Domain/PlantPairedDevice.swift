import Foundation

public struct PlantPairedDevice: Equatable, Sendable {
    public let identifier: UUID
    public let name: String

    public init(identifier: UUID, name: String) {
        self.identifier = identifier
        self.name = name
    }
}
