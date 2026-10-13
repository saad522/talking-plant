import PlantDeviceiOS
import SwiftUI
import ViewInspector

extension PlantDeviceCalibrationView {
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

    func isButtonDisabled(_ label: String) -> Bool {
        (try? inspect().find(button: label).isDisabled()) ?? false
    }

    var hasSpinner: Bool {
        (try? inspect().find(ViewType.ProgressView.self)) != nil
    }

    func simulateTap(_ label: String) {
        try? inspect().find(button: label).tap()
    }
}
