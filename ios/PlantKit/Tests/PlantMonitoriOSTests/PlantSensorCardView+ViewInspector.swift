import PlantMonitoriOS
import SwiftUI
import ViewInspector

extension PlantSensorCardView {
    var title: String? { try? inspect().vStack().text(0).string() }
    var value: String? { try? inspect().vStack().text(1).string() }
}
