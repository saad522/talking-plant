import PlantDevice
import PlantDeviceiOS
import SwiftUI
import ViewInspector

extension PlantDeviceView {
    func simulateAppear() {
        try? inspect().find(ViewType.Form.self).callOnAppear()
    }

    /// Every text on the screen, in order.
    var texts: [String] {
        (try? inspect().findAll(ViewType.Text.self).compactMap { try? $0.string() }) ?? []
    }

    func hasButton(_ label: String) -> Bool {
        (try? inspect().find(button: label)) != nil
    }

    func simulateTap(_ label: String) {
        try? inspect().find(button: label).tap()
    }

    func simulateSelectMode(_ mode: PlantDeviceMode) {
        try? inspect().find(ViewType.Picker.self).select(value: mode)
    }
}
