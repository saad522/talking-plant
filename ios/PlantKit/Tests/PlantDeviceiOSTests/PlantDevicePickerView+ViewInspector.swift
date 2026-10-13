import PlantDeviceiOS
import SwiftUI
import ViewInspector

extension PlantDevicePickerView {
    func simulateAppear() {
        try? inspect().find(ViewType.List.self).callOnAppear()
    }

    func simulateDisappear() {
        try? inspect().find(ViewType.List.self).callOnDisappear()
    }

    /// Every text on the screen, in order.
    var texts: [String] {
        (try? inspect().findAll(ViewType.Text.self).compactMap { try? $0.string() }) ?? []
    }

    func simulateTap(_ label: String) {
        try? inspect().find(button: label).tap()
    }
}
