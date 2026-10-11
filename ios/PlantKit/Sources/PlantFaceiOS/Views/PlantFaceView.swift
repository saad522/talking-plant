import PlantFace
import SwiftUI

public struct PlantFaceView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isBlinking = false
    @State private var isBreathingIn = false

    private let viewModel: PlantFaceViewModel

    init(viewModel: PlantFaceViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        ZStack {
            Circle().fill(PlantFaceColor.background)

            HStack(spacing: PlantFaceSize.eyeSpacing) {
                PlantFaceEyeView(eyes: viewModel.eyes, isBlinking: isBlinking)
                PlantFaceEyeView(eyes: viewModel.eyes, isBlinking: isBlinking)
            }
            .offset(y: PlantFaceSize.eyesOffset)

            PlantFaceMouthView(curve: viewModel.mouthCurve, isOpen: viewModel.isMouthOpen)
                .offset(y: PlantFaceSize.mouthOffset)
        }
        .frame(width: PlantFaceSize.face, height: PlantFaceSize.face)
        .scaleEffect(isBreathingIn && !reduceMotion ? PlantFaceSize.breathingScale : 1)
        .animation(reduceMotion ? nil : PlantFaceAnimation.expression, value: viewModel.mouthCurve)
        .animation(reduceMotion ? nil : PlantFaceAnimation.expression, value: viewModel.eyes)
        .accessibilityHidden(true)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(PlantFaceAnimation.breathing) { isBreathingIn = true }
        }
        .task(id: viewModel.blinks && !reduceMotion) {
            guard viewModel.blinks && !reduceMotion else { return }
            await blinkRepeatedly()
        }
    }

    private func blinkRepeatedly() async {
        while !Task.isCancelled {
            do {
                try await Task.sleep(for: PlantFaceAnimation.blinkInterval)
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
