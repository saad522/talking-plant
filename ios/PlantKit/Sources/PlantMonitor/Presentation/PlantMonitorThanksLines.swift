/// What Sprout says after being watered (docs/plans/P1-alive.md follow-ups). Never the same line twice in a row.
public struct PlantMonitorThanksLines {
    private static let count = 5

    private let randomIndex: (Int) -> Int
    private var lastIndex: Int?

    /// `randomIndex` takes the number of lines and returns the index to try.
    public init(randomIndex: @escaping (Int) -> Int) {
        self.randomIndex = randomIndex
    }

    public static func lines() -> [String] {
        (1...count).map { String.localised(key: "plant.monitor.thanks.\($0)") }
    }

    public mutating func next() -> String {
        let lines = Self.lines()
        var index = min(max(randomIndex(lines.count), 0), lines.count - 1)
        if index == lastIndex {
            index = (index + 1) % lines.count
        }
        lastIndex = index
        return lines[index]
    }
}
