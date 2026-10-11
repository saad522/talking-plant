import Foundation

@MainActor
public final class PlantHistoryViewModel {
    public typealias Observer<T> = (T) -> Void

    private let loader: PlantHistoryLoader
    private var appeared: Bool = false
    public private(set) var selectedRange: PlantHistoryRange

    public let title: String = String.localised(key: "plant.history.title")
    public let ranges: [PlantHistoryRange] = PlantHistoryRange.allCases

    public var loadedRange: Observer<PlantHistoryRange>?
    public var loadedSamples: Observer<[PlantHistorySample]>?
    public var loadedEmpty: Observer<String>?
    public var loadedError: Observer<String>?

    public init(loader: PlantHistoryLoader, initialRange: PlantHistoryRange = .day) {
        self.loader = loader
        self.selectedRange = initialRange
    }

    public func title(for range: PlantHistoryRange) -> String {
        switch range {
        case .day: String.localised(key: "plant.history.range.day")
        case .week: String.localised(key: "plant.history.range.week")
        }
    }

    public func appear() {
        guard appeared == false else { return }
        appeared = true
        loadedRange?(selectedRange)
        load()
        loader.subscribe { [weak self] in
            self?.load()
        }
    }

    public func select(_ range: PlantHistoryRange) {
        guard range != selectedRange else { return }
        selectedRange = range
        loadedRange?(range)
        load()
    }

    private func load() {
        let range = selectedRange
        loader.load(range) { [weak self] result in
            guard let self, range == self.selectedRange else { return }

            switch result {
            case .success(let samples) where samples.isEmpty:
                self.loadedEmpty?(String.localised(key: "plant.history.empty.description"))
            case .success(let samples):
                self.loadedSamples?(samples)
            case .failure:
                self.loadedError?(String.localised(key: "plant.history.error.description"))
            }
        }
    }
}
