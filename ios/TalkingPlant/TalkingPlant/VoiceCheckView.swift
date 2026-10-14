#if DEBUG
import PlantChat
import PlantShared
import SwiftUI

/// Debug screen for Sprout's voice (docs/plans/M5c-kokoro.md K8). Not in Release builds.
struct VoiceCheckView: View {
    @State private var viewModel: PlantVoiceCheckViewModel

    init(voice: SproutVoice) {
        _viewModel = State(initialValue: PlantVoiceCheckViewModel(client: voice))
    }

    var body: some View {
        List {
            Section("Voice") {
                LabeledContent("Id", value: viewModel.voiceIDText)
                LabeledContent("Gate", value: viewModel.gateText)
                LabeledContent("State", value: viewModel.stateText)
                LabeledContent("Load", value: viewModel.loadText)
                LabeledContent("Warm-up", value: viewModel.warmUpText)
                LabeledContent("Memory", value: viewModel.memoryText)
                if let error = viewModel.loadError {
                    Text(error).foregroundStyle(.red)
                }
                HStack {
                    Button("Load") { Task { await viewModel.load() } }
                        .disabled(viewModel.isLoading)
                    Spacer()
                    Button("Unload") { viewModel.unload() }
                }
                .buttonStyle(.bordered)
            }
            Section("Speak sample") {
                ForEach(PlantVoiceCheckViewModel.sampleMoods, id: \.self) { mood in
                    Button(PlantVoiceCheckViewModel.label(for: mood)) { viewModel.speakSample(mood: mood) }
                }
                Button("Force Apple voice") { viewModel.speakWithAppleVoice() }
                Button("Stop", role: .destructive) { viewModel.stop() }
                if let speaking = viewModel.speaking {
                    Text("Speaking: \(speaking)").foregroundStyle(.secondary)
                }
            }
            Section("Last utterance") {
                LabeledContent("First audio", value: viewModel.firstAudioText)
                ForEach(viewModel.chunkTexts, id: \.self) { Text($0).font(.footnote.monospaced()) }
                LabeledContent("Watchdog fired", value: viewModel.watchdogText)
            }
        }
        .navigationTitle("Voice check")
        .task {
            while !Task.isCancelled {
                viewModel.refresh()
                try? await Task.sleep(for: .milliseconds(500))
            }
        }
    }
}
#endif
