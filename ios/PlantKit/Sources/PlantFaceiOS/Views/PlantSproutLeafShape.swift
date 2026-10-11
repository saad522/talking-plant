import SwiftUI

/// A leaf pointing up from its origin (0, 0). Place it with offset, rotation and scale around that origin.
struct PlantSproutLeafShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addCurve(to: CGPoint(x: 0, y: -96), control1: CGPoint(x: -24, y: -26), control2: CGPoint(x: -22, y: -70))
        path.addCurve(to: CGPoint(x: 0, y: 0), control1: CGPoint(x: 22, y: -70), control2: CGPoint(x: 24, y: -26))
        path.closeSubpath()
        return path
    }
}

struct PlantSproutVeinShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: -8))
        path.addLine(to: CGPoint(x: 0, y: -80))
        return path
    }
}
