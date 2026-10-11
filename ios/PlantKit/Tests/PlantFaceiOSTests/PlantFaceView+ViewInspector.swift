import PlantFace
import PlantFaceiOS
import SwiftUI
import ViewInspector

extension PlantFaceView {
    func renderedEyes() -> [PlantFaceEyes] {
        ((try? inspect().findAll(PlantFaceEyeView.self).map { try $0.actualView().eyes }) ?? [])
    }

    func renderedMouth() -> (curve: Double, isOpen: Bool)? {
        guard let mouth = try? inspect().find(PlantFaceMouthView.self).actualView() else { return nil }
        return (mouth.curve, mouth.isOpen)
    }
}
