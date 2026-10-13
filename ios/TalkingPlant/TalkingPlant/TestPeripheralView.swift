#if DEBUG
import PlantTestPeripheral
import SwiftUI

/// Shown instead of the app when launched with `-PlantTestPeripheral`.
struct TestPeripheralView: View {
    @StateObject private var peripheral = CoreBluetoothPlantTestPeripheral()

    var body: some View {
        NavigationStack {
            List {
                Section {
                    LabeledContent("Name", value: CoreBluetoothPlantTestPeripheral.localName)
                    LabeledContent("Status", value: statusText)
                    LabeledContent("Subscribers", value: "\(peripheral.subscriberCount)")
                    LabeledContent("Interval", value: "\(peripheral.intervalSeconds) s")
                    Button("Water") { peripheral.water() }
                }
                Section("Log") {
                    ForEach(Array(peripheral.log.enumerated()), id: \.offset) { _, line in
                        Text(line).font(.footnote.monospaced())
                    }
                }
            }
            .navigationTitle("Test peripheral")
        }
        .onAppear { peripheral.start() }
    }

    private var statusText: String {
        switch peripheral.status {
        case .stopped: "Starting…"
        case .unsupported: "Bluetooth unsupported"
        case .unauthorized: "Bluetooth not allowed"
        case .poweredOff: "Bluetooth is off"
        case .advertising: "Advertising"
        }
    }
}
#endif
