import PlantFace
import PlantShared
import SwiftUI

@MainActor
public enum PlantFaceUIComposer {
    public static func composed(mood: PlantMood) -> PlantFaceView {
        PlantFaceView(viewModel: PlantFaceViewModel(mood: mood))
    }
}
