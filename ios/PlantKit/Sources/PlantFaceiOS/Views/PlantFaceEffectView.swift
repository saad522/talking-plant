import SwiftUI

public enum PlantFaceEffect: Equatable, Hashable, Sendable {
    case puddle
    case sparkles
    case potCracks
    case sweat
    case shiver
    case zzz
    case drops
}

public struct PlantFaceEffectView: View {
    public let effect: PlantFaceEffect

    init(effect: PlantFaceEffect) {
        self.effect = effect
    }

    public var body: some View {
        ZStack(alignment: .topLeading) {
            switch effect {
            case .puddle:
                PlantFaceEllipseShape(cx: 120, cy: 275, rx: 84, ry: 8).fill(PlantFaceColor.puddle)
            case .sparkles:
                PlantFaceSparkleShape(cx: 46, cy: 74, size: 9).fill(PlantFaceColor.sparkle)
                PlantFaceSparkleShape(cx: 198, cy: 56, size: 7).fill(PlantFaceColor.sparkle)
            case .potCracks:
                PlantFacePathShape(segments: [
                    .move(90, 234), .line(96, 242), .line(93, 252),
                    .move(150, 230), .line(145, 240), .line(149, 248),
                ])
                .stroke(PlantFaceColor.potCrack, style: line(PlantFaceLine.crack))
            case .sweat:
                PlantFaceDropShape(cx: 170, cy: 96).fill(PlantFaceColor.sweat)
                PlantFaceDropShape(cx: 70, cy: 108).fill(PlantFaceColor.sweat)
            case .shiver:
                PlantFacePathShape(segments: shiverLines)
                .stroke(PlantFaceColor.shiver, style: line(PlantFaceLine.shiver))
            case .zzz:
                zzz("Z", size: 22, x: 168, y: 72)
                zzz("z", size: 16, x: 188, y: 50)
                zzz("z", size: 11, x: 204, y: 34)
            case .drops:
                PlantFaceDropShape(cx: 58, cy: 46).fill(PlantFaceColor.drop)
                PlantFaceDropShape(cx: 184, cy: 40).fill(PlantFaceColor.drop)
                PlantFaceDropShape(cx: 150, cy: 16).fill(PlantFaceColor.drop)
            }
        }
        .frame(width: PlantFaceSize.viewBox.width, height: PlantFaceSize.viewBox.height, alignment: .topLeading)
    }

    private var shiverLines: [PlantFaceSegment] {
        let ys: [CGFloat] = [108, 128, 148]
        return ys.flatMap { y in
            [PlantFaceSegment.move(44, y), .line(62, y), .move(178, y), .line(196, y)]
        }
    }

    private func line(_ width: CGFloat) -> StrokeStyle {
        StrokeStyle(lineWidth: width, lineCap: PlantFaceLine.cap, lineJoin: PlantFaceLine.join)
    }

    private func zzz(_ letter: String, size: CGFloat, x: CGFloat, y: CGFloat) -> some View {
        Text(letter)
            .font(.system(size: size, weight: .heavy, design: .rounded))
            .foregroundStyle(PlantFaceColor.zzz)
            .position(x: x, y: y)
    }
}
