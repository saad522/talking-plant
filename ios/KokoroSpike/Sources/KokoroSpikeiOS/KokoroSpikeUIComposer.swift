import Foundation
import KokoroSpike
import KokoroSpikeEngine

@MainActor
public enum KokoroSpikeUIComposer {
    /// The real thing: Kokoro on MLX with the bundled model files. Loads when the screen appears.
    public static func composed() -> KokoroSpikeView {
        composed(
            client: KokoroMLXSpikeSynthesizerClient.bundled(),
            now: { ProcessInfo.processInfo.systemUptime },
            memory: KokoroSpikeMemory.current,
            log: { print($0) }
        )
    }

    public static func composed(
        client: KokoroSpikeSynthesizerClient,
        now: @escaping () -> TimeInterval,
        memory: @escaping () -> KokoroSpikeMemory?,
        log: @escaping (String) -> Void
    ) -> KokoroSpikeView {
        let store = KokoroSpikeStore()
        let viewModel = KokoroSpikeViewModel(client: client, now: now, memory: memory, log: log)
        viewModel.onChange = { [weak store] state in
            store?.state = state
        }
        return KokoroSpikeView(store: store, viewModel: viewModel)
    }
}
