import SwiftUI

public struct PlantFaceMouthView: View {
    public let curve: Double
    public let isOpen: Bool

    init(curve: Double, isOpen: Bool) {
        self.curve = curve
        self.isOpen = isOpen
    }

    public var body: some View {
        Group {
            if isOpen {
                PlantFaceMouthShape(curve: curve).fill(PlantFaceColor.feature)
            } else {
                PlantFaceMouthShape(curve: curve).stroke(
                    PlantFaceColor.feature,
                    style: StrokeStyle(lineWidth: PlantFaceLine.mouthWidth, lineCap: PlantFaceLine.mouthCap)
                )
            }
        }
        .frame(width: PlantFaceSize.mouthWidth, height: PlantFaceSize.mouthHeight)
    }
}
