import Foundation

public enum PlantChatAction: Equatable {
    case backTap
    case openSettings
    #if DEBUG
    /// Kokoro spike (docs/spikes/kokoro.md). Delete with the spike.
    case voiceSpikeTap
    #endif
}
