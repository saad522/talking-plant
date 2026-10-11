import PlantFace
import SwiftUI

public enum PlantFaceEyeKind: Equatable, Sendable {
    case open
    /// Open eyes with heavy lids, for thirsty.
    case lidded
    case closed
    case squint
}

/// One path command in viewBox coordinates.
enum PlantFaceSegment {
    case move(CGFloat, CGFloat)
    case line(CGFloat, CGFloat)
    case quad(to: CGPoint, control: CGPoint)
    case close
}

/// Every number of DESIGN.md section 5.2 for one visual state.
struct PlantFacePose {
    let head: Color
    let leaf: Color
    let vein: Color
    let stem: Color
    let tilt: Double
    let topLeft: Double
    let topRight: Double
    let topScale: CGFloat
    let topY: CGFloat
    let armLeft: Double
    let armRight: Double
    let armScale: CGFloat
    let eyes: PlantFaceEyeKind
    let eyeRy: CGFloat
    let browLeft: [PlantFaceSegment]
    let browRight: [PlantFaceSegment]
    let mouth: [PlantFaceSegment]
    let mouthFilled: Bool
    let blush: Double

    static func pose(for state: PlantFaceState) -> PlantFacePose {
        switch state {
        case .happy: happy
        case .thirsty: thirsty
        case .hot: hot
        case .cold: cold
        case .asleep: asleep
        case .overwatered: overwatered
        }
    }

    private static let happy = PlantFacePose(
        head: Color(hex: 0x62BE70), leaf: Color(hex: 0x3FA35B), vein: Color(hex: 0x2C7A43), stem: Color(hex: 0x3A9452),
        tilt: 0, topLeft: -32, topRight: 32, topScale: 0.55, topY: 78,
        armLeft: -62, armRight: 62, armScale: 0.42,
        eyes: .open, eyeRy: 9,
        browLeft: brow(95, 108, 103, 104, 111, 107), browRight: brow(129, 107, 137, 104, 145, 108),
        mouth: [.move(108, 142), .quad(to: CGPoint(x: 132, y: 142), control: CGPoint(x: 120, y: 152))],
        mouthFilled: false, blush: 0.85
    )

    private static let thirsty = PlantFacePose(
        head: Color(hex: 0xB9C46E), leaf: Color(hex: 0xA3B65C), vein: Color(hex: 0x7D8C3F), stem: Color(hex: 0x8FA04E),
        tilt: 16, topLeft: -104, topRight: 96, topScale: 0.50, topY: 80,
        armLeft: -128, armRight: 124, armScale: 0.40,
        eyes: .lidded, eyeRy: 9,
        browLeft: brow(95, 106, 103, 109, 111, 104), browRight: brow(129, 104, 137, 109, 145, 106),
        mouth: [.move(110, 148), .quad(to: CGPoint(x: 130, y: 148), control: CGPoint(x: 120, y: 141))],
        mouthFilled: false, blush: 0
    )

    private static let hot = PlantFacePose(
        head: Color(hex: 0x5BB86A), leaf: Color(hex: 0x4E9E57), vein: Color(hex: 0x367842), stem: Color(hex: 0x3A9452),
        tilt: 0, topLeft: -42, topRight: 42, topScale: 0.55, topY: 78,
        armLeft: -30, armRight: 62, armScale: 0.42,
        eyes: .squint, eyeRy: 0,
        browLeft: brow(95, 108, 103, 105, 111, 108), browRight: brow(129, 108, 137, 105, 145, 108),
        mouth: [
            .move(106, 146),
            .quad(to: CGPoint(x: 116, y: 146), control: CGPoint(x: 111, y: 140)),
            .quad(to: CGPoint(x: 126, y: 146), control: CGPoint(x: 121, y: 152)),
            .quad(to: CGPoint(x: 134, y: 144), control: CGPoint(x: 131, y: 140)),
        ],
        mouthFilled: false, blush: 1
    )

    private static let cold = PlantFacePose(
        head: Color(hex: 0x7DC2B0), leaf: Color(hex: 0x5BA697), vein: Color(hex: 0x3E8074), stem: Color(hex: 0x4A9585),
        tilt: 0, topLeft: -18, topRight: 18, topScale: 0.50, topY: 78,
        armLeft: -96, armRight: 96, armScale: 0.40,
        eyes: .squint, eyeRy: 0,
        browLeft: brow(95, 106, 103, 109, 111, 104), browRight: brow(129, 104, 137, 109, 145, 106),
        mouth: [.move(106, 145), .line(111, 149), .line(116, 143), .line(121, 149), .line(126, 143), .line(132, 147)],
        mouthFilled: false, blush: 0
    )

    private static let asleep = PlantFacePose(
        head: Color(hex: 0x56AE66), leaf: Color(hex: 0x3B8F55), vein: Color(hex: 0x2A6B3E), stem: Color(hex: 0x33874A),
        tilt: -4, topLeft: -48, topRight: 44, topScale: 0.52, topY: 78,
        armLeft: -80, armRight: 78, armScale: 0.42,
        eyes: .closed, eyeRy: 0,
        browLeft: brow(96, 110, 103, 108, 110, 110), browRight: brow(130, 110, 137, 108, 144, 110),
        mouth: [.move(115, 145), .quad(to: CGPoint(x: 125, y: 145), control: CGPoint(x: 120, y: 148))],
        mouthFilled: false, blush: 0.5
    )

    private static let overwatered = PlantFacePose(
        head: Color(hex: 0x4FA06A), leaf: Color(hex: 0x4FA06A), vein: Color(hex: 0x357A4C), stem: Color(hex: 0x3A8F55),
        tilt: 0, topLeft: -70, topRight: 70, topScale: 0.52, topY: 78,
        armLeft: -100, armRight: 100, armScale: 0.42,
        eyes: .open, eyeRy: 11,
        browLeft: brow(94, 104, 103, 98, 111, 102), browRight: brow(129, 102, 137, 98, 146, 104),
        mouth: [
            .move(111, 146),
            .quad(to: CGPoint(x: 129, y: 146), control: CGPoint(x: 120, y: 157)),
            .quad(to: CGPoint(x: 111, y: 146), control: CGPoint(x: 120, y: 137)),
            .close,
        ],
        mouthFilled: true, blush: 0
    )

    private static func brow(
        _ x0: CGFloat, _ y0: CGFloat, _ cx: CGFloat, _ cy: CGFloat, _ x1: CGFloat, _ y1: CGFloat
    ) -> [PlantFaceSegment] {
        [.move(x0, y0), .quad(to: CGPoint(x: x1, y: y1), control: CGPoint(x: cx, y: cy))]
    }
}
