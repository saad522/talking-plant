import PlantShared

/// What Sprout says when shaken (docs/plans/P1-alive.md section 3). Never the same line twice in a row for a mood.
public struct PlantMonitorShakeLines {
    private let randomIndex: (Int) -> Int
    private var lastIndex: [String: Int] = [:]

    /// `randomIndex` takes the number of lines and returns the index to try.
    public init(randomIndex: @escaping (Int) -> Int) {
        self.randomIndex = randomIndex
    }

    public static func lines(for mood: PlantMood, isSleeping: Bool) -> [String] {
        let group = group(for: mood, isSleeping: isSleeping)
        return (1...count(of: group)).map { String.localised(key: "plant.monitor.shake.\(group).\($0)") }
    }

    public mutating func next(for mood: PlantMood, isSleeping: Bool) -> String {
        let group = Self.group(for: mood, isSleeping: isSleeping)
        let lines = Self.lines(for: mood, isSleeping: isSleeping)
        var index = min(max(randomIndex(lines.count), 0), lines.count - 1)
        if index == lastIndex[group] {
            index = (index + 1) % lines.count
        }
        lastIndex[group] = index
        return lines[index]
    }

    private static func group(for mood: PlantMood, isSleeping: Bool) -> String {
        if isSleeping { return "sleeping" }
        switch mood {
        case .happy: return "happy"
        case .thirsty, .veryThirsty: return "thirsty"
        case .drowning: return "drowning"
        case .tooDark: return "tooDark"
        case .tooHot: return "tooHot"
        case .tooCold: return "tooCold"
        case .dryAir: return "dryAir"
        case .offline: return "offline"
        }
    }

    private static func count(of group: String) -> Int {
        group == "happy" || group == "thirsty" ? 3 : 2
    }
}
