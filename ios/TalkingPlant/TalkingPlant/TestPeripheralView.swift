#if DEBUG
import PlantTestPeripheral
import SwiftUI

/// Shown instead of the app when launched with `-PlantTestPeripheral`.
struct TestPeripheralView: View {
    @StateObject private var peripheral = CoreBluetoothPlantTestPeripheral()
    @Environment(\.scenePhase) private var scenePhase

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
                Section("Soil override") {
                    Toggle("Override soil", isOn: overrideBinding)
                    if let millivolts = peripheral.soilOverrideMillivolts {
                        Slider(value: sliderBinding, in: 0...3_300, step: 10)
                        LabeledContent("Soil", value: "\(millivolts) mV")
                        HStack {
                            Button("Air 2450") { peripheral.setSoilOverride(2_450) }
                            Spacer()
                            Button("Water 1050") { peripheral.setSoilOverride(1_050) }
                        }
                        .buttonStyle(.bordered)
                    }
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
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { peripheral.readvertiseInForeground() }
        }
    }

    private var overrideBinding: Binding<Bool> {
        Binding(
            get: { peripheral.soilOverrideMillivolts != nil },
            set: { peripheral.setSoilOverride($0 ? (peripheral.soilOverrideMillivolts ?? 2_450) : nil) }
        )
    }

    private var sliderBinding: Binding<Double> {
        Binding(
            get: { Double(peripheral.soilOverrideMillivolts ?? 0) },
            set: { peripheral.setSoilOverride(UInt16($0)) }
        )
    }

    private var statusText: String {
        switch peripheral.status {
        case .stopped: "Starting…"
        case .unsupported: "Bluetooth unsupported"
        case .unauthorized: "Bluetooth not allowed"
        case .poweredOff: "Bluetooth is off"
        case .resetting: "Bluetooth resetting…"
        case .advertising: "Advertising"
        }
    }
}
#endif
