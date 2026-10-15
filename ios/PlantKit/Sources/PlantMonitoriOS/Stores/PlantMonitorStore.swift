import PlantMonitor
import PlantShared
import SwiftUI

@MainActor
final class PlantMonitorStore<Face: View>: ObservableObject {
    @Published var palette: PlantMonitorPalette
    @Published var title: String = ""
    @Published var subtitle: String = ""
    @Published var window: PlantMonitorWindowView
    @Published var face: Face?
    @Published var bubble: PlantSpeechBubbleView?
    @Published var chips: [PlantSensorChipView] = []
    @Published var primaryButton: PlantMonitorButtonView?
    @Published var secondaryButtons: [PlantMonitorButtonView] = []
    @Published var loading: LoadingSkeletonView? = LoadingSkeletonView()
    @Published var error: PlantMonitorErrorView?
    /// Set once by the composer. Tapping the character makes Sprout say its line.
    var sproutLabel: String = ""
    var sproutTap: () -> Void = {}
    /// Bumped on every accepted shake, so the scene view wobbles Sprout once per shake.
    @Published var shakeCount = 0
    /// What the face is drawn with, so a scene update during a shake keeps the surprised look.
    var faceMood: PlantMood?
    var isSurprised = false

    /// Starts on `scene`, so the first frame already has the final palette and sky.
    init(scene: PlantMonitorScene, sky: PlantMonitorSkyViewModel) {
        palette = Self.makePalette(for: scene)
        window = Self.makeWindow(sky: sky, isGradual: false)
    }

    static func makeWindow(sky: PlantMonitorSkyViewModel, isGradual: Bool) -> PlantMonitorWindowView {
        PlantMonitorWindowView(
            celestial: sky.body == .moon ? .moon : .sun,
            progress: sky.progress,
            isGradual: isGradual
        )
    }

    static func makePalette(for scene: PlantMonitorScene) -> PlantMonitorPalette {
        switch scene {
        case .day: .day
        case .thirsty: .thirsty
        case .night: .night
        }
    }

    /// Changes when the shape of the content changes, so the scene fade never animates layout.
    struct LayoutKey: Equatable {
        let title: String
        let subtitle: String
        let hasFace: Bool
        let hasBubble: Bool
        let chipCount: Int
        let hasPrimaryButton: Bool
        let secondaryButtonCount: Int
    }

    var layoutKey: LayoutKey {
        LayoutKey(
            title: title,
            subtitle: subtitle,
            hasFace: face != nil,
            hasBubble: bubble != nil,
            chipCount: chips.count,
            hasPrimaryButton: primaryButton != nil,
            secondaryButtonCount: secondaryButtons.count
        )
    }
}
