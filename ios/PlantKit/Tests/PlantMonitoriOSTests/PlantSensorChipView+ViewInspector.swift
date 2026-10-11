import PlantMonitoriOS
import SwiftUI
import ViewInspector

extension PlantSensorChipView {
    var value: String? { texts()?.first }
    var title: String? { texts()?.last }

    private func texts() -> [String]? {
        try? inspect().findAll(ViewType.Text.self).map { try $0.string() }
    }
}
