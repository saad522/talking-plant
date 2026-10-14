import Foundation

/// The three fixed Sprout lines of the listening test.
public enum KokoroSpikeLine: String, CaseIterable, Sendable {
    case happy
    case thirsty
    case sleepy

    public var label: String {
        switch self {
        case .happy: "Happy"
        case .thirsty: "Thirsty"
        case .sleepy: "Sleepy"
        }
    }

    public var text: String {
        switch self {
        case .happy:
            "Hi, I'm Sprout! The sun feels lovely today. My leaves are doing a little happy dance."
        case .thirsty:
            "Psst... my soil is getting really dry. Could I have a drink of water, please?"
        case .sleepy:
            "Mmm, it's getting dark already. I'm going to fold my leaves and rest now. Goodnight!"
        }
    }
}
