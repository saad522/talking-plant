import SwiftUI

public enum PlantFaceSoil: Equatable, Sendable {
    case standard
    case dry
    case wet

    var color: Color {
        switch self {
        case .standard: PlantFaceColor.soilDefault
        case .dry: PlantFaceColor.soilDry
        case .wet: PlantFaceColor.soilWet
        }
    }
}

public struct PlantFaceSoilView: View {
    public let soil: PlantFaceSoil

    init(soil: PlantFaceSoil) {
        self.soil = soil
    }

    public var body: some View {
        PlantFaceEllipseShape(cx: 120, cy: 206, rx: 44, ry: 5).fill(soil.color)
    }
}
