import PlantIntro
import PlantShared
import SwiftUI

public struct PlantIntroView: View {
    @ObservedObject private var viewModel: PlantIntroViewModel
    @State private var start = Date()
    private let sprout: Image
    private let sproutBlink: Image
    private let sproutHeight: CGFloat
    private let launchBackground: Color
    private let handoffBackground: Color
    private let haptics: PlantHapticsClient
    private let particles = PlantIntroParticle.make()

    init(
        viewModel: PlantIntroViewModel,
        sprout: Image,
        sproutBlink: Image,
        sproutHeight: CGFloat,
        launchBackground: Color,
        handoffBackground: Color,
        haptics: PlantHapticsClient
    ) {
        self.viewModel = viewModel
        self.sprout = sprout
        self.sproutBlink = sproutBlink
        self.sproutHeight = sproutHeight
        self.launchBackground = launchBackground
        self.handoffBackground = handoffBackground
        self.haptics = haptics
    }

    private var isHandingOff: Bool { viewModel.state == .handingOff }

    public var body: some View {
        // The background fills the screen; the content is centred in the safe area, as the launch screen does.
        ZStack {
            launchBackground.ignoresSafeArea()
            handoffBackground.ignoresSafeArea().opacity(isHandingOff ? 1 : 0)
            if viewModel.playsMotion {
                TimelineView(.animation) { context in
                    let time = max(0, context.date.timeIntervalSince(start))
                    ZStack {
                        particleLayer(at: time).ignoresSafeArea()
                        sproutLayer(at: time)
                    }
                }
            } else {
                sprout
            }
        }
        .opacity(isHandingOff ? 0 : 1)
        .animation(.easeInOut(duration: viewModel.handoffDuration), value: isHandingOff)
        .contentShape(Rectangle())
        .onTapGesture(perform: viewModel.skip)
        .accessibilityHidden(true)
        .task(id: viewModel.state) { await advance() }
    }

    private func sproutLayer(at time: Double) -> some View {
        let pose = PlantIntroTimeline.pose(at: time)
        let glow = PlantIntroTimeline.glow(at: time)
        let text = PlantIntroTimeline.textProgress(at: time)
        return (PlantIntroTimeline.isBlinking(at: time) ? sproutBlink : sprout)
            .scaleEffect(x: pose.scaleX, y: pose.scaleY, anchor: .bottom)
            .rotationEffect(.degrees(pose.rotation), anchor: .bottom)
            .offset(y: pose.offsetY)
            .background { glowView(intensity: glow) }
            .overlay(alignment: .top) {
                texts(progress: text)
                    .offset(y: sproutHeight + PlantIntroSize.titleGap)
            }
            .scaleEffect(isHandingOff ? PlantIntroSize.handoffScale : 1)
            .offset(y: isHandingOff ? PlantIntroSize.handoffOffsetY : 0)
    }

    /// Text sits below Sprout without moving it: it is an overlay, so the layout is the image alone.
    private func texts(progress: Double) -> some View {
        VStack(spacing: PlantIntroSize.textSpacing) {
            Text(viewModel.title)
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundStyle(PlantIntroColor.title)
            Text(viewModel.greeting)
                .font(.system(size: 18, weight: .medium, design: .rounded))
                .foregroundStyle(PlantIntroColor.greeting)
        }
        .fixedSize()
        .opacity(isHandingOff ? 0 : progress)
        .offset(y: (1 - progress) * PlantIntroSize.textRise)
    }

    private func glowView(intensity: Double) -> some View {
        let color = viewModel.particleStyle == .fireflies ? PlantIntroColor.fireflyGlow : PlantIntroColor.pollenGlow
        return Circle()
            .fill(RadialGradient(colors: [color.opacity(0.45), color.opacity(0)], center: .center, startRadius: 0, endRadius: PlantIntroSize.glowDiameter / 2))
            .frame(width: PlantIntroSize.glowDiameter, height: PlantIntroSize.glowDiameter)
            .scaleEffect(0.85 + 0.25 * intensity)
            .opacity(intensity)
    }

    private func particleLayer(at time: Double) -> some View {
        let color = viewModel.particleStyle == .fireflies ? PlantIntroColor.firefly : PlantIntroColor.pollen
        return Canvas { context, size in
            for particle in particles {
                guard let state = particle.state(at: time) else { continue }
                let diameter = particle.size
                let rect = CGRect(
                    x: state.x * size.width - diameter / 2,
                    y: state.y * size.height - diameter / 2,
                    width: diameter,
                    height: diameter
                )
                context.opacity = state.opacity * 0.9
                context.fill(Path(ellipseIn: rect), with: .color(color))
            }
        }
        .opacity(isHandingOff ? 0 : 1)
    }

    private func advance() async {
        switch viewModel.state {
        case .ready:
            viewModel.start()
        case .playing:
            do {
                try await Task.sleep(for: .seconds(PlantIntroTimeline.hapticTime))
                haptics.play(.bump)
                try await Task.sleep(for: .seconds(viewModel.handoffDelay - PlantIntroTimeline.hapticTime))
                viewModel.beginHandoff()
            } catch {}
        case .handingOff:
            do {
                try await Task.sleep(for: .seconds(viewModel.handoffDuration))
                viewModel.complete()
            } catch {}
        case .finished:
            break
        }
    }
}
