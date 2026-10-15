import PlantFace
import PlantShared
import SwiftUI

@MainActor
public enum PlantFaceUIComposer {
    public static func composed(mood: PlantMood) -> PlantFaceView {
        composed(mood: mood, isSurprised: false)
    }

    public static func composed(mood: PlantMood, isSurprised: Bool) -> PlantFaceView {
        PlantFaceView(viewModel: PlantFaceViewModel(mood: mood, isSurprised: isSurprised))
    }
}
