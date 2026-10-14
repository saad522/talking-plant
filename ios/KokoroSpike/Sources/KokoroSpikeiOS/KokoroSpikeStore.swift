import Combine
import KokoroSpike
import SwiftUI

@MainActor
public final class KokoroSpikeStore: ObservableObject {
    @Published public internal(set) var state = KokoroSpikeViewModel.State()

    public init() {}
}
