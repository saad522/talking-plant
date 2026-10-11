import SwiftUI

// Every shape here draws in absolute viewBox coordinates (240 x 280) and ignores its rect.

/// Animatable `ry`, so blinks and eye changes morph.
struct PlantFaceEllipseShape: Shape {
    let cx: CGFloat
    let cy: CGFloat
    let rx: CGFloat
    var ry: CGFloat

    var animatableData: CGFloat {
        get { ry }
        set { ry = newValue }
    }

    func path(in rect: CGRect) -> Path {
        Path(ellipseIn: CGRect(x: cx - rx, y: cy - ry, width: rx * 2, height: ry * 2))
    }
}

/// Move, line and quad commands, for brows, mouths, arcs, lids and cracks.
struct PlantFacePathShape: Shape {
    let segments: [PlantFaceSegment]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        for segment in segments {
            switch segment {
            case let .move(x, y): path.move(to: CGPoint(x: x, y: y))
            case let .line(x, y): path.addLine(to: CGPoint(x: x, y: y))
            case let .quad(to, control): path.addQuadCurve(to: to, control: control)
            case .close: path.closeSubpath()
            }
        }
        return path
    }
}

struct PlantFacePotBodyShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 78, y: 220))
        path.addLine(to: CGPoint(x: 162, y: 220))
        path.addLine(to: CGPoint(x: 154, y: 262))
        path.addQuadCurve(to: CGPoint(x: 144, y: 270), control: CGPoint(x: 152, y: 270))
        path.addLine(to: CGPoint(x: 96, y: 270))
        path.addQuadCurve(to: CGPoint(x: 86, y: 262), control: CGPoint(x: 88, y: 270))
        path.closeSubpath()
        return path
    }
}

/// A 4-point star of the given size (its outer radius) centered on (cx, cy).
struct PlantFaceSparkleShape: Shape {
    let cx: CGFloat
    let cy: CGFloat
    let size: CGFloat

    func path(in rect: CGRect) -> Path {
        let k = size / 9
        let points: [(CGFloat, CGFloat)] = [(0, -9), (2.5, -2.5), (9, 0), (2.5, 2.5), (0, 9), (-2.5, 2.5), (-9, 0), (-2.5, -2.5)]
        var path = Path()
        for (index, point) in points.enumerated() {
            let p = CGPoint(x: cx + point.0 * k, y: cy + point.1 * k)
            index == 0 ? path.move(to: p) : path.addLine(to: p)
        }
        path.closeSubpath()
        return path
    }
}

/// A teardrop about 10 x 14 centered on (cx, cy).
struct PlantFaceDropShape: Shape {
    let cx: CGFloat
    let cy: CGFloat

    func path(in rect: CGRect) -> Path {
        let halfWidth = PlantFaceSize.dropSize.width / 2
        let halfHeight = PlantFaceSize.dropSize.height / 2
        var path = Path()
        path.move(to: CGPoint(x: cx, y: cy - halfHeight))
        path.addCurve(
            to: CGPoint(x: cx + halfWidth, y: cy + 3),
            control1: CGPoint(x: cx + 1.5, y: cy - 3),
            control2: CGPoint(x: cx + halfWidth, y: cy - 1)
        )
        path.addCurve(
            to: CGPoint(x: cx, y: cy + halfHeight),
            control1: CGPoint(x: cx + halfWidth, y: cy + 5.5),
            control2: CGPoint(x: cx + 2.8, y: cy + halfHeight)
        )
        path.addCurve(
            to: CGPoint(x: cx - halfWidth, y: cy + 3),
            control1: CGPoint(x: cx - 2.8, y: cy + halfHeight),
            control2: CGPoint(x: cx - halfWidth, y: cy + 5.5)
        )
        path.addCurve(
            to: CGPoint(x: cx, y: cy - halfHeight),
            control1: CGPoint(x: cx - halfWidth, y: cy - 1),
            control2: CGPoint(x: cx - 1.5, y: cy - 3)
        )
        path.closeSubpath()
        return path
    }
}
