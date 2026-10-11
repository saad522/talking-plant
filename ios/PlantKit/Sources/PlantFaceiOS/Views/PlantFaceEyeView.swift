import PlantFace
import SwiftUI

public struct PlantFaceEyeView: View {
    public let eyes: PlantFaceEyes
    public let isBlinking: Bool

    init(eyes: PlantFaceEyes, isBlinking: Bool) {
        self.eyes = eyes
        self.isBlinking = isBlinking
    }

    public var body: some View {
        Ellipse()
            .fill(PlantFaceColor.feature)
            .frame(width: PlantFaceSize.eyeWidth, height: PlantFaceSize.eyeHeight * heightRatio)
            .frame(height: PlantFaceSize.eyeSlotHeight)
    }

    private var heightRatio: CGFloat {
        isBlinking ? PlantFaceSize.blinkHeightRatio : PlantFaceSize.eyeHeightRatio(for: eyes)
    }
}
