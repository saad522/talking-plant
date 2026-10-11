import SwiftUI

/// A leaf (with an optional vein) placed like `translate(x, y) rotate(angle) scale(scale)` in the viewBox.
struct PlantSproutLeafView: View {
    let fill: Color
    let vein: Color?
    let angle: Double
    let scale: CGFloat
    let origin: CGPoint

    var body: some View {
        ZStack {
            PlantSproutLeafShape().fill(fill)
            if let vein {
                PlantSproutVeinShape().stroke(vein, style: StrokeStyle(lineWidth: PlantFaceLine.vein, lineCap: PlantFaceLine.cap))
            }
        }
        .frame(width: 1, height: 1)
        .scaleEffect(scale, anchor: .topLeading)
        .rotationEffect(.degrees(angle), anchor: .topLeading)
        .offset(x: origin.x, y: origin.y)
    }
}
