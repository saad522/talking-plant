import PlantFace
import SwiftUI

public struct PlantFaceView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isBlinking = false
    @State private var isBreathingIn = false
    @State private var isSwayingForward = false

    private let viewModel: PlantFaceViewModel

    init(viewModel: PlantFaceViewModel) {
        self.viewModel = viewModel
    }

    /// Everything that changes the drawing, so every change morphs, not only a new state.
    private struct Look: Hashable {
        let state: PlantFaceState
        let drySoil: Bool
        let extraTilt: Double
    }

    public var body: some View {
        ZStack {
            character
                // Reduce Motion: a new identity per state turns the morph into a cross-fade.
                .id(reduceMotion ? viewModel.state : nil)
                .transition(.opacity)
        }
        .frame(width: PlantFaceSize.face.width, height: PlantFaceSize.face.height)
        .animation(
            reduceMotion ? PlantFaceAnimation.crossFade : PlantFaceAnimation.morph,
            value: Look(state: viewModel.state, drySoil: viewModel.drySoil, extraTilt: viewModel.extraTilt)
        )
        .accessibilityHidden(true)
        .onAppear {
            guard !reduceMotion else { return }
            // No withAnimation: the repeating animations are scoped to the views they drive,
            // so layout changes elsewhere in the screen never pick them up.
            isBreathingIn = true
            isSwayingForward = true
        }
        .task(id: viewModel.blinks && !reduceMotion) {
            guard viewModel.blinks && !reduceMotion else { return }
            await blinkRepeatedly()
        }
    }

    private var pose: PlantFacePose {
        PlantFacePose.pose(for: viewModel.state)
    }

    private var soil: PlantFaceSoil {
        if viewModel.state == .overwatered { .wet } else if viewModel.drySoil { .dry } else { .standard }
    }

    private var backEffects: [PlantFaceEffect] {
        viewModel.state == .overwatered ? [.puddle] : []
    }

    private var frontEffects: [PlantFaceEffect] {
        switch viewModel.state {
        case .happy: [.sparkles]
        case .thirsty: viewModel.drySoil ? [.potCracks] : []
        case .hot: [.sweat]
        case .cold: [.shiver]
        case .asleep: [.zzz]
        case .overwatered: [.drops]
        }
    }

    private var character: some View {
        ZStack(alignment: .topLeading) {
            effects(backEffects)
            PlantFaceEllipseShape(cx: 120, cy: 274, rx: 52, ry: 5).fill(PlantFaceColor.inkShadow.opacity(0.1))
            plant
            pot
            effects(frontEffects)
        }
        .frame(width: PlantFaceSize.viewBox.width, height: PlantFaceSize.viewBox.height, alignment: .topLeading)
        .scaleEffect(PlantFaceSize.faceScale)
    }

    private func effects(_ effects: [PlantFaceEffect]) -> some View {
        ForEach(effects, id: \.self) { effect in
            PlantFaceEffectView(effect: effect).transition(.opacity)
        }
    }

    private var plant: some View {
        ZStack(alignment: .topLeading) {
            PlantFacePathShape(segments: [.move(120, 206), .line(120, 176)])
                .stroke(pose.stem, style: StrokeStyle(lineWidth: PlantFaceLine.stem, lineCap: PlantFaceLine.cap))
            arm(angle: pose.armLeft)
            arm(angle: pose.armRight)
            head
        }
    }

    private func arm(angle: Double) -> some View {
        PlantSproutLeafView(fill: pose.leaf, vein: nil, angle: angle, scale: pose.armScale, origin: PlantFaceSize.armOrigin)
    }

    private func topLeaf(angle: Double) -> some View {
        PlantSproutLeafView(
            fill: pose.leaf,
            vein: pose.vein,
            angle: angle + swayOffset,
            scale: pose.topScale,
            origin: CGPoint(x: PlantFaceSize.topLeafX, y: pose.topY)
        )
        .animation(reduceMotion ? nil : PlantFaceAnimation.sway, value: isSwayingForward)
    }

    private var swayOffset: Double {
        reduceMotion ? 0 : (isSwayingForward ? PlantFaceSize.swayDegrees : -PlantFaceSize.swayDegrees)
    }

    private var breathingScale: CGFloat {
        reduceMotion || !isBreathingIn ? PlantFaceSize.breathingScale : PlantFaceSize.breathingScaleIn
    }

    private var head: some View {
        ZStack(alignment: .topLeading) {
            topLeaf(angle: pose.topLeft)
            topLeaf(angle: pose.topRight)
            PlantFaceEllipseShape(
                cx: PlantFaceSize.headCenter.x, cy: PlantFaceSize.headCenter.y,
                rx: PlantFaceSize.headRadius, ry: PlantFaceSize.headRadius
            )
            .fill(pose.head)
            PlantFaceEllipseShape(cx: 100, cy: 102, rx: 18, ry: 9).fill(PlantFaceColor.highlight.opacity(0.28))
            blush
            features
        }
        .frame(width: PlantFaceSize.viewBox.width, height: PlantFaceSize.viewBox.height, alignment: .topLeading)
        .animation(PlantFaceAnimation.breathing, body: { content in
            content.scaleEffect(breathingScale, anchor: PlantFaceSize.headPivot)
        })
        .rotationEffect(.degrees(pose.tilt + viewModel.extraTilt), anchor: PlantFaceSize.headPivot)
    }

    private var blush: some View {
        ZStack(alignment: .topLeading) {
            PlantFaceEllipseShape(cx: 92, cy: 140, rx: 8, ry: 5).fill(PlantFaceColor.blush)
            PlantFaceEllipseShape(cx: 148, cy: 140, rx: 8, ry: 5).fill(PlantFaceColor.blush)
        }
        .opacity(pose.blush)
    }

    /// Keyed by state, so eyes, brows and mouth cross-fade instead of morphing.
    private var features: some View {
        ZStack(alignment: .topLeading) {
            PlantFaceEyesView(kind: pose.eyes, ry: pose.eyeRy, headColor: pose.head, isBlinking: isBlinking)
            PlantFacePathShape(segments: pose.browLeft + pose.browRight)
                .stroke(PlantFaceColor.ink, style: featureLine)
            mouth
        }
        .id(viewModel.state)
        .transition(.opacity)
    }

    @ViewBuilder
    private var mouth: some View {
        let shape = PlantFacePathShape(segments: pose.mouth)
        if pose.mouthFilled {
            shape.fill(PlantFaceColor.ink)
            shape.stroke(PlantFaceColor.ink, style: featureLine)
        } else {
            shape.stroke(PlantFaceColor.ink, style: featureLine)
        }
    }

    private var featureLine: StrokeStyle {
        StrokeStyle(lineWidth: PlantFaceLine.feature, lineCap: PlantFaceLine.cap, lineJoin: PlantFaceLine.join)
    }

    private var pot: some View {
        ZStack(alignment: .topLeading) {
            PlantFacePotBodyShape().fill(PlantFaceColor.potBody)
            RoundedRectangle(cornerRadius: 11)
                .fill(PlantFaceColor.potRim)
                .frame(width: 104, height: 22)
                .offset(x: 68, y: 202)
            PlantFaceSoilView(soil: soil)
        }
    }

    private func blinkRepeatedly() async {
        while !Task.isCancelled {
            do {
                try await Task.sleep(for: .seconds(Double.random(in: PlantFaceAnimation.blinkInterval)))
                withAnimation(PlantFaceAnimation.blink) { isBlinking = true }
                try await Task.sleep(for: PlantFaceAnimation.blinkDuration)
                withAnimation(PlantFaceAnimation.blink) { isBlinking = false }
            } catch {
                isBlinking = false
                return
            }
        }
    }
}
