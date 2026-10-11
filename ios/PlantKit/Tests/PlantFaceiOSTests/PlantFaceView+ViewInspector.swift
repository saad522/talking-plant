import PlantFaceiOS
import SwiftUI
import ViewInspector

extension PlantFaceView {
    func renderedEyes() -> [PlantFaceEyeKind] {
        (try? inspect().findAll(PlantFaceEyesView.self).map { try $0.actualView().kind }) ?? []
    }

    func renderedEffects() -> Set<PlantFaceEffect> {
        Set((try? inspect().findAll(PlantFaceEffectView.self).map { try $0.actualView().effect }) ?? [])
    }

    func renderedSoil() -> [PlantFaceSoil] {
        (try? inspect().findAll(PlantFaceSoilView.self).map { try $0.actualView().soil }) ?? []
    }
}
