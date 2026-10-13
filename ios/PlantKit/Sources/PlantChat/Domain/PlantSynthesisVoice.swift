public struct PlantSynthesisVoice: Equatable, Sendable {
    public enum Quality: Int, Comparable, Sendable {
        case standard, enhanced, premium

        public static func < (lhs: Quality, rhs: Quality) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    public let identifier: String
    public let name: String
    public let language: String
    public let quality: Quality

    public init(identifier: String, name: String, language: String, quality: Quality) {
        self.identifier = identifier
        self.name = name
        self.language = language
        self.quality = quality
    }
}
