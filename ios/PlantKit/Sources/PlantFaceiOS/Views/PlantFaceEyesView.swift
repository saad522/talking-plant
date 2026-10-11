import SwiftUI

public struct PlantFaceEyesView: View {
    public let kind: PlantFaceEyeKind
    let ry: CGFloat
    let headColor: Color
    let isBlinking: Bool

    init(kind: PlantFaceEyeKind, ry: CGFloat, headColor: Color, isBlinking: Bool) {
        self.kind = kind
        self.ry = ry
        self.headColor = headColor
        self.isBlinking = isBlinking
    }

    public var body: some View {
        ZStack(alignment: .topLeading) {
            switch kind {
            case .open, .lidded:
                openEyes
                if kind == .lidded { lids }
            case .closed:
                arcs(left: (95, 126, 103, 132, 111, 126), right: (129, 126, 137, 132, 145, 126))
            case .squint:
                arcs(left: (96, 127, 103, 118, 110, 127), right: (130, 127, 137, 118, 144, 127))
            }
        }
    }

    private var openEyes: some View {
        ZStack(alignment: .topLeading) {
            PlantFaceEllipseShape(cx: 103, cy: 124, rx: PlantFaceSize.eyeRx, ry: eyeRy).fill(PlantFaceColor.ink)
            PlantFaceEllipseShape(cx: 137, cy: 124, rx: PlantFaceSize.eyeRx, ry: eyeRy).fill(PlantFaceColor.ink)
            PlantFaceEllipseShape(cx: 105.5, cy: 120, rx: 2.5, ry: 2.5).fill(PlantFaceColor.highlight)
                .opacity(isBlinking ? 0 : 1)
            PlantFaceEllipseShape(cx: 139.5, cy: 120, rx: 2.5, ry: 2.5).fill(PlantFaceColor.highlight)
                .opacity(isBlinking ? 0 : 1)
        }
    }

    private var eyeRy: CGFloat {
        isBlinking ? PlantFaceSize.blinkRy : ry
    }

    private var lids: some View {
        ZStack(alignment: .topLeading) {
            PlantFacePathShape(segments: rect(93, 112, 113, 123)).fill(headColor)
            PlantFacePathShape(segments: rect(127, 112, 147, 123)).fill(headColor)
            PlantFacePathShape(segments: [.move(94, 123), .line(112, 123), .move(128, 123), .line(146, 123)])
                .stroke(PlantFaceColor.ink, style: StrokeStyle(lineWidth: PlantFaceLine.lid, lineCap: PlantFaceLine.cap))
        }
    }

    private func rect(_ x0: CGFloat, _ y0: CGFloat, _ x1: CGFloat, _ y1: CGFloat) -> [PlantFaceSegment] {
        [.move(x0, y0), .line(x1, y0), .line(x1, y1), .line(x0, y1), .close]
    }

    private func arcs(
        left: (CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat),
        right: (CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat)
    ) -> some View {
        PlantFacePathShape(segments: arc(left) + arc(right))
            .stroke(PlantFaceColor.ink, style: StrokeStyle(lineWidth: PlantFaceLine.feature, lineCap: PlantFaceLine.cap))
    }

    private func arc(_ p: (CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat)) -> [PlantFaceSegment] {
        [.move(p.0, p.1), .quad(to: CGPoint(x: p.4, y: p.5), control: CGPoint(x: p.2, y: p.3))]
    }
}
