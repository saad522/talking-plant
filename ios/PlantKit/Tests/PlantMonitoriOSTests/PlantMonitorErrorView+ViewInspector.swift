import PlantMonitoriOS
import SwiftUI
import ViewInspector

extension PlantMonitorErrorView {
    var description: String? { try? inspect().zStack().vStack(1).text(1).string() }
    var buttonTitle: String? { try? inspect().zStack().vStack(1).button(2).labelView().text().string() }

    func simulateTap() {
        try? inspect().zStack().vStack(1).button(2).tap()
    }
}
