import Foundation
import PlantShared

/// Forwards readings unchanged and saves each successful one to the store.
/// Skips a reading with the same sequence as the last one saved. Store errors are ignored
/// so the live readings keep flowing.
@MainActor
public final class LocalPlantReadingDecorator: PlantReadingLoader {
    private let decoratee: PlantReadingLoader
    private let store: PlantReadingStore
    private var lastSavedSequence: UInt32?

    public init(decoratee: PlantReadingLoader, store: PlantReadingStore) {
        self.decoratee = decoratee
        self.store = store
    }

    public func load(completion: @escaping (PlantReadingLoader.Result) -> Void) {
        decoratee.load { [weak self] result in
            self?.save(result)
            completion(result)
        }
    }

    public func subscribe(update: @escaping (PlantReadingLoader.Result) -> Void) {
        decoratee.subscribe { [weak self] result in
            self?.save(result)
            update(result)
        }
    }

    private func save(_ result: PlantReadingLoader.Result) {
        guard case let .success(reading) = result, reading.sequence != lastSavedSequence else { return }

        lastSavedSequence = reading.sequence
        store.insert(reading) { [weak self] error in
            if error != nil, self?.lastSavedSequence == reading.sequence {
                self?.lastSavedSequence = nil
            }
        }
    }
}
