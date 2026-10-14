import KokoroSpike
import SwiftUI

/// DEBUG-only listening test for Kokoro (docs/spikes/kokoro.md).
public struct KokoroSpikeView: View {
    @ObservedObject var store: KokoroSpikeStore
    let viewModel: KokoroSpikeViewModel

    public var body: some View {
        let state = store.state
        Form {
            Section("Line") {
                Picker("Line", selection: Binding(get: { state.line }, set: { viewModel.select($0) })) {
                    ForEach(KokoroSpikeLine.allCases, id: \.self) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                Text(state.line.text)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Section("Voice") {
                Picker("Voice", selection: Binding(get: { state.voice }, set: { viewModel.select(voice: $0) })) {
                    ForEach(KokoroSpikeVoice.catalog) { Text($0.label).tag($0) }
                }
                Picker("Blend with", selection: Binding(get: { state.blendVoice }, set: { viewModel.select(blendVoice: $0) })) {
                    ForEach(KokoroSpikeVoice.catalog) { Text($0.label).tag($0) }
                }
                slider("Blend", value: String(format: "%.0f%%", state.blend * 100)) {
                    Slider(value: Binding(get: { state.blend }, set: { viewModel.setBlend($0) }), in: 0...1, step: 0.05)
                }
            }

            Section("Effect") {
                slider("Pitch", value: String(format: "%+.0f ct", state.pitchCents)) {
                    Slider(
                        value: Binding(get: { state.pitchCents }, set: { viewModel.setPitchCents($0) }),
                        in: KokoroSpikeViewModel.pitchRange,
                        step: 25
                    )
                }
                slider("Speed", value: String(format: "×%.2f", state.speed)) {
                    Slider(
                        value: Binding(get: { state.speed }, set: { viewModel.setSpeed($0) }),
                        in: KokoroSpikeViewModel.speedRange,
                        step: 0.05
                    )
                }
            }

            Section {
                Button(state.playLabel) { viewModel.playTap() }
                    .disabled(!state.canPlay)
                Text(state.statusLabel)
                    .foregroundStyle(.secondary)
                if let notice = state.notice {
                    Text(notice).foregroundStyle(.red)
                }
            }

            if !state.metrics.isEmpty {
                Section("Timings") {
                    ForEach(state.metrics, id: \.self) { Text($0).monospacedDigit() }
                }
            }

            if !state.runs.isEmpty {
                Section("Last runs") {
                    ForEach(state.runs, id: \.self) { Text($0).font(.caption).monospacedDigit() }
                }
            }
        }
        .navigationTitle("Voice spike")
        .onAppear { viewModel.appear() }
        .onDisappear { viewModel.disappear() }
    }

    private func slider<S: View>(_ title: String, value: String, @ViewBuilder slider: () -> S) -> some View {
        VStack(alignment: .leading) {
            HStack {
                Text(title)
                Spacer()
                Text(value).monospacedDigit().foregroundStyle(.secondary)
            }
            slider()
        }
    }
}
