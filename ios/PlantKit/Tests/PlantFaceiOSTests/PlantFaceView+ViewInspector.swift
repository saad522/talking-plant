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

    func renderedEyeRy() -> [CGFloat] {
        (try? inspect().findAll(PlantFaceEyesView.self).map { try $0.actualView().ry }) ?? []
    }

    func renderedMouthFilled() -> [Bool] {
        (try? inspect().findAll(PlantFaceMouthView.self).map { try $0.actualView().isFilled }) ?? []
    }
}
