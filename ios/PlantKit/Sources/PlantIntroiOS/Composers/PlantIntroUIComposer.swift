import PlantIntro
import PlantShared
import SwiftUI

@MainActor
public enum PlantIntroUIComposer {
    /// `sprout` and `sproutBlink` are the launch screen image and its eyes-closed twin, same size and framing.
    /// `sproutHeight` is the image's height in points, to place the text under it.
    /// `launchBackground` is the launch screen colour; `handoffBackground` is the home screen's.
    public static func composed(
        viewModel: PlantIntroViewModel,
        sprout: Image,
        sproutBlink: Image,
        sproutHeight: CGFloat,
        launchBackground: Color,
        handoffBackground: Color,
        haptics: PlantHapticsClient,
        sounds: PlantSoundEffectsClient
    ) -> PlantIntroView {
        PlantIntroView(
            viewModel: viewModel,
            sprout: sprout,
            sproutBlink: sproutBlink,
            sproutHeight: sproutHeight,
            launchBackground: launchBackground,
            handoffBackground: handoffBackground,
            haptics: haptics,
            sounds: sounds
        )
    }
}
